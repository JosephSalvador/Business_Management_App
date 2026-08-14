using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record WarehouseUpdatedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid WarehouseId,
    Guid TenantId,
    string Name,
    string Code) : IDomainEvent;
