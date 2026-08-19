using BusinessOS.Domain.Inventory;

namespace BusinessOS.Tests.Unit.Inventory;

public sealed class TransferTests
{
    private static readonly Guid TenantId = new("11111111-1111-1111-1111-111111111111");
    private static readonly Guid SourceWarehouseId = new("22222222-2222-2222-2222-222222222222");
    private static readonly Guid DestWarehouseId = new("33333333-3333-3333-3333-333333333333");
    private static readonly Guid ProductId = new("44444444-4444-4444-4444-444444444444");

    [Fact]
    public void Create_ValidTransfer_SetsPendingStatus()
    {
        var transfer = Transfer.Create(
            TenantId, SourceWarehouseId, null, DestWarehouseId, null,
            [(ProductId, null, 10m, null)]);

        Assert.Equal(TransferStatus.Pending, transfer.Status);
        Assert.Single(transfer.Lines);
        Assert.Equal(ProductId, transfer.Lines.First().ProductId);
        Assert.Equal(10m, transfer.Lines.First().Quantity);
        Assert.Null(transfer.CompletedAt);
        Assert.Null(transfer.CancelledAt);
    }

    [Fact]
    public void Create_SourceEqualsDestination_Throws()
        => Assert.Throws<ArgumentException>(() => Transfer.Create(
            TenantId, SourceWarehouseId, null, SourceWarehouseId, null,
            [(ProductId, null, 10m, null)]));

    [Fact]
    public void Create_EmptyLines_Throws()
        => Assert.Throws<ArgumentException>(() => Transfer.Create(
            TenantId, SourceWarehouseId, null, DestWarehouseId, null,
            []));

    [Fact]
    public void Create_LineWithZeroQuantity_Throws()
        => Assert.Throws<ArgumentException>(() => Transfer.Create(
            TenantId, SourceWarehouseId, null, DestWarehouseId, null,
            [(ProductId, null, 0m, null)]));

    [Fact]
    public void Create_LineWithNegativeQuantity_Throws()
        => Assert.Throws<ArgumentException>(() => Transfer.Create(
            TenantId, SourceWarehouseId, null, DestWarehouseId, null,
            [(ProductId, null, -5m, null)]));

    [Fact]
    public void Create_MultipleLines_AllAdded()
    {
        var product2 = Guid.NewGuid();
        var transfer = Transfer.Create(
            TenantId, SourceWarehouseId, null, DestWarehouseId, null,
            [(ProductId, null, 10m, null), (product2, null, 20m, null)]);

        Assert.Equal(2, transfer.Lines.Count);
    }

    [Fact]
    public void Complete_FromPending_SetsCompleted()
    {
        var transfer = Transfer.Create(
            TenantId, SourceWarehouseId, null, DestWarehouseId, null,
            [(ProductId, null, 10m, null)]);
        var now = DateTime.UtcNow;

        transfer.Complete(now);

        Assert.Equal(TransferStatus.Completed, transfer.Status);
        Assert.Equal(now, transfer.CompletedAt);
    }

    [Fact]
    public void Complete_FromCancelled_Throws()
    {
        var transfer = Transfer.Create(
            TenantId, SourceWarehouseId, null, DestWarehouseId, null,
            [(ProductId, null, 10m, null)]);
        transfer.Cancel(DateTime.UtcNow);

        Assert.Throws<InvalidOperationException>(() => transfer.Complete(DateTime.UtcNow));
    }

    [Fact]
    public void Complete_FromCompleted_Throws()
    {
        var transfer = Transfer.Create(
            TenantId, SourceWarehouseId, null, DestWarehouseId, null,
            [(ProductId, null, 10m, null)]);
        transfer.Complete(DateTime.UtcNow);

        Assert.Throws<InvalidOperationException>(() => transfer.Complete(DateTime.UtcNow));
    }

    [Fact]
    public void Cancel_FromPending_SetsCancelled()
    {
        var transfer = Transfer.Create(
            TenantId, SourceWarehouseId, null, DestWarehouseId, null,
            [(ProductId, null, 10m, null)]);
        var now = DateTime.UtcNow;

        transfer.Cancel(now);

        Assert.Equal(TransferStatus.Cancelled, transfer.Status);
        Assert.Equal(now, transfer.CancelledAt);
    }

    [Fact]
    public void Cancel_FromCompleted_Throws()
    {
        var transfer = Transfer.Create(
            TenantId, SourceWarehouseId, null, DestWarehouseId, null,
            [(ProductId, null, 10m, null)]);
        transfer.Complete(DateTime.UtcNow);

        Assert.Throws<InvalidOperationException>(() => transfer.Cancel(DateTime.UtcNow));
    }
}

public sealed class StockCountTests
{
    private static readonly Guid TenantId = new("11111111-1111-1111-1111-111111111111");
    private static readonly Guid WarehouseId = new("22222222-2222-2222-2222-222222222222");
    private static readonly Guid ProductId = new("33333333-3333-3333-3333-333333333333");

