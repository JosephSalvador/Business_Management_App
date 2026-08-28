using BusinessOS.Application.Features.Sales;
using BusinessOS.Application.Features.Sales.Commands;
using BusinessOS.Application.Features.Sales.Dtos;
using BusinessOS.Application.Features.Sales.Queries;
using BusinessOS.Application.Ports;
using BusinessOS.Application.Sales;
using BusinessOS.Application.Tax;
using BusinessOS.Domain.Catalog;
using BusinessOS.Domain.Inventory;
using BusinessOS.Domain.Pricing;
using BusinessOS.Domain.Sales;
using BusinessOS.Domain.Tenants;
using BusinessOS.Shared;

namespace BusinessOS.Tests.Unit.Sales;

public sealed class CreateSaleCommandTests
{
    private static readonly Guid TenantId = new("11111111-1111-1111-1111-111111111111");
    private static readonly Guid CashierId = new("22222222-2222-2222-2222-222222222222");
    private static readonly DateTime EffectiveAt = new(2026, 8, 15, 12, 0, 0, DateTimeKind.Utc);

    [Fact]
    public async Task HappyPath_ResolvesPriceTaxStockAndIssuesNumber()
    {
        var world = BuildWorld();
        var handler = world.CreateHandler();

        var result = await handler.Handle(world.Command(), CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error.Message);
        var dto = result.Value;
        Assert.Equal("S-2026-000001", dto.Number);
        Assert.Equal(100.00m, dto.Subtotal);
        Assert.Equal(15.25m, dto.TaxAmount);
        Assert.Equal(100.00m, dto.TotalAmount);
        Assert.Equal(100.00m, dto.AmountPaid);
        Assert.Equal(0m, dto.Change);
        Assert.Single(dto.Lines);
        Assert.Equal("A", dto.Lines[0].TaxCode);
        Assert.Equal(0.18m, dto.Lines[0].AppliedRate);
        Assert.Equal(84.75m, dto.Lines[0].BaseAmount);
        Assert.Equal("Coca Cola 500ml", dto.Lines[0].ProductName);
        Assert.Equal("Piece", dto.Lines[0].UnitOfMeasureName);
        Assert.Equal(PaymentMethod.Cash, dto.Payments[0].Method);

        Assert.NotNull(world.Sales.Added);
        Assert.Single(world.Sales.Added!.DomainEvents);
        Assert.Single(world.Stock.Movements);
        Assert.Equal(StockMovementType.Sale, world.Stock.Movements[0].MovementType);
        Assert.Equal(world.Sales.Added.Id, world.Stock.Movements[0].ReferenceId);
        Assert.Equal(1, world.NumberSequences.AllocationCount);
        Assert.Equal(100m - 1m, world.Stock.Balance!.Quantity);
    }

    [Fact]
    public async Task HappyPath_CarriesCustomerSnapshot()
    {
        var world = BuildWorld();
        var handler = world.CreateHandler();

        var result = await handler.Handle(
            world.Command() with
            {
                IsVatRegistered = true,
                CustomerName = "John Doe",
                CustomerPhone = "0712345678",
                CustomerTin = "123-456-789",
            },
            CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error.Message);
        var customer = result.Value.Customer;
        Assert.NotNull(customer);
        Assert.Equal("John Doe", customer!.Name);
        Assert.Equal("0712345678", customer.Phone);
        Assert.Equal("123-456-789", customer.Tin);
        Assert.True(customer.IsVatRegistered);
    }

    [Fact]
    public async Task HappyPath_WithOnlyName_StillExposesCustomer()
    {
        var world = BuildWorld();
        var handler = world.CreateHandler();

        var result = await handler.Handle(
            world.Command() with { CustomerName = "Walk-in" },
            CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error.Message);
        var customer = result.Value.Customer;
        Assert.NotNull(customer);
        Assert.Equal("Walk-in", customer!.Name);
        Assert.Null(customer.Phone);
        Assert.Null(customer.Tin);
        Assert.Null(customer.IsVatRegistered);
    }

