using BusinessOS.Application.Ports;
using BusinessOS.Domain.Events;
using Microsoft.Extensions.Logging;

namespace BusinessOS.Notifications.Events;

/// <summary>
/// Fans identity domain events (users, roles, permissions) out to the activity feed.
/// </summary>
public sealed class IdentityActivityFeedHandler
    : IDomainEventHandler<UserCreatedEvent>,
      IDomainEventHandler<UserProfileUpdatedEvent>,
      IDomainEventHandler<UserRolesChangedEvent>,
      IDomainEventHandler<UserStatusChangedEvent>,
      IDomainEventHandler<UserBranchesChangedEvent>,
      IDomainEventHandler<RoleCreatedEvent>,
      IDomainEventHandler<RoleUpdatedEvent>,
      IDomainEventHandler<RolePermissionsChangedEvent>,
      IDomainEventHandler<RoleDeletedEvent>
{
    private readonly ILogger<IdentityActivityFeedHandler> _logger;

    public IdentityActivityFeedHandler(ILogger<IdentityActivityFeedHandler> logger) => _logger = logger;

    public Task HandleAsync(UserCreatedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Activity feed: User {FullName} ({Email}) created for tenant {TenantId}",
            domainEvent.FullName, domainEvent.Email, domainEvent.TenantId);
        return Task.CompletedTask;
    }

    public Task HandleAsync(UserProfileUpdatedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Activity feed: User {UserId} profile updated for tenant {TenantId}",
            domainEvent.UserId, domainEvent.TenantId);
        return Task.CompletedTask;
    }

    public Task HandleAsync(UserRolesChangedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Activity feed: Roles {RoleIds} assigned to user {UserId} for tenant {TenantId}",
            string.Join(",", domainEvent.RoleIds), domainEvent.UserId, domainEvent.TenantId);
        return Task.CompletedTask;
    }

    public Task HandleAsync(UserStatusChangedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Activity feed: User {UserId} {State} for tenant {TenantId}",
            domainEvent.UserId, domainEvent.IsActive ? "activated" : "deactivated", domainEvent.TenantId);
        return Task.CompletedTask;
    }

    public Task HandleAsync(UserBranchesChangedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Activity feed: Branches {BranchIds} assigned to user {UserId} for tenant {TenantId}",
            string.Join(",", domainEvent.BranchIds), domainEvent.UserId, domainEvent.TenantId);
        return Task.CompletedTask;
    }

    public Task HandleAsync(RoleCreatedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Activity feed: Role {Name} created for tenant {TenantId}",
            domainEvent.Name, domainEvent.TenantId);
        return Task.CompletedTask;
    }

    public Task HandleAsync(RoleUpdatedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Activity feed: Role {Name} updated for tenant {TenantId}",
            domainEvent.Name, domainEvent.TenantId);
        return Task.CompletedTask;
    }

    public Task HandleAsync(RolePermissionsChangedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Activity feed: Permissions {Permissions} set on role {RoleId} for tenant {TenantId}",
            string.Join(",", domainEvent.PermissionNames), domainEvent.RoleId, domainEvent.TenantId);
        return Task.CompletedTask;
    }

    public Task HandleAsync(RoleDeletedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Activity feed: Role {Name} deleted for tenant {TenantId}",
            domainEvent.Name, domainEvent.TenantId);
        return Task.CompletedTask;
    }
}
