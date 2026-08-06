using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record UserStatusChangedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid UserId,
    Guid TenantId,
    bool IsActive) : IDomainEvent;
