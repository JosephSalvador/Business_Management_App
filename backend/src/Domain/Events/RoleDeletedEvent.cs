using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record RoleDeletedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid RoleId,
    Guid TenantId,
    string Name) : IDomainEvent;
