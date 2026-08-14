using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Inventory;

/// <summary>
/// Current (derived) stock quantity for one sellable unit at one location. Derived state —
/// the <see cref="StockMovement"/> ledger is the historical source of explanation, so a
/// balance can always be recomputed from movements and corrections are compensating
/// movements rather than edits.
/// </summary>
public sealed class StockBalance : Entity
{
    private StockBalance(
        Guid id,
        Guid tenantId,
        Guid warehouseId,
        Guid stockLocationId,
        Guid productId,
        Guid? variantId)
        : base(id)
    {
        TenantId = tenantId;
        WarehouseId = warehouseId;
        StockLocationId = stockLocationId;
        ProductId = productId;
        VariantId = variantId;
    }

    public Guid TenantId { get; private set; }
    public Guid WarehouseId { get; private set; }
    public Guid StockLocationId { get; private set; }
    public Guid ProductId { get; private set; }
    public Guid? VariantId { get; private set; }
    public decimal Quantity { get; private set; }

    public static StockBalance Create(
        Guid tenantId, Guid warehouseId, Guid stockLocationId, Guid productId, Guid? variantId)
        => new(Guid.NewGuid(), tenantId, warehouseId, stockLocationId, productId, variantId);

    public void Apply(decimal quantityDelta)
    {
        var updated = Quantity + quantityDelta;
        if (updated < 0)
        {
            throw new InvalidOperationException("Stock balance cannot be negative.");
        }

        Quantity = updated;
    }
}
