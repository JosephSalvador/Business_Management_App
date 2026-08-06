using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record UserCreatedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid UserId,
    Guid TenantId,
    string Email,
    string FullName) : IDomainEvent;
