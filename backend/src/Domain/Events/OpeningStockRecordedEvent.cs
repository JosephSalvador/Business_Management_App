using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record OpeningStockRecordedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid MovementId,
    Guid TenantId,
    Guid WarehouseId,
    Guid StockLocationId,
    Guid ProductId,
    Guid? VariantId,
    decimal Quantity,
    DateTime EffectiveAt) : IDomainEvent;
