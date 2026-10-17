using BusinessOS.Application.Features.Receipts.Services;
using BusinessOS.Application.Features.Sales.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Application.Sales;
using BusinessOS.Application.Tax;
using BusinessOS.Domain.Catalog;
using BusinessOS.Domain.Crm;
using BusinessOS.Domain.Inventory;
using BusinessOS.Domain.Pricing;
using BusinessOS.Domain.Sales;
using BusinessOS.Domain.Tenants;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Sales.Commands;

public sealed record CreateSaleCommand(
    Guid BranchId,
    Guid? WarehouseId,
    Guid? PriceListId,
    Guid ClientSaleId,
    SaleSource Source,
    DateTime EffectiveAt,
    bool IsElectronicPayment,
    bool? IsVatRegistered,
    string? CustomerName,
    string? CustomerPhone,
    string? CustomerTin,
    IReadOnlyList<CreateSaleLineInput> Lines,
    IReadOnlyList<CreateSalePaymentInput> Payments,
    Guid? CustomerId = null)
    : IRequest<Result<SaleDto>>, IRequiresTenantAdvisoryLock;

/// <summary>
/// Records a completed sale against the real product/price/stock foundation. The server
/// re-resolves price, tax and stock on the first arrival only: a replay of the same
/// <see cref="CreateSaleCommand.ClientSaleId"/> returns the original sale with no new stock,
/// numbering, or event work (idempotency key, unique per tenant). All money is server-computed
/// from resolved lines; the header is a dumb aggregator and must reconcile exactly.
/// </summary>
public sealed class CreateSaleCommandHandler : IRequestHandler<CreateSaleCommand, Result<SaleDto>>
{
    private const string DefaultTaxCategoryCode = "VAT_STANDARD";

    private readonly ITenantContext _tenantContext;
    private readonly IBranchRepository _branches;
    private readonly IWarehouseRepository _warehouses;
    private readonly IProductRepository _products;
    private readonly IUnitOfMeasureRepository _unitsOfMeasure;
    private readonly IPriceListRepository _priceLists;
    private readonly ITaxRuleRepository _taxRules;
    private readonly ITaxEngine _taxEngine;
    private readonly ISaleRepository _sales;
    private readonly INumberSequenceRepository _numberSequences;
    private readonly SaleStockDebitService _stockDebit;
    private readonly ICustomerCreditRepository _credits;
    private readonly IReceiptMetadataService _receiptMetadata;

    public CreateSaleCommandHandler(
        ITenantContext tenantContext,
        IBranchRepository branches,
        IWarehouseRepository warehouses,
        IProductRepository products,
        IUnitOfMeasureRepository unitsOfMeasure,
        IPriceListRepository priceLists,
        ITaxRuleRepository taxRules,
        ITaxEngine taxEngine,
        ISaleRepository sales,
        INumberSequenceRepository numberSequences,
        SaleStockDebitService stockDebit,
        ICustomerCreditRepository credits,
        IReceiptMetadataService receiptMetadata)
    {
        _tenantContext = tenantContext;
        _branches = branches;
        _warehouses = warehouses;
        _products = products;
        _unitsOfMeasure = unitsOfMeasure;
        _priceLists = priceLists;
        _taxRules = taxRules;
        _taxEngine = taxEngine;
        _sales = sales;
        _numberSequences = numberSequences;
        _stockDebit = stockDebit;
        _credits = credits;
        _receiptMetadata = receiptMetadata;
    }

