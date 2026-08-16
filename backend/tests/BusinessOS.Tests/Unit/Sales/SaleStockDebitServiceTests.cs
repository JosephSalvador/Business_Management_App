using BusinessOS.Application.Ports;
using BusinessOS.Application.Sales;
using BusinessOS.Domain.Inventory;

namespace BusinessOS.Tests.Unit.Sales;

public sealed class SaleStockDebitServiceTests
{
    private static readonly Guid TenantId = new("11111111-1111-1111-1111-111111111111");
    private static readonly Guid BranchId = new("22222222-2222-2222-2222-222222222222");
    private static readonly Guid WarehouseId = new("33333333-3333-3333-3333-333333333333");
    private static readonly Guid LocationId = new("44444444-4444-4444-4444-444444444444");
    private static readonly Guid SaleId = new("55555555-5555-5555-5555-555555555555");
    private static readonly Guid ProductId = new("66666666-6666-6666-6666-666666666666");
    private static readonly Guid ServiceProductId = new("77777777-7777-7777-7777-777777777777");
    private static readonly Guid UnitOfMeasureId = new("88888888-8888-8888-8888-888888888888");
    private static readonly DateTime OnDate = new(2026, 8, 15, 12, 0, 0, DateTimeKind.Utc);

    private static StockDebitLine StockedLine(decimal quantity, Guid? variantId = null, Guid? productId = null)
        => new(productId ?? ProductId, variantId, "Rice 1kg", UnitOfMeasureId, quantity, DebitsStock: true);

    private static StockDebitLine ServiceLine(decimal quantity)
        => new(ServiceProductId, null, "Repair service", UnitOfMeasureId, quantity, DebitsStock: false);

    private static StockDebitRequest Request(params StockDebitLine[] lines)
        => new(TenantId, BranchId, WarehouseId, LocationId, SaleId, OnDate, CreatedBy: null, lines);

    [Fact]
    public async Task Debit_DebitsStockAndWritesSaleMovement()
    {
        var stock = new FakeStockRepository();
        stock.Seed(TenantId, WarehouseId, LocationId, ProductId, null, 100m);
        var service = new SaleStockDebitService(stock);

        var result = await service.DebitAsync(Request(StockedLine(3m)), CancellationToken.None);

        Assert.True(result.IsSuccess);
        var movement = Assert.Single(stock.Movements);
        Assert.Equal(StockMovementType.Sale, movement.MovementType);
        Assert.Equal(-3m, movement.Quantity);
        Assert.Equal("Sale", movement.ReferenceType);
        Assert.Equal(SaleId, movement.ReferenceId);
        Assert.Equal(ProductId, movement.ProductId);
        Assert.Equal(WarehouseId, movement.WarehouseId);
        Assert.Equal(LocationId, movement.StockLocationId);
        Assert.Equal(UnitOfMeasureId, movement.UnitOfMeasureId);
        Assert.Equal(97m, stock.Balance(ProductId).Quantity);
    }

