using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record StockAdjustedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid StockMovementId,
    Guid TenantId,
    Guid WarehouseId,
    Guid StockLocationId,
    Guid ProductId,
    Guid? VariantId,
    decimal QuantityDelta,
    string Reason,
    Guid? CreatedBy) : IDomainEvent;