    public async Task<Result<SaleDto>> Handle(CreateSaleCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var cashierId = _tenantContext.UserId;
        if (!cashierId.HasValue || cashierId.Value == Guid.Empty)
        {
            return Error.Unauthorized("A signed-in cashier is required to record a sale.");
        }

        var existing = await _sales.GetByClientSaleIdAsync(tenantId, command.ClientSaleId, cancellationToken);
        if (existing is not null)
        {
            return Result.Success(SalesMappers.ToDto(existing));
        }

        var branch = await _branches.GetByIdAsync(tenantId, command.BranchId, cancellationToken);
        if (branch is null)
        {
            return Error.NotFound("Branch not found.");
        }

        Warehouse? warehouse;
        if (command.WarehouseId.HasValue)
        {
            warehouse = await _warehouses.GetByIdAsync(tenantId, command.WarehouseId.Value, cancellationToken);
            if (warehouse is null)
            {
                return Error.NotFound("Warehouse not found.");
            }

            if (warehouse.BranchId != branch.Id)
            {
                return Error.Validation("The warehouse does not belong to the sale branch.");
            }
        }
        else
        {
            var warehouses = await _warehouses.ListAsync(
                tenantId, page: 1, pageSize: 1, search: null, branch.Id, cancellationToken);
            var candidate = warehouses.FirstOrDefault();
            if (candidate is null)
            {
                return Error.Validation("The branch has no warehouse to draw stock from.");
            }

            warehouse = await _warehouses.GetByIdAsync(tenantId, candidate.Id, cancellationToken);
            if (warehouse is null)
            {
                return Error.NotFound("Warehouse not found.");
            }
        }

        var priceList = command.PriceListId.HasValue
            ? await _priceLists.GetByIdAsync(
                tenantId, command.PriceListId.Value, includePrices: false, cancellationToken)
            : await _priceLists.GetDefaultAsync(tenantId, cancellationToken);
        if (priceList is null)
        {
            return Error.NotFound("No price list could be resolved for this sale.");
        }

        var products = new List<Product>(command.Lines.Count);
        var prices = new ResolvedPrice[command.Lines.Count];
        var debitsStock = new bool[command.Lines.Count];
        var itemIds = new Guid[command.Lines.Count];
        var taxItems = new List<TaxCalculationLineItem>(command.Lines.Count);
        var onDate = command.EffectiveAt;

        var productIds = command.Lines.Select(l => l.ProductId).Distinct();
        var productList = await _products.GetByIdsAsync(tenantId, productIds, cancellationToken);
        var productMap = productList.ToDictionary(p => p.Id);

        for (var i = 0; i < command.Lines.Count; i++)
        {
            var input = command.Lines[i];
            if (!productMap.TryGetValue(input.ProductId, out var product))
            {
                return Error.NotFound("Product not found.");
            }

            if (product.Status != ProductStatus.Active)
            {
                return Error.Validation($"Product '{product.Name}' is not sellable.");
            }

            if (product.HasVariants)
            {
                if (!input.VariantId.HasValue || product.Variants.All(v => v.Id != input.VariantId.Value))
                {
                    return Error.Validation("A variant belonging to the product must be specified.");
                }
            }
            else if (input.VariantId.HasValue)
            {
                return Error.Validation("This product has no variants.");
            }

            var price = await ResolvePriceAsync(
                tenantId, priceList, branch.Id, product, input, onDate, cancellationToken);
            if (price is null)
            {
                return Error.Validation($"No price could be resolved for '{product.Name}'.");
            }

            var itemId = Guid.NewGuid();
            products.Add(product);
            prices[i] = price;
            debitsStock[i] = product.ProductType == ProductType.Product;
            itemIds[i] = itemId;
            taxItems.Add(new TaxCalculationLineItem(
                itemId,
                await ResolveTaxCategoryCodeAsync(product, cancellationToken),
                price.Price,
                input.Quantity,
                IsPriceTaxInclusive: true));
        }

        var taxResult = await _taxEngine.CalculateAsync(new TaxCalculationContext(
            tenantId,
            branch.Id,
            onDate,
            CustomerId: null,
            priceList.Currency,
            command.IsElectronicPayment,
            command.CustomerTin,
            command.IsVatRegistered,
            taxItems), cancellationToken);
        var snapshotByItemId = taxResult.Lines.ToDictionary(s => s.ItemId);

        var unitOfMeasureNameById = await ResolveUnitOfMeasureNamesAsync(
            tenantId, products, cancellationToken);

        var saleLines = new List<SaleLine>(command.Lines.Count);
        decimal discountTotal = 0m;
        for (var i = 0; i < command.Lines.Count; i++)
        {
            var input = command.Lines[i];
            var product = products[i];
            var price = prices[i];
            var snapshot = snapshotByItemId[itemIds[i]];
            var variant = input.VariantId.HasValue
                ? product.Variants.FirstOrDefault(v => v.Id == input.VariantId.Value)
                : null;

            var gross = Round(price.Price * input.Quantity);
            if (input.DiscountAmount > gross)
            {
                return Error.Validation($"Discount cannot exceed the line total for '{product.Name}'.");
            }

            saleLines.Add(SaleLine.Create(
                product.Id,
                input.VariantId,
                input.ProductName ?? product.Name,
                variant?.Sku ?? product.Sku,
                variant?.Barcode ?? product.Barcode,
                product.UnitOfMeasureId,
                unitOfMeasureNameById.GetValueOrDefault(product.UnitOfMeasureId),
                input.Quantity,
                price.Price,
                input.DiscountAmount,
                snapshot.TaxCode,
                snapshot.AppliedRate,
                snapshot.AppliedRuleId,
                snapshot.BaseAmount,
                snapshot.TaxAmount,
                snapshot.LineTotal,
                orderIndex: i,
                unitCost: product.CostPrice));

            discountTotal += input.DiscountAmount;
        }

        var subtotal = saleLines.Sum(l => Round(l.UnitPrice * l.Quantity));
        var taxAmount = saleLines.Sum(l => l.TaxAmount);
        var totalAmount = saleLines.Sum(l => l.LineTotal - l.DiscountAmount);

        var payments = command.Payments
            .Select((p, i) => SalePayment.Create(p.Method, p.Amount, p.Provider, p.PhoneNumber, p.Reference, i))
            .ToList();
        var amountPaid = payments.Sum(p => p.Amount);
        var hasCreditPayment = payments.Any(p => p.Method == PaymentMethod.Credit);
        if (amountPaid < totalAmount && !hasCreditPayment)
        {
            return Error.Validation("Payments must fully cover the sale total.");
        }

        if (hasCreditPayment
            && amountPaid < totalAmount
            && (!command.CustomerId.HasValue || command.CustomerId.Value == Guid.Empty))
        {
            return Error.Validation("A credit sale needs a customer.");
        }

        var number = await _numberSequences.AllocateAsync(tenantId, "Sale", onDate, cancellationToken);

        var sale = Sale.Create(
            tenantId,
            branch.Id,
            warehouse.Id,
            cashierId.Value,
            command.ClientSaleId,
            number,
            command.Source,
            DateTime.UtcNow,
            onDate,
            priceList.Currency,
            priceList.Id,
            isPriceTaxInclusive: true,
            command.IsElectronicPayment,
            command.CustomerId,
            command.CustomerName,
            command.CustomerTin,
            command.IsVatRegistered,
            subtotal,
            discountTotal,
            taxAmount,
            totalAmount,
            amountPaid,
            Math.Max(0m, amountPaid - totalAmount),
            saleLines,
            payments,
            buyerMobile: command.CustomerPhone);

        var debitResult = await _stockDebit.DebitAsync(new StockDebitRequest(
            tenantId,
            branch.Id,
            warehouse.Id,
            ResolveStockLocation(warehouse).Id,
            sale.Id,
            onDate,
            cashierId.Value,
            saleLines.Select((l, i) => new StockDebitLine(
                l.ProductId, l.VariantId, l.ProductName, l.UnitOfMeasureId, l.Quantity, debitsStock[i])).ToList()),
            cancellationToken);
        if (debitResult.IsFailure)
        {
            return Result.Failure<SaleDto>(debitResult.Error);
        }

        await _sales.AddAsync(sale, cancellationToken);

        // Capture receipt metadata (business identity snapshot + layout version).
        // This is done inside the sale transaction so that the metadata is always
        // consistent with the sale, even if the business settings change later.
        try
        {
            await _receiptMetadata.CaptureMetadataAsync(sale, cancellationToken);
        }
        catch (InvalidOperationException)
        {
            // If no default layout is seeded, continue without metadata.
            // The receipt preview will fall back to the current business name.
            // This allows sales to proceed even before the layout is seeded.
        }

        var outstanding = totalAmount - amountPaid;
        if (hasCreditPayment && outstanding > 0m)
        {
            // The customer-id guard above guarantees a non-empty id here.
            var credit = await _credits.GetByCustomerIdAsync(tenantId, command.CustomerId!.Value, cancellationToken);
            var creditCreated = credit is null;
            if (credit is null)
            {
                credit = CustomerCredit.Create(tenantId, command.CustomerId.Value);
                await _credits.AddAsync(credit, cancellationToken);
            }

            credit.RecordSale(outstanding);
            if (!creditCreated)
            {
                await _credits.UpdateAsync(credit, cancellationToken);
            }

            await _credits.AddTransactionAsync(CreditTransaction.Create(
                tenantId,
                command.CustomerId.Value,
                CreditTransactionType.Sale,
                outstanding,
                credit.Balance,
                $"Credit - Sale {sale.Number}",
                sale.Id), cancellationToken);
        }

        return Result.Success(SalesMappers.ToDto(sale));
    }

/// <summary>
/// Resolves the selling price for a line. When the line carries an explicit
/// <see cref="CreateSaleLineInput.UnitPrice"/> override (e.g. the POS "Bila
/// Jina" quick-sale flow) that amount is used as-is; otherwise the price list
/// is consulted. The server stays the final authority: overrides are values
/// the caller is allowed to fix, not discounted catalogue prices.
/// </summary>
private async Task<ResolvedPrice?> ResolvePriceAsync(
    Guid tenantId,
    PriceList priceList,
    Guid branchId,
    Product product,
    CreateSaleLineInput input,
    DateTime onDate,
    CancellationToken cancellationToken)
{
    if (input.UnitPrice.HasValue)
    {
        return new ResolvedPrice(
            ProductPriceId: Guid.Empty,
            PriceListId: priceList.Id,
            Price: Round(input.UnitPrice.Value),
            Currency: priceList.Currency,
            PriceType: PriceType.Retail,
            MinQuantity: input.Quantity);
    }

    var candidates = await _priceLists.ResolvePricesAsync(
        tenantId,
        priceList.Id,
        product.Id,
        input.VariantId,
        branchId,
        PriceType.Retail,
        input.Quantity,
        onDate,
        cancellationToken);

    return PriceResolver.Resolve(
        candidates, product.Id, input.VariantId, branchId, PriceType.Retail, input.Quantity, onDate);
}

