using BusinessOS.Application.Features.Sales;
using BusinessOS.Application.Features.Sales.Commands;
using BusinessOS.Application.Features.Sales.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Application.Sales;
using BusinessOS.Domain.Inventory;
using BusinessOS.Domain.Sales;
using BusinessOS.Shared;
using FluentValidation.TestHelper;

namespace BusinessOS.Tests.Unit.Sales;

public sealed class VoidSaleCommandTests
{
    private static readonly Guid TenantId = new("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
    private static readonly Guid BranchId = new("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb");
    private static readonly Guid WarehouseId = new("cccccccc-cccc-cccc-cccc-cccccccccccc");
    private static readonly Guid LocationId = new("dddddddd-dddd-dddd-dddd-dddddddddddd");
    private static readonly Guid CashierId = new("eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee");
    private static readonly Guid ProductId = new("ffffffff-ffff-ffff-ffff-ffffffffffff");
    private static readonly Guid UnitOfMeasureId = new("11111111-1111-1111-1111-111111111111");

    private static Sale BuildSale()
    {
        var line = SaleLine.Create(
            ProductId, null, "Rice 1kg", "RICE-1KG", null, UnitOfMeasureId, "kg",
            1m, 1000m, 0m, "A", 0.18m, Guid.NewGuid(), 847.46m, 152.54m, 1000m, 0);
        var payment = SalePayment.Create(PaymentMethod.Cash, 1000m, null, null, null, 0);

        return Sale.Create(
            TenantId, BranchId, WarehouseId, CashierId, Guid.NewGuid(),
            "S-2026-000001", SaleSource.Online,
            new DateTime(2026, 8, 15, 12, 0, 0, DateTimeKind.Utc),
            new DateTime(2026, 8, 15, 12, 0, 0, DateTimeKind.Utc),
            "TZS", priceListId: null, isPriceTaxInclusive: true, isElectronicPayment: false,
            customerId: null, customerName: null, customerTin: null, isVatRegistered: null,
            subtotal: 1000m, discountAmount: 0m, taxAmount: 152.54m, totalAmount: 1000m,
            amountPaid: 1000m, change: 0m, [line], [payment]);
    }

    private static StockMovement DebitMovement(Guid saleId) => StockMovement.Record(
        TenantId, BranchId, WarehouseId, LocationId, ProductId, null,
        StockMovementType.Sale, -1m, UnitOfMeasureId,
        new DateTime(2026, 8, 15, 12, 0, 0, DateTimeKind.Utc),
        referenceType: "Sale", referenceId: saleId, createdBy: CashierId);

    private sealed class World
    {
        public required Sale Sale { get; init; }
        public required StubSaleRepository Sales { get; init; }
        public required StubStockRepository Stock { get; init; }
        public required StubTenantContext TenantContext { get; init; }

        public VoidSaleCommandHandler CreateHandler() => new(
            TenantContext,
            Sales,
            Stock,
            new SaleStockDebitService(Stock));
    }

    private static World BuildWorld(bool withUser = true, bool alreadyVoided = false)
    {
        var sale = BuildSale();
        if (alreadyVoided)
        {
            sale.Void("First reason", CashierId, new DateTime(2026, 8, 15, 13, 0, 0, DateTimeKind.Utc));
        }

        var stock = new StubStockRepository();
        stock.Add(DebitMovement(sale.Id));

        var sales = new StubSaleRepository { Sale = sale };
        return new World
        {
            Sale = sale,
            Sales = sales,
            Stock = stock,
            TenantContext = new StubTenantContext { TenantId = TenantId, UserId = withUser ? CashierId : null },
        };
    }

    [Fact]
    public async Task Handle_CompletedSale_VoidsAndRestoresStock()
    {
        var world = BuildWorld();
        var stock = world.Stock;
        stock.SeedBalance(90m);
        var handler = world.CreateHandler();

        var result = await handler.Handle(new VoidSaleCommand(world.Sale.Id, "Wrong item"), CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(SaleStatus.Voided, result.Value.Status);
        Assert.Equal("Wrong item", result.Value.VoidReason);
        Assert.Equal(CashierId, result.Value.VoidedBy);
        Assert.NotNull(result.Value.VoidedAt);

        var reversal = Assert.Single(
            stock.Movements, m => m.MovementType == StockMovementType.SaleVoid);
        Assert.Equal(1m, reversal.Quantity);
        Assert.Equal(world.Sale.Id, reversal.ReferenceId);
        Assert.Equal(91m, stock.Balance!.Quantity);
        Assert.True(world.Sales.Updated);
    }

    [Fact]
    public async Task Handle_ServiceOnlySale_NoMovementsToRestore_Succeeds()
    {
        var world = BuildWorld();
        world.Stock.Movements.Clear();
        var handler = world.CreateHandler();

        var result = await handler.Handle(new VoidSaleCommand(world.Sale.Id, "No stock involved"), CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(SaleStatus.Voided, result.Value.Status);
        Assert.Empty(world.Stock.Movements);
    }

    [Fact]
    public async Task Handle_UnknownSale_ReturnsNotFound()
    {
        var world = BuildWorld();
        var handler = world.CreateHandler();

        var result = await handler.Handle(new VoidSaleCommand(Guid.NewGuid(), "Reason"), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("NotFound", result.Error.Code);
    }

    [Fact]
    public async Task Handle_AlreadyVoided_ReturnsConflict()
    {
        var world = BuildWorld(alreadyVoided: true);
        var handler = world.CreateHandler();

        var result = await handler.Handle(new VoidSaleCommand(world.Sale.Id, "Again"), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("Conflict", result.Error.Code);
        Assert.DoesNotContain(world.Stock.Movements, m => m.MovementType == StockMovementType.SaleVoid);
    }

    [Fact]
    public async Task Handle_NoSignedInUser_ReturnsUnauthorized()
    {
        var world = BuildWorld(withUser: false);
        var handler = world.CreateHandler();

        var result = await handler.Handle(new VoidSaleCommand(world.Sale.Id, "Reason"), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("Unauthorized", result.Error.Code);
    }

    private sealed class StubTenantContext : ITenantContext
    {
        public Guid TenantId { get; init; }
        public Guid? UserId { get; init; }
        public string? IpAddress => null;
    }

    private sealed class StubSaleRepository : ISaleRepository
    {
        public Sale? Sale { get; set; }
        public bool Updated { get; private set; }

        public Task AddAsync(Sale sale, CancellationToken ct = default) => Task.CompletedTask;
        public Task UpdateAsync(Sale sale, CancellationToken ct = default)
        {
            Updated = true;
            return Task.CompletedTask;
        }
        public Task<Sale?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken ct = default)
            => Task.FromResult(Sale?.Id == id ? Sale : null);
        public Task<Sale?> GetByClientSaleIdAsync(Guid tenantId, Guid clientSaleId, CancellationToken ct = default)
            => Task.FromResult<Sale?>(null);
        public Task<IReadOnlyList<Sale>> ListAsync(
            Guid tenantId, int page, int pageSize, SaleListFilter filter, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<Sale>>(Sale is null ? Array.Empty<Sale>() : new[] { Sale });
        public Task<int> CountAsync(Guid tenantId, SaleListFilter filter, CancellationToken ct = default)
            => Task.FromResult(Sale is null ? 0 : 1);
    }

    private sealed class StubStockRepository : IStockRepository
    {
        public List<StockMovement> Movements { get; } = new();
        public StockBalance? Balance { get; private set; }

        public void Add(StockMovement movement) => Movements.Add(movement);

        public void SeedBalance(decimal quantity)
        {
            Balance = StockBalance.Create(TenantId, WarehouseId, LocationId, ProductId, null);
            Balance.Apply(quantity);
        }

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
}

public sealed class VoidSaleCommandValidatorTests
{
    private readonly VoidSaleCommandValidator _validator = new();

    private static VoidSaleCommand Valid() => new(Guid.NewGuid(), "Wrong item rung up");

    [Fact]
    public void Valid_Command_Passes()
    {
        var result = _validator.TestValidate(Valid());
        Assert.True(result.IsValid);
    }

    [Fact]
    public void EmptySaleId_Fails()
    {
        var result = _validator.TestValidate(Valid() with { SaleId = Guid.Empty });
        Assert.False(result.IsValid);
    }

    [Fact]
    public void BlankReason_Fails()
    {
        var result = _validator.TestValidate(Valid() with { Reason = "   " });
        Assert.False(result.IsValid);
    }

    [Fact]
    public void TooLongReason_Fails()
    {
        var result = _validator.TestValidate(Valid() with { Reason = new string('x', 501) });
        Assert.False(result.IsValid);
    }
}
