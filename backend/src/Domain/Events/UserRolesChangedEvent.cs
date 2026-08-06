using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record UserRolesChangedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid UserId,
    Guid TenantId,
    IReadOnlyCollection<Guid> RoleIds) : IDomainEvent;
