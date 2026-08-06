using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record RoleUpdatedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid RoleId,
    Guid TenantId,
    string Name) : IDomainEvent;
