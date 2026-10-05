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
    public async Task Debit_OversellsStock_StillDebitsToNegativeBalance()
    {
        var stock = new FakeStockRepository();
        stock.Seed(TenantId, WarehouseId, LocationId, ProductId, null, 2m);
        var service = new SaleStockDebitService(stock);

        var result = await service.DebitAsync(Request(StockedLine(3m)), CancellationToken.None);

        Assert.True(result.IsSuccess);
        var movement = Assert.Single(stock.Movements);
        Assert.Equal(StockMovementType.Sale, movement.MovementType);
        Assert.Equal(-3m, movement.Quantity);
        Assert.Equal(-1m, stock.Balance(ProductId).Quantity);
    }

    [Fact]
    public async Task Debit_MissingBalance_CreatesBalanceAndDebits()
    {
        var stock = new FakeStockRepository();
        var service = new SaleStockDebitService(stock);

        var result = await service.DebitAsync(Request(StockedLine(3m)), CancellationToken.None);

        Assert.True(result.IsSuccess);
        var movement = Assert.Single(stock.Movements);
        Assert.Equal(ProductId, movement.ProductId);
        Assert.Equal(-3m, movement.Quantity);
        Assert.Equal(-3m, stock.Balance(ProductId).Quantity);
    }

    [Fact]
    public async Task Debit_MultiLine_OversellsAllLines_StillSucceeds()
    {
        var stock = new FakeStockRepository();
        stock.Seed(TenantId, WarehouseId, LocationId, ProductId, null, 100m);
        var secondProduct = Guid.NewGuid();
        stock.Seed(TenantId, WarehouseId, LocationId, secondProduct, null, 1m);
        var service = new SaleStockDebitService(stock);

        var result = await service.DebitAsync(
            Request(StockedLine(3m), StockedLine(2m, productId: secondProduct)), CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(2, stock.Movements.Count);
        Assert.Equal(97m, stock.Balance(ProductId).Quantity);
        Assert.Equal(-1m, stock.Balance(secondProduct).Quantity);
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

    private static StockMovement DebitMovement(
        decimal quantity,
        Guid? productId = null,
        Guid? variantId = null,
        Guid? warehouseId = null,
        Guid? locationId = null,
        Guid? unitOfMeasureId = null)
        => StockMovement.Record(
            TenantId, BranchId, warehouseId ?? WarehouseId, locationId ?? LocationId,
            productId ?? ProductId, variantId, StockMovementType.Sale, -quantity,
            unitOfMeasureId ?? UnitOfMeasureId, OnDate, referenceType: "Sale",
            referenceId: SaleId, createdBy: null);

    private static StockRestoreRequest RestoreRequest(params StockMovement[] movements)
        => new(TenantId, SaleId, OnDate, CreatedBy: Guid.NewGuid(), Reason: "Wrong item", movements);

    [Fact]
    public async Task Restore_ReversesEveryDebitMovement_AndCreditsBalance()
    {
        var stock = new FakeStockRepository();
        stock.Seed(TenantId, WarehouseId, LocationId, ProductId, null, 97m);
        var service = new SaleStockDebitService(stock);

        await service.RestoreAsync(RestoreRequest(DebitMovement(3m)), CancellationToken.None);

        var reversal = Assert.Single(stock.Movements);
        Assert.Equal(StockMovementType.SaleVoid, reversal.MovementType);
        Assert.Equal(3m, reversal.Quantity);
        Assert.Equal("Sale", reversal.ReferenceType);
        Assert.Equal(SaleId, reversal.ReferenceId);
        Assert.Equal(ProductId, reversal.ProductId);
        Assert.Equal(WarehouseId, reversal.WarehouseId);
        Assert.Equal(LocationId, reversal.StockLocationId);
        Assert.Equal(UnitOfMeasureId, reversal.UnitOfMeasureId);
        Assert.Equal(100m, stock.Balance(ProductId).Quantity);
    }

    [Fact]
    public async Task Restore_MultipleDebits_WritesOneReversalEach()
    {
        var stock = new FakeStockRepository();
        stock.Seed(TenantId, WarehouseId, LocationId, ProductId, null, 10m);
        var secondProduct = Guid.NewGuid();
        stock.Seed(TenantId, WarehouseId, LocationId, secondProduct, null, 5m);
        var service = new SaleStockDebitService(stock);

        await service.RestoreAsync(
            RestoreRequest(DebitMovement(3m), DebitMovement(2m, productId: secondProduct)),
            CancellationToken.None);

        Assert.Equal(2, stock.Movements.Count);
        Assert.All(stock.Movements, m => Assert.Equal(StockMovementType.SaleVoid, m.MovementType));
        Assert.Equal(13m, stock.Balance(ProductId).Quantity);
        Assert.Equal(7m, stock.Balance(secondProduct).Quantity);
    }

    [Fact]
    public async Task Restore_NoMovements_WritesNothing()
    {
        var stock = new FakeStockRepository();
        var service = new SaleStockDebitService(stock);

        await service.RestoreAsync(RestoreRequest(), CancellationToken.None);

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
                .Where(m => m.ReferenceType == referenceType
                    && m.ReferenceId == referenceId
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
