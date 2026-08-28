using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record UserEmailVerifiedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid UserId,
    Guid TenantId,
    string Email) : IDomainEvent;
