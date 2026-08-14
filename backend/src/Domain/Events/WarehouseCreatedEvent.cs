using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record WarehouseCreatedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid WarehouseId,
    Guid TenantId,
    Guid BranchId,
    string Name,
    string Code) : IDomainEvent;