    private readonly Dictionary<Guid, string> _taxCategoryCache = new();

    private async Task<string> ResolveTaxCategoryCodeAsync(
        Product product, CancellationToken cancellationToken)
    {
        if (!product.TaxCategoryId.HasValue)
        {
            return DefaultTaxCategoryCode;
        }

        if (_taxCategoryCache.TryGetValue(product.TaxCategoryId.Value, out var cachedCode))
        {
            return cachedCode;
        }

        var category = await _taxRules.GetCategoryByIdAsync(product.TaxCategoryId.Value, cancellationToken);
        var code = category?.Code ?? DefaultTaxCategoryCode;
        _taxCategoryCache[product.TaxCategoryId.Value] = code;
        return code;
    }

    private async Task<IReadOnlyDictionary<Guid, string?>> ResolveUnitOfMeasureNamesAsync(
        Guid tenantId, IReadOnlyCollection<Product> products, CancellationToken cancellationToken)
    {
        var names = new Dictionary<Guid, string?>();
        foreach (var unitOfMeasureId in products.Select(p => p.UnitOfMeasureId).Distinct())
        {
            var unitOfMeasure = await _unitsOfMeasure.GetByIdAsync(tenantId, unitOfMeasureId, cancellationToken);
            names[unitOfMeasureId] = unitOfMeasure?.Name;
        }

        return names;
    }

    private static StockLocation ResolveStockLocation(Warehouse warehouse)
        => warehouse.Locations.FirstOrDefault(l => l.Code == Warehouse.DefaultLocationCode)
            ?? warehouse.Locations.First();

    private static decimal Round(decimal value)
        => Math.Round(value, 2, MidpointRounding.AwayFromZero);
}