    [Fact]
    public async Task Debit_ExactlyEnoughStock_Succeeds()
    {
        var stock = new FakeStockRepository();
        stock.Seed(TenantId, WarehouseId, LocationId, ProductId, null, 3m);
        var service = new SaleStockDebitService(stock);

        var result = await service.DebitAsync(Request(StockedLine(3m)), CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(0m, stock.Balance(ProductId).Quantity);
    }

    [Fact]
    public async Task Debit_InsufficientStock_RejectsWholeSale()
    {
        var stock = new FakeStockRepository();
        stock.Seed(TenantId, WarehouseId, LocationId, ProductId, null, 2m);
        var service = new SaleStockDebitService(stock);

        var result = await service.DebitAsync(Request(StockedLine(3m)), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("Validation", result.Error.Code);
        Assert.Empty(stock.Movements);
        Assert.Equal(2m, stock.Balance(ProductId).Quantity);
    }

    [Fact]
    public async Task Debit_MissingBalance_Rejects()
    {
        var stock = new FakeStockRepository();
        var service = new SaleStockDebitService(stock);

        var result = await service.DebitAsync(Request(StockedLine(3m)), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Empty(stock.Movements);
    }

    [Fact]
    public async Task Debit_MultiLineAtomicRejection_TouchesNothing()
    {
        var stock = new FakeStockRepository();
        stock.Seed(TenantId, WarehouseId, LocationId, ProductId, null, 100m);
        var secondProduct = Guid.NewGuid();
        stock.Seed(TenantId, WarehouseId, LocationId, secondProduct, null, 1m);
        var service = new SaleStockDebitService(stock);

        var result = await service.DebitAsync(
            Request(StockedLine(3m), StockedLine(2m, productId: secondProduct)), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Empty(stock.Movements);
        Assert.Equal(100m, stock.Balance(ProductId).Quantity);
        Assert.Equal(1m, stock.Balance(secondProduct).Quantity);
    }

    [Fact]
    public async Task Debit_SkipsServiceLines()
    {
        var stock = new FakeStockRepository();
        var service = new SaleStockDebitService(stock);

        var result = await service.DebitAsync(Request(ServiceLine(5m)), CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Empty(stock.Movements);
    }

    [Fact]
    public async Task Debit_MixedCart_DebitsOnlyStockedLines()
    {
        var stock = new FakeStockRepository();
        stock.Seed(TenantId, WarehouseId, LocationId, ProductId, null, 10m);
        var service = new SaleStockDebitService(stock);

        var result = await service.DebitAsync(
            Request(StockedLine(3m), ServiceLine(5m)), CancellationToken.None);

        Assert.True(result.IsSuccess);
        var movement = Assert.Single(stock.Movements);
        Assert.Equal(ProductId, movement.ProductId);
        Assert.Equal(-3m, movement.Quantity);
        Assert.Equal(7m, stock.Balance(ProductId).Quantity);
    }

    [Fact]
    public async Task Debit_EmptyCart_ReturnsSuccess()
    {
        var stock = new FakeStockRepository();
        var service = new SaleStockDebitService(stock);

        var result = await service.DebitAsync(Request(), CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Empty(stock.Movements);
    }

    private sealed class FakeStockRepository : IStockRepository
    {
        private readonly Dictionary<(Guid Warehouse, Guid Location, Guid Product, Guid? Variant), StockBalance> _byKey = new();

        public List<StockMovement> Movements { get; } = [];

        public IReadOnlyList<StockBalance> Balances => _byKey.Values.ToList();

        public StockBalance Balance(Guid productId, Guid? variantId = null)
            => _byKey[(WarehouseId, LocationId, productId, variantId)];

        public void Seed(Guid tenantId, Guid warehouseId, Guid locationId, Guid productId, Guid? variantId, decimal quantity)
        {
            var balance = StockBalance.Create(tenantId, warehouseId, locationId, productId, variantId);
            balance.Apply(quantity);
            _byKey[(warehouseId, locationId, productId, variantId)] = balance;
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
            {
                return Task.FromResult(existing);
            }

            var created = StockBalance.Create(tenantId, warehouseId, stockLocationId, productId, variantId);
            _byKey[key] = created;
            return Task.FromResult(created);
        }

        public Task AddMovementAsync(StockMovement movement, CancellationToken cancellationToken = default)
        {
            Movements.Add(movement);
            return Task.CompletedTask;
        }

        public Task<IReadOnlyList<StockBalance>> ListBalancesAsync(
            Guid tenantId, int page, int pageSize, Guid? warehouseId = null, Guid? productId = null,
            string? search = null, CancellationToken cancellationToken = default)
            => Task.FromResult<IReadOnlyList<StockBalance>>(Balances);

        public Task<int> CountBalancesAsync(
            Guid tenantId, Guid? warehouseId = null, Guid? productId = null,
            string? search = null, CancellationToken cancellationToken = default)
            => Task.FromResult(_byKey.Count);

        public Task<IReadOnlyList<StockMovement>> ListMovementsAsync(
            Guid tenantId, int page, int pageSize, Guid? warehouseId = null, Guid? productId = null,
            StockMovementType? type = null, CancellationToken cancellationToken = default)
            => Task.FromResult<IReadOnlyList<StockMovement>>(Movements);

        public Task<int> CountMovementsAsync(
            Guid tenantId, Guid? warehouseId = null, Guid? productId = null,
            StockMovementType? type = null, CancellationToken cancellationToken = default)
            => Task.FromResult(Movements.Count);
    }
}