    [Fact]
    public async Task Replay_SameClientSaleId_ReturnsOriginalWithoutSideEffects()
    {
        var world = BuildWorld();
        world.Sales.Replay = BuildSale(world);
        var handler = world.CreateHandler();

        var result = await handler.Handle(world.Command(), CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(world.Sales.Replay.Id, result.Value.Id);
        Assert.Null(world.Sales.Added);
        Assert.Equal(0, world.NumberSequences.AllocationCount);
        Assert.Empty(world.Stock.Movements);
    }

    [Fact]
    public async Task NoPrice_RejectsTheWholeSale()
    {
        var world = BuildWorld();
        world.PriceLists.RemoveCandidate(world.Product.Id);
        var handler = world.CreateHandler();

        var result = await handler.Handle(world.Command(), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("Validation", result.Error.Code);
        Assert.Contains("No price could be resolved", result.Error.Message);
        Assert.Null(world.Sales.Added);
        Assert.Empty(world.Stock.Movements);
        Assert.Equal(0, world.NumberSequences.AllocationCount);
    }

    [Fact]
    public async Task InsufficientStock_RejectsWithNoMovementsOrNumber()
    {
        var world = BuildWorld();
        world.Stock.Balance!.Apply(-100m);
        var handler = world.CreateHandler();

        var result = await handler.Handle(world.Command(), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("Validation", result.Error.Code);
        Assert.Contains("Insufficient stock", result.Error.Message);
        Assert.Null(world.Sales.Added);
        Assert.Empty(world.Stock.Movements);
    }

    [Fact]
    public async Task PaymentsBelowTotal_AreRejected()
    {
        var world = BuildWorld();
        var handler = world.CreateHandler();

        var result = await handler.Handle(
            world.Command() with { Payments = [new CreateSalePaymentInput(PaymentMethod.Cash, 50m)] },
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("Validation", result.Error.Code);
        Assert.Contains("cover the sale total", result.Error.Message);
        Assert.Null(world.Sales.Added);
    }

    [Fact]
    public async Task VariantProductWithoutVariant_IsRejected()
    {
        var world = BuildWorld();
        var variantProduct = Product.Create(
            TenantId, "T-Shirt", null, sku: null, barcode: null, null, null,
            world.UnitOfMeasure.Id, ProductType.Product, ProductStatus.Active, world.TaxCategory.Id);
        variantProduct.SetVariants([new ProductVariantSpec(Guid.Empty, "Red", "VAR-SKU", null)]);
        world.Products.Add(variantProduct);
        world.PriceLists.AddCandidate(variantProduct.Id, price: 80m);
        var handler = world.CreateHandler();

        var result = await handler.Handle(
            world.Command() with
            {
                Lines = [new CreateSaleLineInput(variantProduct.Id, VariantId: null, 1m)],
                Payments = [new CreateSalePaymentInput(PaymentMethod.Cash, 80m)],
            },
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("Validation", result.Error.Code);
        Assert.Contains("variant belonging to the product", result.Error.Message);
    }

    [Fact]
    public async Task NonActiveProduct_IsRejected()
    {
        var world = BuildWorld();
        world.Product.SetStatus(ProductStatus.Inactive);
        var handler = world.CreateHandler();

        var result = await handler.Handle(world.Command(), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("Validation", result.Error.Code);
        Assert.Contains("not sellable", result.Error.Message);
    }

    [Fact]
    public async Task BranchNotFound_ReturnsNotFound()
    {
        var world = BuildWorld();
        world.Branches.Branch = null;
        var handler = world.CreateHandler();

        var result = await handler.Handle(world.Command(), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("NotFound", result.Error.Code);
    }

    [Fact]
    public async Task ExplicitWarehouseNotInBranch_IsRejected()
    {
        var world = BuildWorld();
        var otherBranch = Branch.Create(TenantId, "Other", "OB", "TZS");
        var foreignWarehouse = Warehouse.Create(TenantId, otherBranch.Id, "Foreign", "FGN");
        world.Warehouses.Add(foreignWarehouse);
        var handler = world.CreateHandler();

        var result = await handler.Handle(
            world.Command() with { WarehouseId = foreignWarehouse.Id },
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("Validation", result.Error.Code);
    }

    [Fact]
    public async Task ServiceLine_SkipsStockDebit()
    {
        var world = BuildWorld();
        var serviceProduct = Product.Create(
            TenantId, "Repair service", null, "SRV-1", null, null, null,
            world.UnitOfMeasure.Id, ProductType.Service, ProductStatus.Active, world.TaxCategory.Id);
        world.Products.Add(serviceProduct);
        world.PriceLists.AddCandidate(serviceProduct.Id, price: 50m);
        var handler = world.CreateHandler();

        var result = await handler.Handle(
            world.Command() with
            {
                Lines =
                [
                    new CreateSaleLineInput(serviceProduct.Id, null, 1m),
                ],
                Payments = [new CreateSalePaymentInput(PaymentMethod.Cash, 50m)],
            },
            CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error.Message);
        Assert.Empty(world.Stock.Movements);
        Assert.Equal(100m, world.Stock.Balance!.Quantity);
    }

    [Fact]
    public async Task DiscountBelowOrEqualToGross_IsApplied()
    {
        var world = BuildWorld();
        var handler = world.CreateHandler();

        var result = await handler.Handle(
            world.Command() with
            {
                Lines = [new CreateSaleLineInput(world.Product.Id, null, 1m, DiscountAmount: 10m)],
                Payments = [new CreateSalePaymentInput(PaymentMethod.Cash, 90m)],
            },
            CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error.Message);
        Assert.Equal(10m, result.Value.DiscountAmount);
        Assert.Equal(90m, result.Value.TotalAmount);
        Assert.Equal(90m, result.Value.AmountPaid);
    }

    [Fact]
    public async Task DiscountAboveGross_IsRejected()
    {
        var world = BuildWorld();
        var handler = world.CreateHandler();

        var result = await handler.Handle(
            world.Command() with
            {
                Lines = [new CreateSaleLineInput(world.Product.Id, null, 1m, DiscountAmount: 200m)],
            },
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("Validation", result.Error.Code);
        Assert.Contains("Discount cannot exceed", result.Error.Message);
    }

    [Fact]
    public async Task SplitPayment_ReconcilesWhenPaidInFull()
    {
        var world = BuildWorld();
        var handler = world.CreateHandler();

        var result = await handler.Handle(
            world.Command() with
            {
                Payments =
                [
                    new CreateSalePaymentInput(PaymentMethod.Cash, 40m),
                    new CreateSalePaymentInput(PaymentMethod.MobileMoney, 60m, "Vodacom", "0712345678", "MM-1"),
                ],
            },
            CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error.Message);
        Assert.Equal(2, result.Value.Payments.Count);
        Assert.Equal(PaymentMethod.MobileMoney, result.Value.Payments[1].Method);
        Assert.Equal("Vodacom", result.Value.Payments[1].Provider);
        Assert.Equal("0712345678", result.Value.Payments[1].PhoneNumber);
    }

    [Fact]
    public async Task NoCashier_ReturnsUnauthorized()
    {
        var world = BuildWorld();
        var handler = world.CreateHandler(withCashier: false);

        var result = await handler.Handle(world.Command(), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("Unauthorized", result.Error.Code);
    }

    private sealed class World
    {
        public required Branch Branch { get; init; }
        public required Warehouse Warehouse { get; init; }
        public required UnitOfMeasure UnitOfMeasure { get; init; }
        public required PriceList PriceList { get; init; }
        public required TaxCategory TaxCategory { get; init; }
        public required Product Product { get; init; }
        public required StubProductRepository Products { get; init; }
        public required StubPriceListRepository PriceLists { get; init; }
        public required StubWarehouseRepository Warehouses { get; init; }
        public required StubBranchRepository Branches { get; init; }
        public required StubTaxRuleRepository TaxRules { get; init; }
        public required StubUnitOfMeasureRepository UnitsOfMeasure { get; init; }
        public required StubStockRepository Stock { get; init; }
        public required StubSaleRepository Sales { get; init; }
        public required StubNumberSequenceRepository NumberSequences { get; init; }

        public CreateSaleCommand Command() => new(
            BranchId: Branch.Id,
            WarehouseId: null,
            PriceListId: null,
            ClientSaleId: Guid.NewGuid(),
            Source: SaleSource.Online,
            EffectiveAt: EffectiveAt,
            IsElectronicPayment: false,
            IsVatRegistered: null,
            CustomerName: null,
            CustomerPhone: null,
            CustomerTin: null,
            Lines: [new CreateSaleLineInput(Product.Id, null, 1m)],
            Payments: [new CreateSalePaymentInput(PaymentMethod.Cash, 100m)]);

        public CreateSaleCommandHandler CreateHandler(bool withCashier = true) => new(
            new StubTenantContext { TenantId = TenantId, UserId = withCashier ? CashierId : null },
            Branches,
            Warehouses,
            Products,
            UnitsOfMeasure,
            PriceLists,
            TaxRules,
            new StubTaxEngine(),
            Sales,
            NumberSequences,
            new SaleStockDebitService(Stock));
    }

    private static World BuildWorld()
    {
        var branch = Branch.Create(TenantId, "Head Office", "HQ", "TZS");
        var warehouse = Warehouse.Create(TenantId, branch.Id, "Main Warehouse", "MAIN");
        var unitOfMeasure = UnitOfMeasure.Create(TenantId, "Piece", "pc");
        var priceList = PriceList.Create(TenantId, "Default", "TZS", isDefault: true);
        var taxCategory = TaxCategory.Create("VAT_STANDARD", "Standard VAT");
        var product = Product.Create(
            TenantId, "Coca Cola 500ml", null, "SKU-1", null, null, null,
            unitOfMeasure.Id, ProductType.Product, ProductStatus.Active, taxCategory.Id);

        var stockLocation = warehouse.Locations.First(l => l.Code == Warehouse.DefaultLocationCode);
        var balance = StockBalance.Create(
            TenantId, warehouse.Id, stockLocation.Id, product.Id, variantId: null);
        balance.Apply(100m);

        var products = new StubProductRepository();
        products.Add(product);
        var priceLists = new StubPriceListRepository { Default = priceList };
        priceLists.AddCandidate(product.Id, price: 100m);
        var warehouses = new StubWarehouseRepository { Warehouse = warehouse, BranchId = branch.Id };
        warehouses.Add(warehouse);

        return new World
        {
            Branch = branch,
            Warehouse = warehouse,
            UnitOfMeasure = unitOfMeasure,
            PriceList = priceList,
            TaxCategory = taxCategory,
            Product = product,
            Products = products,
            PriceLists = priceLists,
            Warehouses = warehouses,
            Branches = new StubBranchRepository { Branch = branch },
            TaxRules = new StubTaxRuleRepository { Category = taxCategory },
            UnitsOfMeasure = new StubUnitOfMeasureRepository { UnitOfMeasure = unitOfMeasure },
            Stock = new StubStockRepository { Balance = balance },
            Sales = new StubSaleRepository(),
            NumberSequences = new StubNumberSequenceRepository(),
        };
    }

    private static Sale BuildSale(World world)
    {
        var line = SaleLine.Create(
            world.Product.Id, null, world.Product.Name, world.Product.Sku, world.Product.Barcode,
            world.Product.UnitOfMeasureId, world.UnitOfMeasure.Name, 1m, 100m, 0m,
            "A", 0.18m, Guid.NewGuid(), 84.75m, 15.25m, 100m, 0);
        var payment = SalePayment.Create(PaymentMethod.Cash, 100m, null, null, null, 0);

        return Sale.Create(
            TenantId, world.Branch.Id, world.Warehouse.Id, CashierId, Guid.NewGuid(),
            "S-2026-000001", SaleSource.Online, EffectiveAt, EffectiveAt,
            "TZS", world.PriceList.Id, isPriceTaxInclusive: true, isElectronicPayment: false,
            customerId: null, customerName: null, customerTin: null, isVatRegistered: null,
            subtotal: 100m, discountAmount: 0m, taxAmount: 15.25m, totalAmount: 100m,
            amountPaid: 100m, change: 0m, [line], [payment]);
    }

    private sealed class StubTenantContext : ITenantContext
    {
        public Guid TenantId { get; init; }
        public Guid? UserId { get; init; }
        public string? IpAddress => null;
    }

    private sealed class StubBranchRepository : IBranchRepository
    {
        public Branch? Branch { get; set; }

        public Task<Branch?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken ct = default)
            => Task.FromResult(Branch?.Id == id ? Branch : null);
        public Task<Branch?> GetByCodeAsync(Guid tenantId, string code, CancellationToken ct = default)
            => Task.FromResult(Branch?.Code == code ? Branch : null);
        public Task<IReadOnlyList<Branch>> ListAsync(Guid tenantId, int page, int pageSize, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<Branch>>(Branch is null ? Array.Empty<Branch>() : new[] { Branch });
        public Task<IReadOnlyList<Branch>> ListAllAsync(Guid tenantId, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<Branch>>(Branch is null ? Array.Empty<Branch>() : new[] { Branch });
        public Task<IReadOnlyList<Branch>> ListByIdsAsync(Guid tenantId, IEnumerable<Guid> ids, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<Branch>>(Branch is null ? Array.Empty<Branch>() : new[] { Branch });
        public Task<int> CountAsync(Guid tenantId, CancellationToken ct = default) => Task.FromResult(1);
        public Task AddAsync(Branch branch, CancellationToken ct = default) => Task.CompletedTask;
    }

    private sealed class StubWarehouseRepository : IWarehouseRepository
    {
        public Warehouse? Warehouse { get; set; }
        public Guid BranchId { get; set; }
        private readonly List<Warehouse> _warehouses = new();

        public void Add(Warehouse warehouse) => _warehouses.Add(warehouse);

        public Task<Warehouse?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken ct = default)
            => Task.FromResult(_warehouses.FirstOrDefault(w => w.Id == id) ?? (Warehouse?.Id == id ? Warehouse : null));
        public Task<Warehouse?> GetByCodeAsync(Guid tenantId, string code, CancellationToken ct = default)
            => Task.FromResult(Warehouse?.Code == code ? Warehouse : null);
        public Task<IReadOnlyList<Warehouse>> ListAsync(
            Guid tenantId, int page, int pageSize, string? search, Guid? branchId, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<Warehouse>>(
                _warehouses.Where(w => branchId is null || w.BranchId == branchId).ToList());
        public Task<int> CountAsync(Guid tenantId, string? search, Guid? branchId, CancellationToken ct = default)
            => Task.FromResult(_warehouses.Count);
        public Task AddAsync(Warehouse warehouse, CancellationToken ct = default) => Task.CompletedTask;
    }

    private sealed class StubProductRepository : IProductRepository
    {
        private readonly Dictionary<Guid, Product> _products = new();

        public void Add(Product product) => _products[product.Id] = product;

        public Task<Product?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken ct = default)
            => Task.FromResult(_products.GetValueOrDefault(id));
        public Task<Product?> GetBySkuAsync(Guid tenantId, string sku, CancellationToken ct = default)
            => Task.FromResult(_products.Values.FirstOrDefault(p => p.Sku == sku));
        public Task<Product?> GetByBarcodeAsync(Guid tenantId, string barcode, CancellationToken ct = default)
            => Task.FromResult(_products.Values.FirstOrDefault(p => p.Barcode == barcode));
        public Task<IReadOnlyList<Product>> ListAsync(
            Guid tenantId, int page, int pageSize, ProductListFilter filter, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<Product>>(_products.Values.ToList());
        public Task<int> CountAsync(Guid tenantId, ProductListFilter filter, CancellationToken ct = default)
            => Task.FromResult(_products.Count);
        public Task AddAsync(Product product, CancellationToken ct = default) => Task.CompletedTask;
        public Task<bool> VariantSkuExistsAsync(Guid tenantId, string sku, Guid? excludeProductId = null, CancellationToken ct = default)
            => Task.FromResult(false);
        public Task<bool> VariantBarcodeExistsAsync(Guid tenantId, string barcode, Guid? excludeProductId = null, CancellationToken ct = default)
            => Task.FromResult(false);
    }

    private sealed class StubUnitOfMeasureRepository : IUnitOfMeasureRepository
    {
        public UnitOfMeasure? UnitOfMeasure { get; set; }

        public Task<UnitOfMeasure?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken ct = default)
            => Task.FromResult(UnitOfMeasure?.Id == id ? UnitOfMeasure : null);
        public Task<UnitOfMeasure?> GetByNameAsync(Guid tenantId, string name, CancellationToken ct = default)
            => Task.FromResult(UnitOfMeasure?.Name == name ? UnitOfMeasure : null);
        public Task<IReadOnlyList<UnitOfMeasure>> ListAsync(Guid tenantId, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<UnitOfMeasure>>(UnitOfMeasure is null ? Array.Empty<UnitOfMeasure>() : new[] { UnitOfMeasure });
        public Task AddAsync(UnitOfMeasure unitOfMeasure, CancellationToken ct = default) => Task.CompletedTask;
        public Task RemoveAsync(UnitOfMeasure unitOfMeasure, CancellationToken ct = default) => Task.CompletedTask;
    }

    private sealed class StubPriceListRepository : IPriceListRepository
    {
        public PriceList? Default { get; set; }
        private readonly Dictionary<Guid, List<ProductPrice>> _candidates = new();

        public void AddCandidate(Guid productId, decimal price)
            => _candidates[productId] =
            [
                ProductPrice.Assign(
                    TenantId, Default!.Id, Guid.NewGuid(), productId, variantId: null, branchId: null,
                    PriceType.Retail, price, Default.Currency, minQuantity: 1m,
                    effectiveFrom: null, effectiveTo: null, isActive: true),
            ];

        public void RemoveCandidate(Guid productId) => _candidates.Remove(productId);

        public Task<PriceList?> GetByIdAsync(Guid tenantId, Guid id, bool includePrices = false, CancellationToken ct = default)
            => Task.FromResult(Default?.Id == id ? Default : null);
        public Task<PriceList?> GetByNameAsync(Guid tenantId, string name, CancellationToken ct = default)
            => Task.FromResult(Default?.Name == name ? Default : null);
        public Task<PriceList?> GetDefaultAsync(Guid tenantId, CancellationToken ct = default)
            => Task.FromResult(Default);
        public Task<IReadOnlyList<PriceList>> ListAsync(Guid tenantId, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<PriceList>>(Default is null ? Array.Empty<PriceList>() : new[] { Default });
        public Task<IReadOnlyList<ProductPrice>> ResolvePricesAsync(
            Guid tenantId, Guid priceListId, Guid productId, Guid? variantId, Guid? branchId,
            PriceType priceType, decimal quantity, DateTime onDate, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<ProductPrice>>(
                _candidates.GetValueOrDefault(productId) ?? new List<ProductPrice>());
        public Task AddAsync(PriceList priceList, CancellationToken ct = default) => Task.CompletedTask;
    }

    private sealed class StubTaxRuleRepository : ITaxRuleRepository
    {
        public TaxCategory? Category { get; set; }

        public Task<TaxRegime?> GetRegimeForTenantAsync(Guid tenantId, CancellationToken ct = default)
            => Task.FromResult<TaxRegime?>(null);
        public Task<IReadOnlyList<TaxCategory>> ListCategoriesAsync(CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<TaxCategory>>(Array.Empty<TaxCategory>());

        public Task<TaxCategory?> GetCategoryByIdAsync(Guid id, CancellationToken ct = default)
            => Task.FromResult(Category?.Id == id ? Category : null);
        public Task<IReadOnlyList<TaxCategory>> ListCategoriesByCodesAsync(IEnumerable<string> codes, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<TaxCategory>>(Category is null ? Array.Empty<TaxCategory>() : new[] { Category });
        public Task<IReadOnlyList<TaxRule>> ListEffectiveRulesAsync(Guid regimeId, DateTime onDate, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<TaxRule>>(Array.Empty<TaxRule>());
        public Task<IReadOnlyList<TaxExemption>> ListExemptionsAsync(Guid tenantId, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<TaxExemption>>(Array.Empty<TaxExemption>());
    }

    private sealed class StubStockRepository : IStockRepository
    {
        public StockBalance? Balance { get; set; }
        public List<StockMovement> Movements { get; } = new();

        public Task<StockBalance?> GetBalanceAsync(
            Guid tenantId, Guid warehouseId, Guid stockLocationId, Guid productId, Guid? variantId, CancellationToken ct = default)
            => Task.FromResult(Balance);
        public Task<StockBalance?> GetBalanceWithLockAsync(
            Guid tenantId, Guid warehouseId, Guid stockLocationId, Guid productId, Guid? variantId, CancellationToken ct = default)
            => Task.FromResult(Balance);
        public Task<StockBalance> GetOrCreateBalanceAsync(
            Guid tenantId, Guid warehouseId, Guid stockLocationId, Guid productId, Guid? variantId, CancellationToken ct = default)
            => Task.FromResult(Balance ?? throw new InvalidOperationException("No balance configured."));
        public Task AddMovementAsync(StockMovement movement, CancellationToken ct = default)
        {
            Movements.Add(movement);
            return Task.CompletedTask;
        }
        public Task<IReadOnlyList<StockBalance>> ListBalancesAsync(
            Guid tenantId, int page, int pageSize, Guid? warehouseId = null, Guid? productId = null,
            string? search = null, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<StockBalance>>(Balance is null ? Array.Empty<StockBalance>() : new[] { Balance });
        public Task<int> CountBalancesAsync(
            Guid tenantId, Guid? warehouseId = null, Guid? productId = null, string? search = null, CancellationToken ct = default)
            => Task.FromResult(Balance is null ? 0 : 1);
        public Task<IReadOnlyList<StockMovement>> ListMovementsAsync(
            Guid tenantId, int page, int pageSize, Guid? warehouseId = null, Guid? productId = null,
            StockMovementType? type = null, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<StockMovement>>(Movements);
        public Task<int> CountMovementsAsync(
            Guid tenantId, Guid? warehouseId = null, Guid? productId = null,
            StockMovementType? type = null, CancellationToken ct = default)
            => Task.FromResult(Movements.Count);
        public Task<IReadOnlyList<StockMovement>> ListMovementsByReferenceAsync(
            Guid tenantId, string referenceType, Guid referenceId,
            StockMovementType? type = null, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<StockMovement>>(Movements
                .Where(m => m.ReferenceType == referenceType
                    && m.ReferenceId == referenceId
                    && (type == null || m.MovementType == type.Value))
                .ToList());
    }

    private sealed class StubSaleRepository : ISaleRepository
    {
        public Sale? Added { get; private set; }
        public Sale? Replay { get; set; }

        public Task AddAsync(Sale sale, CancellationToken ct = default)
        {
            Added = sale;
            return Task.CompletedTask;
        }
        public Task UpdateAsync(Sale sale, CancellationToken ct = default) => Task.CompletedTask;
        public Task<Sale?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken ct = default)
            => Task.FromResult(Added?.Id == id ? Added : Replay);
        public Task<Sale?> GetByClientSaleIdAsync(Guid tenantId, Guid clientSaleId, CancellationToken ct = default)
            => Task.FromResult(Replay);
        public Task<IReadOnlyList<Sale>> ListAsync(
            Guid tenantId, int page, int pageSize, SaleListFilter filter, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<Sale>>(Added is null ? Array.Empty<Sale>() : new[] { Added });
        public Task<int> CountAsync(Guid tenantId, SaleListFilter filter, CancellationToken ct = default)
            => Task.FromResult(Added is null ? 0 : 1);
    }

    private sealed class StubNumberSequenceRepository : INumberSequenceRepository
    {
        public int AllocationCount { get; private set; }
        public string Number { get; set; } = "S-2026-000001";

        public Task<string> AllocateAsync(Guid tenantId, string scope, DateTime date, CancellationToken ct = default)
        {
            AllocationCount++;
            return Task.FromResult(Number);
        }
    }

    private sealed class StubTaxEngine : ITaxEngine
    {
        public Task<TaxCalculationResult> CalculateAsync(TaxCalculationContext context, CancellationToken ct = default)
        {
            var snapshots = new List<TaxLineSnapshot>();
            foreach (var item in context.Items)
            {
                var gross = Round(item.UnitPrice * item.Quantity);
                var baseAmount = Round(gross / 1.18m);
                var taxAmount = Round(gross - baseAmount);
                snapshots.Add(new TaxLineSnapshot(
                    item.ItemId, "A", 0.18m, baseAmount, taxAmount, gross, Guid.NewGuid()));
            }

            return Task.FromResult(new TaxCalculationResult(
                snapshots.Sum(s => s.BaseAmount),
                snapshots.Sum(s => s.TaxAmount),
                snapshots));
        }

        private static decimal Round(decimal value)
            => Math.Round(value, 2, MidpointRounding.AwayFromZero);
    }
}

public sealed class CreateSaleCommandValidatorTests
{
    private static CreateSaleCommand Valid() => new(
        BranchId: Guid.NewGuid(),
        WarehouseId: null,
        PriceListId: null,
        ClientSaleId: Guid.NewGuid(),
        Source: SaleSource.Online,
        EffectiveAt: DateTime.UtcNow.AddMinutes(-1),
        IsElectronicPayment: false,
        IsVatRegistered: null,
        CustomerName: null,
        CustomerPhone: null,
        CustomerTin: null,
        Lines: [new CreateSaleLineInput(Guid.NewGuid(), null, 1m)],
        Payments: [new CreateSalePaymentInput(PaymentMethod.Cash, 100m)]);

    [Fact]
    public void ValidCommand_Passes()
    {
        var validator = new CreateSaleCommandValidator();
        Assert.True(validator.Validate(Valid()).IsValid);
    }

    [Fact]
    public void FutureEffectiveAt_BeyondSkew_IsRejected()
    {
        var validator = new CreateSaleCommandValidator();
        var command = Valid() with { EffectiveAt = DateTime.UtcNow.AddMinutes(10) };
        Assert.False(validator.Validate(command).IsValid);
    }

    [Fact]
    public void EmptyLines_AreRejected()
    {
        var validator = new CreateSaleCommandValidator();
        var command = Valid() with { Lines = [] };
        Assert.False(validator.Validate(command).IsValid);
    }

    [Fact]
    public void FractionalQuantityBelowOne_IsRejected()
    {
        var validator = new CreateSaleCommandValidator();
        var command = Valid() with { Lines = [new CreateSaleLineInput(Guid.NewGuid(), null, 0.5m)] };
        Assert.False(validator.Validate(command).IsValid);
    }

    [Fact]
    public void NoPayments_AreRejected()
    {
        var validator = new CreateSaleCommandValidator();
        var command = Valid() with { Payments = [] };
        Assert.False(validator.Validate(command).IsValid);
    }

    [Fact]
    public void InvalidSource_IsRejected()
    {
        var validator = new CreateSaleCommandValidator();
        var command = Valid() with { Source = (SaleSource)999 };
        Assert.False(validator.Validate(command).IsValid);
    }

    [Fact]
    public void NegativeDiscount_IsRejected()
    {
        var validator = new CreateSaleCommandValidator();
        var command = Valid() with { Lines = [new CreateSaleLineInput(Guid.NewGuid(), null, 1m, DiscountAmount: -1m)] };
        Assert.False(validator.Validate(command).IsValid);
    }
}

public sealed class SalesQueriesValidatorsTests
{
    [Fact]
    public void GetSaleQuery_EmptyId_IsRejected()
    {
        var validator = new GetSaleQueryValidator();
        Assert.False(validator.Validate(new GetSaleQuery(Guid.Empty)).IsValid);
        Assert.True(validator.Validate(new GetSaleQuery(Guid.NewGuid())).IsValid);
    }

    [Fact]
    public void ListSalesQuery_InvalidPaging_IsRejected()
    {
        var validator = new ListSalesQueryValidator();
        Assert.False(validator.Validate(new ListSalesQuery(0, 10, null, null, null, null, null)).IsValid);
        Assert.False(validator.Validate(new ListSalesQuery(1, 0, null, null, null, null, null)).IsValid);
        Assert.False(validator.Validate(new ListSalesQuery(1, 101, null, null, null, null, null)).IsValid);
    }

    [Fact]
    public void ListSalesQuery_InvertedDateRange_IsRejected()
    {
        var validator = new ListSalesQueryValidator();
        var from = new DateTime(2026, 8, 31, 0, 0, 0, DateTimeKind.Utc);
        var to = new DateTime(2026, 8, 1, 0, 0, 0, DateTimeKind.Utc);
        Assert.False(validator.Validate(new ListSalesQuery(1, 20, null, from, to, null, null)).IsValid);
    }

    [Fact]
    public void ListSalesQuery_ValidPagingAndRange_Passes()
    {
        var validator = new ListSalesQueryValidator();
        var from = new DateTime(2026, 8, 1, 0, 0, 0, DateTimeKind.Utc);
        var to = new DateTime(2026, 8, 31, 0, 0, 0, DateTimeKind.Utc);
        Assert.True(validator.Validate(new ListSalesQuery(1, 20, null, from, to, null, null)).IsValid);
        Assert.True(validator.Validate(new ListSalesQuery(3, 100, null, null, null, SaleStatus.Completed, "a")).IsValid);
    }
}
