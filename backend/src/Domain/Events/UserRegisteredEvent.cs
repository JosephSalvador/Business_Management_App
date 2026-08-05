using BusinessOS.Shared.Entities;
using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record UserRegisteredEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid UserId,
    Guid TenantId,
    string Email,
    string FullName) : IDomainEvent;
