using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record WarehouseStatusChangedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid WarehouseId,
    Guid TenantId,
    string Name,
    string Code,
    bool IsActive) : IDomainEvent;
