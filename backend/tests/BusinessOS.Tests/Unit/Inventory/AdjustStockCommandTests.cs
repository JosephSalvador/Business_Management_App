using BusinessOS.Application.Features.Inventory.Commands;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Catalog;
using BusinessOS.Domain.Inventory;
using BusinessOS.Shared;

namespace BusinessOS.Tests.Unit.Inventory;

public sealed class AdjustStockCommandTests
{
    private static readonly Guid TenantId = new("11111111-1111-1111-1111-111111111111");
    private static readonly Guid UserId = new("22222222-2222-2222-2222-222222222222");
    private static readonly Guid BranchId = new("33333333-3333-3333-3333-333333333333");
    private static readonly Guid UnitOfMeasureId = new("77777777-7777-7777-7777-777777777777");
    private static readonly DateTime OnDate = new(2026, 8, 17, 12, 0, 0, DateTimeKind.Utc);

    private static Product CreateProduct(string name, ProductType type = ProductType.Product)
        => Product.Create(TenantId, name, null, null, null, null, null, UnitOfMeasureId, type);

    [Fact]
    public async Task Handle_PositiveAdjustment_IncreasesBalance()
    {
        var product = CreateProduct("Rice");
        var (handler, stock, warehouse, location) = CreateHandler(product);
        stock.SeedBalance(TenantId, warehouse.Id, location.Id, product.Id, null, 50m);

        var result = await handler.Handle(
            new AdjustStockCommand(warehouse.Id, null, product.Id, null, 10m, "Found extra", OnDate),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(60m, result.Value.Quantity);
        Assert.Single(stock.Movements);
        Assert.Equal(StockMovementType.Adjustment, stock.Movements[0].MovementType);
        Assert.Equal(10m, stock.Movements[0].Quantity);
    }

    [Fact]
    public async Task Handle_NegativeAdjustment_DecreasesBalance()
    {
        var product = CreateProduct("Rice");
        var (handler, stock, warehouse, location) = CreateHandler(product);
        stock.SeedBalance(TenantId, warehouse.Id, location.Id, product.Id, null, 50m);

        var result = await handler.Handle(
            new AdjustStockCommand(warehouse.Id, null, product.Id, null, -5m, "Damaged", OnDate),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(45m, result.Value.Quantity);
    }

    [Fact]
    public async Task Handle_NegativeAdjustment_BelowZero_Rejects()
    {
        var product = CreateProduct("Rice");
        var (handler, stock, warehouse, location) = CreateHandler(product);
        stock.SeedBalance(TenantId, warehouse.Id, location.Id, product.Id, null, 3m);

        var result = await handler.Handle(
            new AdjustStockCommand(warehouse.Id, null, product.Id, null, -5m, "Too much", OnDate),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("Validation", result.Error.Code);
        Assert.Empty(stock.Movements);
        Assert.Equal(3m, stock.Balance(product.Id).Quantity);
    }

    [Fact]
    public async Task Handle_NoExistingBalance_PositiveAdjustment_CreatesBalance()
    {
        var product = CreateProduct("Rice");
        var (handler, stock, warehouse, location) = CreateHandler(product);

        var result = await handler.Handle(
            new AdjustStockCommand(warehouse.Id, null, product.Id, null, 20m, "First adjustment", OnDate),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(20m, result.Value.Quantity);
        Assert.Single(stock.Movements);
    }

    [Fact]
    public async Task Handle_NoExistingBalance_NegativeAdjustment_Rejects()
    {
        var product = CreateProduct("Rice");
        var (handler, stock, warehouse, location) = CreateHandler(product);

        var result = await handler.Handle(
            new AdjustStockCommand(warehouse.Id, null, product.Id, null, -5m, "Cannot adjust", OnDate),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("Validation", result.Error.Code);
    }

    [Fact]
    public async Task Handle_SameIdempotencyKey_ReplaysWithoutApplyingTwice()
    {
        var product = CreateProduct("Rice");
        var (handler, stock, warehouse, location) = CreateHandler(product);
        stock.SeedBalance(TenantId, warehouse.Id, location.Id, product.Id, null, 50m);
        var key = Guid.NewGuid();

        var first = await handler.Handle(
            new AdjustStockCommand(warehouse.Id, null, product.Id, null, 10m, "Found extra", OnDate, IdempotencyKey: key),
            CancellationToken.None);
        var replay = await handler.Handle(
            new AdjustStockCommand(warehouse.Id, null, product.Id, null, 10m, "Found extra", OnDate, IdempotencyKey: key),
            CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(replay.IsSuccess);
        Assert.Equal(60m, first.Value.Quantity);
        Assert.Equal(60m, replay.Value.Quantity);
        Assert.Single(stock.Movements);
        Assert.Equal(key.ToString(), stock.Movements[0].CorrelationId);
    }

    [Fact]
    public async Task Handle_DifferentIdempotencyKeys_ApplyEachAdjustment()
    {
        var product = CreateProduct("Rice");
        var (handler, stock, warehouse, location) = CreateHandler(product);
        stock.SeedBalance(TenantId, warehouse.Id, location.Id, product.Id, null, 50m);

        var first = await handler.Handle(
            new AdjustStockCommand(warehouse.Id, null, product.Id, null, 5m, "Extra", OnDate, IdempotencyKey: Guid.NewGuid()),
            CancellationToken.None);
        var second = await handler.Handle(
            new AdjustStockCommand(warehouse.Id, null, product.Id, null, 5m, "Extra again", OnDate, IdempotencyKey: Guid.NewGuid()),
            CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(second.IsSuccess);
        Assert.Equal(60m, second.Value.Quantity);
        Assert.Equal(2, stock.Movements.Count);
    }

    [Fact]
    public async Task Handle_NoIdempotencyKey_AppliesNormally()
    {
        var product = CreateProduct("Rice");
        var (handler, stock, warehouse, location) = CreateHandler(product);
        stock.SeedBalance(TenantId, warehouse.Id, location.Id, product.Id, null, 50m);

        var result = await handler.Handle(
            new AdjustStockCommand(warehouse.Id, null, product.Id, null, 10m, "Found extra", OnDate),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(60m, result.Value.Quantity);
        Assert.Single(stock.Movements);
        Assert.Null(stock.Movements[0].CorrelationId);
    }

    [Fact]
    public async Task Handle_WarehouseNotFound_ReturnsNotFound()
    {
        var product = CreateProduct("Rice");
        var (handler, stock, warehouse, location) = CreateHandler(product);

        var result = await handler.Handle(
            new AdjustStockCommand(Guid.NewGuid(), null, product.Id, null, 5m, "Reason", OnDate),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("NotFound", result.Error.Code);
    }

    [Fact]
    public async Task Handle_ProductNotFound_ReturnsNotFound()
    {
        var product = CreateProduct("Rice");
        var (handler, stock, warehouse, location) = CreateHandler(product);
        stock.SeedBalance(TenantId, warehouse.Id, location.Id, product.Id, null, 10m);

        var result = await handler.Handle(
            new AdjustStockCommand(warehouse.Id, null, Guid.NewGuid(), null, 5m, "Reason", OnDate),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("NotFound", result.Error.Code);
    }

    [Fact]
    public async Task Handle_ServiceProduct_Rejects()
    {
        var product = CreateProduct("Rice");
        var serviceProduct = CreateProduct("Repair", ProductType.Service);
        var (handler, stock, warehouse, location) = CreateHandler(product, serviceProduct);

        var result = await handler.Handle(
            new AdjustStockCommand(warehouse.Id, null, serviceProduct.Id, null, 5m, "Reason", OnDate),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("Validation", result.Error.Code);
    }

    private static (AdjustStockCommandHandler Handler, FakeStockRepository Stock, Warehouse Warehouse, StockLocation Location) CreateHandler(params Product[] products)
    {
        var stock = new FakeStockRepository();
        var warehouse = Warehouse.Create(TenantId, BranchId, "WH", "Main Warehouse");
        var location = warehouse.Locations.First();
        var productDict = products.ToDictionary(p => p.Id);
        var warehouses = new FakeWarehouseRepository(warehouse);
        var tenantCtx = new FakeTenantContext(TenantId, UserId);
        var units = new FakeUnitOfMeasureRepository();
        var handler = new AdjustStockCommandHandler(tenantCtx, warehouses, new FakeProductRepository(productDict), units, stock);
        return (handler, stock, warehouse, location);
    }

    private sealed class FakeTenantContext(Guid tenantId, Guid? userId) : ITenantContext
    {
        public Guid TenantId => tenantId;
        public Guid? UserId => userId;
        public string? IpAddress => "127.0.0.1";
        public string? UserAgent => null;
        public string? CurrentRefreshToken => null;
    }

    private sealed class FakeWarehouseRepository(Warehouse warehouse) : IWarehouseRepository
    {
        public Task<Warehouse?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken ct = default)
            => Task.FromResult<Warehouse?>(warehouse.Id == id ? warehouse : null);

        public Task<Warehouse?> GetByCodeAsync(Guid tenantId, string code, CancellationToken ct = default)
            => Task.FromResult<Warehouse?>(warehouse);

        public Task<IReadOnlyList<Warehouse>> ListAsync(
            Guid tenantId, int page, int pageSize, string? search = null, Guid? branchId = null,
            CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<Warehouse>>([warehouse]);

        public Task<int> CountAsync(Guid tenantId, string? search = null, Guid? branchId = null,
            CancellationToken ct = default) => Task.FromResult(1);

        public Task AddAsync(Warehouse w, CancellationToken ct = default) => Task.CompletedTask;
    }

    private sealed class FakeUnitOfMeasureRepository : IUnitOfMeasureRepository
    {
        public Task<UnitOfMeasure?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken ct = default)
        {
            var uom = UnitOfMeasure.Create(tenantId, "Units", "pcs");
            uom.Update("Units", "pcs");
            return Task.FromResult<UnitOfMeasure?>(uom);
        }
        public Task<UnitOfMeasure?> GetByNameAsync(Guid tenantId, string name, CancellationToken ct = default)
            => Task.FromResult<UnitOfMeasure?>(null);
        public Task<IReadOnlyList<UnitOfMeasure>> ListAsync(Guid tenantId, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<UnitOfMeasure>>(Array.Empty<UnitOfMeasure>());
        public Task AddAsync(UnitOfMeasure unitOfMeasure, CancellationToken ct = default) => Task.CompletedTask;
        public Task RemoveAsync(UnitOfMeasure unitOfMeasure, CancellationToken ct = default) => Task.CompletedTask;
    }

    private sealed class FakeProductRepository(Dictionary<Guid, Product> products) : IProductRepository
    {
        public Task<Product?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken ct = default)
            => Task.FromResult(products.TryGetValue(id, out var p) ? p : null);

        public Task<IReadOnlyList<Product>> GetByIdsAsync(Guid tenantId, IEnumerable<Guid> ids, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<Product>>(
                ids.Where(products.ContainsKey).Select(id => products[id]).ToList());

        public Task<Product?> GetBySkuAsync(Guid tenantId, string sku, CancellationToken ct = default)
            => Task.FromResult<Product?>(null);

        public Task<Product?> GetByBarcodeAsync(Guid tenantId, string barcode, CancellationToken ct = default)
            => Task.FromResult<Product?>(null);

        public Task<IReadOnlyList<Product>> ListAsync(
            Guid tenantId, int page, int pageSize, ProductListFilter filter, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<Product>>(products.Values.ToList());

        public Task<int> CountAsync(Guid tenantId, ProductListFilter filter, CancellationToken ct = default)
            => Task.FromResult(products.Count);

        public Task AddAsync(Product product, CancellationToken ct = default)
        {
            products[product.Id] = product;
            return Task.CompletedTask;
        }

        public Task<bool> VariantSkuExistsAsync(Guid tenantId, string sku, Guid? excludeProductId = null,
            CancellationToken ct = default) => Task.FromResult(false);

        public Task<bool> VariantBarcodeExistsAsync(Guid tenantId, string barcode, Guid? excludeProductId = null,
            CancellationToken ct = default) => Task.FromResult(false);
    }

    private sealed class FakeStockRepository : IStockRepository
    {
        private readonly Dictionary<(Guid Warehouse, Guid Location, Guid Product, Guid? Variant), StockBalance> _byKey = new();

        public List<StockMovement> Movements { get; } = [];

        public void SeedBalance(Guid tenantId, Guid warehouseId, Guid locationId, Guid productId, Guid? variantId, decimal quantity)
        {
            var balance = StockBalance.Create(tenantId, warehouseId, locationId, productId, variantId);
            balance.Apply(quantity);
            _byKey[(warehouseId, locationId, productId, variantId)] = balance;
        }

        public StockBalance Balance(Guid productId, Guid? variantId = null)
        {
            var key = _byKey.Keys.First(k => k.Product == productId && k.Variant == variantId);
            return _byKey[key];
        }

        public Task<StockBalance?> GetBalanceAsync(
            Guid tenantId, Guid warehouseId, Guid stockLocationId, Guid productId, Guid? variantId,
            CancellationToken cancellationToken = default)
            => Task.FromResult(_byKey.GetValueOrDefault((warehouseId, stockLocationId, productId, variantId)));

        public Task<StockBalance?> GetBalanceWithLockAsync(
            Guid tenantId, Guid warehouseId, Guid stockLocationId, Guid productId, Guid? variantId,
            CancellationToken cancellationToken = default)
            => Task.FromResult(_byKey.GetValueOrDefault((warehouseId, stockLocationId, productId, variantId)));

        public Task<StockBalance> GetOrCreateBalanceAsync(
            Guid tenantId, Guid warehouseId, Guid stockLocationId, Guid productId, Guid? variantId,
            CancellationToken cancellationToken = default)
        {
            var key = (warehouseId, stockLocationId, productId, variantId);
            if (_byKey.TryGetValue(key, out var existing))
                return Task.FromResult(existing);

            var created = StockBalance.Create(tenantId, warehouseId, stockLocationId, productId, variantId);
            _byKey[key] = created;
            return Task.FromResult(created);
        }

        public Task AddMovementAsync(StockMovement movement, CancellationToken cancellationToken = default)
        {
            Movements.Add(movement);
            return Task.CompletedTask;
        }

        public Task<StockMovement?> FindAdjustmentByKeyAsync(
            Guid tenantId, string key, CancellationToken cancellationToken = default)
            => Task.FromResult(Movements.FirstOrDefault(
                m => m.TenantId == tenantId
                    && m.MovementType == StockMovementType.Adjustment
                    && m.CorrelationId == key));

        public Task<IReadOnlyList<StockBalanceView>> ListBalancesAsync(
            Guid tenantId, int page, int pageSize, Guid? warehouseId = null, Guid? productId = null,
            string? search = null, CancellationToken cancellationToken = default)
            => Task.FromResult<IReadOnlyList<StockBalanceView>>(Array.Empty<StockBalanceView>());

        public Task<int> CountBalancesAsync(
            Guid tenantId, Guid? warehouseId = null, Guid? productId = null,
            string? search = null, CancellationToken cancellationToken = default)
            => Task.FromResult(_byKey.Count);

        public Task<IReadOnlyList<StockMovementView>> ListMovementsAsync(
            Guid tenantId, int page, int pageSize, Guid? warehouseId = null, Guid? productId = null,
            StockMovementType? type = null, CancellationToken cancellationToken = default)
            => Task.FromResult<IReadOnlyList<StockMovementView>>(Array.Empty<StockMovementView>());

        public Task<int> CountMovementsAsync(
            Guid tenantId, Guid? warehouseId = null, Guid? productId = null,
            StockMovementType? type = null, CancellationToken cancellationToken = default)
            => Task.FromResult(Movements.Count);

        public Task<IReadOnlyList<StockMovement>> ListMovementsByReferenceAsync(
            Guid tenantId, string referenceType, Guid referenceId,
            StockMovementType? type = null, CancellationToken cancellationToken = default)
            => Task.FromResult<IReadOnlyList<StockMovement>>(Movements
                .Where(m => m.ReferenceType == referenceType && m.ReferenceId == referenceId
                    && (type == null || m.MovementType == type.Value))
                .ToList());

        public Task<IReadOnlyList<StockSummaryRow>> GetStockSummaryAsync(
            Guid tenantId, DateTime from, DateTime to, Guid? warehouseId, CancellationToken cancellationToken = default)
            => Task.FromResult<IReadOnlyList<StockSummaryRow>>(new List<StockSummaryRow>());

        public Task<IReadOnlyList<StockMovementSummaryRow>> GetStockMovementSummaryAsync(
            Guid tenantId, DateTime from, DateTime to, Guid? warehouseId, CancellationToken cancellationToken = default)
            => Task.FromResult<IReadOnlyList<StockMovementSummaryRow>>(new List<StockMovementSummaryRow>());

        public Task<IReadOnlyList<LowStockReportItem>> GetLowStockReportAsync(
            Guid tenantId, decimal threshold, Guid? warehouseId, CancellationToken cancellationToken = default)
            => Task.FromResult<IReadOnlyList<LowStockReportItem>>(new List<LowStockReportItem>());

        public Task<IReadOnlyList<StockVelocityRow>> GetStockVelocityAsync(
            Guid tenantId, DateTime from, DateTime to, CancellationToken cancellationToken = default)
            => Task.FromResult<IReadOnlyList<StockVelocityRow>>(new List<StockVelocityRow>());
    }
}
