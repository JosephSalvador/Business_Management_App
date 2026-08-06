using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record UserBranchesChangedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid UserId,
    Guid TenantId,
    IReadOnlyCollection<Guid> BranchIds,
    Guid? DefaultBranchId) : IDomainEvent;
