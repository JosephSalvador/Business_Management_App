using BusinessOS.Application.Features.Sales.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Application.Sales;
using BusinessOS.Application.Tax;
using BusinessOS.Domain.Catalog;
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
    IReadOnlyList<CreateSalePaymentInput> Payments)
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
        SaleStockDebitService stockDebit)
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

        for (var i = 0; i < command.Lines.Count; i++)
        {
            var input = command.Lines[i];
            var product = await _products.GetByIdAsync(tenantId, input.ProductId, cancellationToken);
            if (product is null)
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
                tenantId, priceList.Id, branch.Id, product, input, onDate, cancellationToken);
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
                product.Name,
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
                orderIndex: i));

            discountTotal += input.DiscountAmount;
        }

        var subtotal = saleLines.Sum(l => Round(l.UnitPrice * l.Quantity));
        var taxAmount = saleLines.Sum(l => l.TaxAmount);
        var totalAmount = saleLines.Sum(l => l.LineTotal - l.DiscountAmount);

        var payments = command.Payments
            .Select((p, i) => SalePayment.Create(p.Method, p.Amount, p.Provider, p.PhoneNumber, p.Reference, i))
            .ToList();
        var amountPaid = payments.Sum(p => p.Amount);
        if (amountPaid != totalAmount)
        {
            return Error.Validation("Payments must fully cover the sale total.");
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
            customerId: null,
            command.CustomerName,
            command.CustomerTin,
            command.IsVatRegistered,
            subtotal,
            discountTotal,
            taxAmount,
            totalAmount,
            amountPaid,
            amountPaid - totalAmount,
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
        return Result.Success(SalesMappers.ToDto(sale));
    }

    private async Task<ResolvedPrice?> ResolvePriceAsync(
        Guid tenantId,
        Guid priceListId,
        Guid branchId,
        Product product,
        CreateSaleLineInput input,
        DateTime onDate,
        CancellationToken cancellationToken)
    {
        var candidates = await _priceLists.ResolvePricesAsync(
            tenantId,
            priceListId,
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

    private async Task<string> ResolveTaxCategoryCodeAsync(
        Product product, CancellationToken cancellationToken)
    {
        if (!product.TaxCategoryId.HasValue)
        {
            return DefaultTaxCategoryCode;
        }

        var category = await _taxRules.GetCategoryByIdAsync(product.TaxCategoryId.Value, cancellationToken);
        return category?.Code ?? DefaultTaxCategoryCode;
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
