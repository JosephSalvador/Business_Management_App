using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record BranchUpdatedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid BranchId,
    Guid TenantId,
    string Name,
    string Code) : IDomainEvent;