    [Fact]
    public void Create_ValidCount_SetsDraftStatus()
    {
        var count = StockCount.Create(TenantId, WarehouseId, null, ProductId, null, 50m, "Physical count");

        Assert.Equal(CountStatus.Draft, count.Status);
        Assert.Equal(50m, count.CountedQuantity);
        Assert.Equal("Physical count", count.Notes);
        Assert.Equal(0m, count.SystemQuantity);
        Assert.Equal(0m, count.Difference);
    }

    [Fact]
    public void Create_NegativeCountedQuantity_Throws()
        => Assert.Throws<ArgumentException>(() => StockCount.Create(
            TenantId, WarehouseId, null, ProductId, null, -5m));

    [Fact]
    public void Complete_FromDraft_WithPositiveDifference()
    {
        var count = StockCount.Create(TenantId, WarehouseId, null, ProductId, null, 55m);
        var now = DateTime.UtcNow;

        count.Complete(systemQuantity: 50m, now);

        Assert.Equal(CountStatus.Completed, count.Status);
        Assert.Equal(50m, count.SystemQuantity);
        Assert.Equal(55m, count.CountedQuantity);
        Assert.Equal(5m, count.Difference);
        Assert.Equal(now, count.CompletedAt);
    }

    [Fact]
    public void Complete_FromDraft_WithNegativeDifference()
    {
        var count = StockCount.Create(TenantId, WarehouseId, null, ProductId, null, 45m);

        count.Complete(systemQuantity: 50m, DateTime.UtcNow);

        Assert.Equal(-5m, count.Difference);
    }

    [Fact]
    public void Complete_FromDraft_WithZeroDifference()
    {
        var count = StockCount.Create(TenantId, WarehouseId, null, ProductId, null, 50m);

        count.Complete(systemQuantity: 50m, DateTime.UtcNow);

        Assert.Equal(0m, count.Difference);
    }

    [Fact]
    public void Complete_FromCompleted_Throws()
    {
        var count = StockCount.Create(TenantId, WarehouseId, null, ProductId, null, 50m);
        count.Complete(systemQuantity: 50m, DateTime.UtcNow);

        Assert.Throws<InvalidOperationException>(() => count.Complete(systemQuantity: 50m, DateTime.UtcNow));
    }

    [Fact]
    public void Cancel_FromDraft_SetsCancelled()
    {
        var count = StockCount.Create(TenantId, WarehouseId, null, ProductId, null, 50m);
        var now = DateTime.UtcNow;

        count.Cancel(now);

        Assert.Equal(CountStatus.Cancelled, count.Status);
        Assert.Equal(now, count.CancelledAt);
    }

    [Fact]
    public void Cancel_FromCompleted_Throws()
    {
        var count = StockCount.Create(TenantId, WarehouseId, null, ProductId, null, 50m);
        count.Complete(systemQuantity: 50m, DateTime.UtcNow);

        Assert.Throws<InvalidOperationException>(() => count.Cancel(DateTime.UtcNow));
    }
}

public sealed class StockBatchTests
{
    private static readonly Guid TenantId = new("11111111-1111-1111-1111-111111111111");
    private static readonly Guid ProductId = new("22222222-2222-2222-2222-222222222222");

    [Fact]
    public void Create_ValidBatch_SetsActiveByDefault()
    {
        var batch = StockBatch.Create(
            TenantId, ProductId, null, "BATCH-001",
            expiryDate: DateTime.UtcNow.AddDays(365));

        Assert.Equal("BATCH-001", batch.BatchNumber);
        Assert.True(batch.IsActive);
        Assert.Equal(TenantId, batch.TenantId);
        Assert.Equal(ProductId, batch.ProductId);
    }

    [Fact]
    public void Create_EmptyBatchNumber_Throws()
        => Assert.Throws<ArgumentException>(() => StockBatch.Create(
            TenantId, ProductId, null, ""));

    [Fact]
    public void Create_PastExpiryDate_Throws()
        => Assert.Throws<ArgumentException>(() => StockBatch.Create(
            TenantId, ProductId, null, "BATCH-001",
            expiryDate: DateTime.UtcNow.AddDays(-1)));

    [Fact]
    public void Deactivate_SetsInactive()
    {
        var batch = StockBatch.Create(
            TenantId, ProductId, null, "BATCH-001",
            expiryDate: DateTime.UtcNow.AddDays(365));

        batch.Deactivate();

        Assert.False(batch.IsActive);
    }

    [Fact]
    public void Activate_AfterDeactivate_SetsActive()
    {
        var batch = StockBatch.Create(
            TenantId, ProductId, null, "BATCH-001",
            expiryDate: DateTime.UtcNow.AddDays(365));
        batch.Deactivate();

        batch.Activate();

        Assert.True(batch.IsActive);
    }

    [Fact]
    public void Create_BatchNumberIsTrimmed()
    {
        var batch = StockBatch.Create(
            TenantId, ProductId, null, "  BATCH-001  ",
            expiryDate: DateTime.UtcNow.AddDays(365));

        Assert.Equal("BATCH-001", batch.BatchNumber);
    }
}
