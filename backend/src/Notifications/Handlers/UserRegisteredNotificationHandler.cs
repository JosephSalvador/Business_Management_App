using BusinessOS.Application.Ports;
using BusinessOS.Domain.Events;
using Microsoft.Extensions.Logging;
using EmailMessage = BusinessOS.Application.Notifications.EmailMessage;

namespace BusinessOS.Notifications;

/// <summary>
/// Subscribes to platform domain events and turns them into notifications.
/// Proves the event → notification loop (outbox → in-process publish → handler).
/// </summary>
public sealed class UserRegisteredNotificationHandler : IDomainEventHandler<UserRegisteredEvent>
{
    private readonly INotificationService _notifications;
    private readonly ILogger<UserRegisteredNotificationHandler> _logger;

    public UserRegisteredNotificationHandler(
        INotificationService notifications,
        ILogger<UserRegisteredNotificationHandler> logger)
    {
        _notifications = notifications;
        _logger = logger;
    }

    public Task HandleAsync(UserRegisteredEvent domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Handling UserRegisteredEvent for {Email}", domainEvent.Email);

        return _notifications.SendEmailAsync(
            new EmailMessage(
                domainEvent.Email,
                "Welcome to Business OS",
                $"Karibu {domainEvent.FullName}! Your organization is ready. Sign in to get started."),
            cancellationToken);
    }
}
