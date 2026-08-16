using BusinessOS.Domain.Events;
using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Inventory;

/// <summary>
/// Immutable stock ledger row. Never mutated or deleted after posting — corrections are
/// compensating movements. The ledger is the historical source of explanation for the
/// current (derived) <see cref="StockBalance"/> quantities.
/// </summary>
public sealed class StockMovement : AggregateRoot
{
    private StockMovement(
        Guid id,
        Guid tenantId,
        Guid branchId,
        Guid warehouseId,
        Guid stockLocationId,
        Guid productId,
        Guid? variantId,
        StockMovementType movementType,
        decimal quantity,
        Guid unitOfMeasureId,
        DateTime occurredAt,
        string? referenceType,
        Guid? referenceId,
        string? reason,
        string? correlationId,
        Guid? createdBy)
        : base(id)
    {
        TenantId = tenantId;
        BranchId = branchId;
        WarehouseId = warehouseId;
        StockLocationId = stockLocationId;
        ProductId = productId;
        VariantId = variantId;
        MovementType = movementType;
        Quantity = quantity;
        UnitOfMeasureId = unitOfMeasureId;
        OccurredAt = occurredAt;
        ReferenceType = referenceType;
        ReferenceId = referenceId;
        Reason = reason;
        CorrelationId = correlationId;
        CreatedBy = createdBy;
        CreatedAt = occurredAt;
    }

    public Guid TenantId { get; private set; }
    public Guid BranchId { get; private set; }
    public Guid WarehouseId { get; private set; }
    public Guid StockLocationId { get; private set; }
    public Guid ProductId { get; private set; }
    public Guid? VariantId { get; private set; }
    public StockMovementType MovementType { get; private set; }
    public decimal Quantity { get; private set; }
    public Guid UnitOfMeasureId { get; private set; }
    public DateTime OccurredAt { get; private set; }
    public string? ReferenceType { get; private set; }
    public Guid? ReferenceId { get; private set; }
    public string? Reason { get; private set; }
    public string? CorrelationId { get; private set; }

    public static StockMovement Record(
        Guid tenantId,
        Guid branchId,
        Guid warehouseId,
        Guid stockLocationId,
        Guid productId,
        Guid? variantId,
        StockMovementType movementType,
        decimal quantity,
        Guid unitOfMeasureId,
        DateTime occurredAt,
        string? referenceType = null,
        Guid? referenceId = null,
        string? reason = null,
        string? correlationId = null,
        Guid? createdBy = null)
    {
        if (quantity == 0)
        {
            throw new ArgumentException("Movement quantity must be non-zero.", nameof(quantity));
        }

        if (movementType == StockMovementType.OpeningStock && quantity < 0)
        {
            throw new ArgumentException("Opening stock quantity must be positive.", nameof(quantity));
        }

        if (movementType == StockMovementType.Sale && quantity >= 0)
        {
            throw new ArgumentException("Sale stock quantity must be negative.", nameof(quantity));
        }

        var movement = new StockMovement(
            Guid.NewGuid(),
            tenantId,
            branchId,
            warehouseId,
            stockLocationId,
            productId,
            variantId,
            movementType,
            quantity,
            unitOfMeasureId,
            occurredAt,
            referenceType,
            referenceId,
            reason,
            correlationId,
            createdBy);

        movement.AddDomainEvent(new StockMovementRecordedEvent(
            Guid.NewGuid(), DateTime.UtcNow, movement.Id, tenantId, warehouseId, stockLocationId,
            productId, variantId, movementType, quantity, occurredAt));

        if (movementType == StockMovementType.OpeningStock)
        {
            movement.AddDomainEvent(new OpeningStockRecordedEvent(
                Guid.NewGuid(), DateTime.UtcNow, movement.Id, tenantId, warehouseId, stockLocationId,
                productId, variantId, quantity, occurredAt));
        }

        return movement;
    }
}
