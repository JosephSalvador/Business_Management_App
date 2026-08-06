using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record RolePermissionsChangedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid RoleId,
    Guid TenantId,
    IReadOnlyCollection<string> PermissionNames) : IDomainEvent;
