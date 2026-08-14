using BusinessOS.Domain.Events;
using BusinessOS.Domain.Inventory;

namespace BusinessOS.Tests.Unit.Inventory;

public sealed class StockLedgerTests
{
    private static StockMovement RecordOpening(decimal quantity, DateTime? occurredAt = null)
        => StockMovement.Record(
            tenantId: Guid.NewGuid(),
            branchId: Guid.NewGuid(),
            warehouseId: Guid.NewGuid(),
            stockLocationId: Guid.NewGuid(),
            productId: Guid.NewGuid(),
            variantId: null,
            StockMovementType.OpeningStock,
            quantity,
            unitOfMeasureId: Guid.NewGuid(),
            occurredAt ?? new DateTime(2026, 8, 1, 10, 0, 0, DateTimeKind.Utc));

    [Fact]
    public void RecordOpening_CreatesPositiveMovementWithBothEvents()
    {
        var occurredAt = new DateTime(2026, 8, 1, 10, 0, 0, DateTimeKind.Utc);
        var movement = RecordOpening(50m, occurredAt);

        Assert.Equal(StockMovementType.OpeningStock, movement.MovementType);
        Assert.Equal(50m, movement.Quantity);
        Assert.Equal(occurredAt, movement.OccurredAt);
        Assert.Equal(occurredAt, movement.CreatedAt);

        Assert.Single(movement.DomainEvents.OfType<StockMovementRecordedEvent>());
        var opening = Assert.Single(movement.DomainEvents.OfType<OpeningStockRecordedEvent>());
        Assert.Equal(movement.Id, opening.MovementId);
        Assert.Equal(50m, opening.Quantity);
    }

    [Fact]
    public void RecordOpening_ZeroQuantity_Throws()
        => Assert.Throws<ArgumentException>(() => RecordOpening(0m));

    [Fact]
    public void RecordOpening_NegativeQuantity_Throws()
        => Assert.Throws<ArgumentException>(() => RecordOpening(-10m));

    [Fact]
    public void Balance_CreateStartsAtZero()
    {
        var balance = StockBalance.Create(
            Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), variantId: null);

        Assert.Equal(0m, balance.Quantity);
    }

    [Fact]
    public void Balance_Apply_AccumulatesQuantity()
    {
        var balance = StockBalance.Create(
            Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), variantId: null);

        balance.Apply(10m);
        balance.Apply(5m);

        Assert.Equal(15m, balance.Quantity);
    }

    [Fact]
    public void Balance_Apply_NegativeBeyondZero_Throws()
    {
        var balance = StockBalance.Create(
            Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), variantId: null);
        balance.Apply(10m);

        Assert.Throws<InvalidOperationException>(() => balance.Apply(-11m));
        Assert.Equal(10m, balance.Quantity);
    }
}
