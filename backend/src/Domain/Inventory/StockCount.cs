using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Inventory;

/// <summary>
/// A physical stock count (cycle count) for a specific product/variant at a specific location.
/// The count records the physically observed quantity and, on completion, reconciles with the
/// system quantity by generating an adjustment movement if they differ.
/// </summary>
public sealed class StockCount : Entity
{
    private StockCount(
        Guid id,
        Guid tenantId,
        Guid warehouseId,
        Guid? stockLocationId,
        Guid productId,
        Guid? variantId,
        decimal countedQuantity,
        string? notes)
        : base(id)
    {
        TenantId = tenantId;
        WarehouseId = warehouseId;
        StockLocationId = stockLocationId;
        ProductId = productId;
        VariantId = variantId;
        CountedQuantity = countedQuantity;
        Notes = notes;
        Status = CountStatus.Draft;
        CreatedAt = DateTime.UtcNow;
    }

    public Guid TenantId { get; private set; }
    public Guid WarehouseId { get; private set; }
    public Guid? StockLocationId { get; private set; }
    public Guid ProductId { get; private set; }
    public Guid? VariantId { get; private set; }
    public decimal CountedQuantity { get; private set; }
    public decimal SystemQuantity { get; private set; }
    public decimal Difference { get; private set; }
    public string? Notes { get; private set; }
    public CountStatus Status { get; private set; }
    public DateTime? CompletedAt { get; private set; }
    public DateTime? CancelledAt { get; private set; }

    public static StockCount Create(
        Guid tenantId,
        Guid warehouseId,
        Guid? stockLocationId,
        Guid productId,
        Guid? variantId,
        decimal countedQuantity,
        string? notes = null)
    {
        if (countedQuantity < 0)
        {
            throw new ArgumentException("Counted quantity cannot be negative.", nameof(countedQuantity));
        }

        return new StockCount(
            Guid.NewGuid(), tenantId, warehouseId, stockLocationId,
            productId, variantId, countedQuantity, notes);
    }

    public void Complete(decimal systemQuantity, DateTime completedAt)
    {
        if (Status != CountStatus.Draft)
        {
            throw new InvalidOperationException($"Cannot complete a count in {Status} status.");
        }

        SystemQuantity = systemQuantity;
        Difference = CountedQuantity - systemQuantity;
        Status = CountStatus.Completed;
        CompletedAt = completedAt;
    }

    public void Cancel(DateTime cancelledAt)
    {
        if (Status != CountStatus.Draft)
        {
            throw new InvalidOperationException($"Cannot cancel a count in {Status} status.");
        }

        Status = CountStatus.Cancelled;
        CancelledAt = cancelledAt;
    }
}
