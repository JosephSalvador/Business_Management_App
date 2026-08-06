using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record UserProfileUpdatedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid UserId,
    Guid TenantId,
    string FullName,
    string? Phone) : IDomainEvent;
