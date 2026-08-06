using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record BranchStatusChangedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid BranchId,
    Guid TenantId,
    string Name,
    string Code,
    bool IsActive) : IDomainEvent;
