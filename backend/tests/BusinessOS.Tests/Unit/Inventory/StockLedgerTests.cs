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
    public void RecordAdjustment_PositiveQuantity_CreatesMovement()
    {
        var movement = StockMovement.Record(
            tenantId: Guid.NewGuid(),
            branchId: Guid.NewGuid(),
            warehouseId: Guid.NewGuid(),
            stockLocationId: Guid.NewGuid(),
            productId: Guid.NewGuid(),
            variantId: null,
            StockMovementType.Adjustment,
            10m,
            unitOfMeasureId: Guid.NewGuid(),
            occurredAt: DateTime.UtcNow,
            reason: "Found extra stock");

        Assert.Equal(StockMovementType.Adjustment, movement.MovementType);
        Assert.Equal(10m, movement.Quantity);
        Assert.Equal("Found extra stock", movement.Reason);
        Assert.Single(movement.DomainEvents.OfType<StockMovementRecordedEvent>());
        var adjusted = Assert.Single(movement.DomainEvents.OfType<StockAdjustedEvent>());
        Assert.Equal(movement.Id, adjusted.StockMovementId);
        Assert.Equal(10m, adjusted.QuantityDelta);
        Assert.Equal("Found extra stock", adjusted.Reason);
    }

    [Fact]
    public void RecordAdjustment_NegativeQuantity_CreatesMovement()
    {
        var movement = StockMovement.Record(
            tenantId: Guid.NewGuid(),
            branchId: Guid.NewGuid(),
            warehouseId: Guid.NewGuid(),
            stockLocationId: Guid.NewGuid(),
            productId: Guid.NewGuid(),
            variantId: null,
            StockMovementType.Adjustment,
            -5m,
            unitOfMeasureId: Guid.NewGuid(),
            occurredAt: DateTime.UtcNow,
            reason: "Damaged goods");

        Assert.Equal(StockMovementType.Adjustment, movement.MovementType);
        Assert.Equal(-5m, movement.Quantity);
    }

    [Fact]
    public void RecordAdjustment_ZeroQuantity_Throws()
        => Assert.Throws<ArgumentException>(() => StockMovement.Record(
            Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(),
            Guid.NewGuid(), null, StockMovementType.Adjustment, 0m,
            Guid.NewGuid(), DateTime.UtcNow));

    [Fact]
    public void RecordTransferIn_PositiveQuantity_CreatesMovement()
    {
        var movement = StockMovement.Record(
            tenantId: Guid.NewGuid(),
            branchId: Guid.NewGuid(),
            warehouseId: Guid.NewGuid(),
            stockLocationId: Guid.NewGuid(),
            productId: Guid.NewGuid(),
            variantId: null,
            StockMovementType.TransferIn,
            20m,
            unitOfMeasureId: Guid.NewGuid(),
            occurredAt: DateTime.UtcNow);

        Assert.Equal(StockMovementType.TransferIn, movement.MovementType);
        Assert.Equal(20m, movement.Quantity);
    }

    [Fact]
    public void RecordTransferIn_NegativeQuantity_Throws()
        => Assert.Throws<ArgumentException>(() => StockMovement.Record(
            Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(),
            Guid.NewGuid(), null, StockMovementType.TransferIn, -10m,
            Guid.NewGuid(), DateTime.UtcNow));

    [Fact]
    public void RecordTransferOut_NegativeQuantity_CreatesMovement()
    {
        var movement = StockMovement.Record(
            tenantId: Guid.NewGuid(),
            branchId: Guid.NewGuid(),
            warehouseId: Guid.NewGuid(),
            stockLocationId: Guid.NewGuid(),
            productId: Guid.NewGuid(),
            variantId: null,
            StockMovementType.TransferOut,
            -15m,
            unitOfMeasureId: Guid.NewGuid(),
            occurredAt: DateTime.UtcNow);

        Assert.Equal(StockMovementType.TransferOut, movement.MovementType);
        Assert.Equal(-15m, movement.Quantity);
    }

    [Fact]
    public void RecordTransferOut_PositiveQuantity_Throws()
        => Assert.Throws<ArgumentException>(() => StockMovement.Record(
            Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(),
            Guid.NewGuid(), null, StockMovementType.TransferOut, 10m,
            Guid.NewGuid(), DateTime.UtcNow));

    [Fact]
    public void RecordCount_PositiveDifference_CreatesMovement()
    {
        var movement = StockMovement.Record(
            tenantId: Guid.NewGuid(),
            branchId: Guid.NewGuid(),
            warehouseId: Guid.NewGuid(),
            stockLocationId: Guid.NewGuid(),
            productId: Guid.NewGuid(),
            variantId: null,
            StockMovementType.Count,
            3m,
            unitOfMeasureId: Guid.NewGuid(),
            occurredAt: DateTime.UtcNow,
            reason: "Cycle count found 3 extra");

        Assert.Equal(StockMovementType.Count, movement.MovementType);
        Assert.Equal(3m, movement.Quantity);
    }

    [Fact]
    public void RecordCount_NegativeDifference_CreatesMovement()
    {
        var movement = StockMovement.Record(
            tenantId: Guid.NewGuid(),
            branchId: Guid.NewGuid(),
            warehouseId: Guid.NewGuid(),
            stockLocationId: Guid.NewGuid(),
            productId: Guid.NewGuid(),
            variantId: null,
            StockMovementType.Count,
            -2m,
            unitOfMeasureId: Guid.NewGuid(),
            occurredAt: DateTime.UtcNow,
            reason: "Cycle count found 2 missing");

        Assert.Equal(StockMovementType.Count, movement.MovementType);
        Assert.Equal(-2m, movement.Quantity);
    }

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
