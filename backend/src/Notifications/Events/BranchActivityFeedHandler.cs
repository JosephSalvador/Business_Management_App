using BusinessOS.Application.Ports;
using BusinessOS.Domain.Events;
using Microsoft.Extensions.Logging;

namespace BusinessOS.Notifications.Events;

/// <summary>
/// Fans branch domain events out to the activity feed.
/// </summary>
public sealed class BranchActivityFeedHandler
    : IDomainEventHandler<BranchCreatedEvent>,
      IDomainEventHandler<BranchUpdatedEvent>,
      IDomainEventHandler<BranchStatusChangedEvent>
{
    private readonly ILogger<BranchActivityFeedHandler> _logger;

    public BranchActivityFeedHandler(ILogger<BranchActivityFeedHandler> logger) => _logger = logger;

    public Task HandleAsync(BranchCreatedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Activity feed: Branch {Code} ({Name}) created for tenant {TenantId}",
            domainEvent.Code, domainEvent.Name, domainEvent.TenantId);
        return Task.CompletedTask;
    }

    public Task HandleAsync(BranchUpdatedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Activity feed: Branch {Code} ({Name}) profile updated for tenant {TenantId}",
            domainEvent.Code, domainEvent.Name, domainEvent.TenantId);
        return Task.CompletedTask;
    }

    public Task HandleAsync(BranchStatusChangedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Activity feed: Branch {Code} ({Name}) {State} for tenant {TenantId}",
            domainEvent.Code, domainEvent.Name, domainEvent.IsActive ? "activated" : "deactivated", domainEvent.TenantId);
        return Task.CompletedTask;
    }
}
