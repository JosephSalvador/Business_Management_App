using BusinessOS.Application.Ports;
using BusinessOS.Domain.Events;
using Microsoft.Extensions.Logging;

namespace BusinessOS.Notifications.Events;

/// <summary>
/// Fans UserRegisteredEvent out to the activity feed.
/// </summary>
public sealed class UserRegisteredActivityFeedHandler : IDomainEventHandler<UserRegisteredEvent>
{
    private readonly ILogger<UserRegisteredActivityFeedHandler> _logger;

    public UserRegisteredActivityFeedHandler(ILogger<UserRegisteredActivityFeedHandler> logger) => _logger = logger;

    public Task HandleAsync(UserRegisteredEvent domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Activity feed: New user {FullName} joined", domainEvent.FullName);
        return Task.CompletedTask;
    }
}
