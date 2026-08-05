using BusinessOS.Application.Ports;
using BusinessOS.Domain.Events;
using Microsoft.Extensions.Logging;

namespace BusinessOS.Notifications.Events;

/// <summary>
/// Fans UserRegisteredEvent out to the analytics feed.
/// </summary>
public sealed class UserRegisteredAnalyticsHandler : IDomainEventHandler<UserRegisteredEvent>
{
    private readonly ILogger<UserRegisteredAnalyticsHandler> _logger;

    public UserRegisteredAnalyticsHandler(ILogger<UserRegisteredAnalyticsHandler> logger) => _logger = logger;

    public Task HandleAsync(UserRegisteredEvent domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Analytics: tenant {TenantId} user {UserId} registered",
            domainEvent.TenantId, domainEvent.UserId);
        return Task.CompletedTask;
    }
}
