using BusinessOS.Domain.Inventory;
using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record StockMovementRecordedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid MovementId,
    Guid TenantId,
    Guid WarehouseId,
    Guid StockLocationId,
    Guid ProductId,
    Guid? VariantId,
    StockMovementType MovementType,
    decimal Quantity,
    DateTime EffectiveAt) : IDomainEvent;
