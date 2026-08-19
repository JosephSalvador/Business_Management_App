using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record StockCountCompletedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid CountId,
    Guid TenantId,
    Guid WarehouseId,
    Guid? StockLocationId,
    Guid ProductId,
    Guid? VariantId,
    decimal SystemQuantity,
    decimal CountedQuantity,
    decimal Difference,
    Guid? CreatedBy) : IDomainEvent;
