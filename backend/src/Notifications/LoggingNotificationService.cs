using Microsoft.Extensions.Logging;

namespace BusinessOS.Notifications;

/// <summary>
/// Dev-only implementation: logs messages instead of sending them.
/// Real providers (email/SMS/WhatsApp/FCM) plug in behind this interface later.
/// </summary>
public sealed class LoggingNotificationService : INotificationService
{
    private readonly ILogger<LoggingNotificationService> _logger;

    public LoggingNotificationService(ILogger<LoggingNotificationService> logger)
        => _logger = logger;

    public Task SendEmailAsync(EmailMessage message, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "EMAIL to {To}: {Subject} | {Body}",
            message.To, message.Subject, message.Body);
        return Task.CompletedTask;
    }

    public Task SendSmsAsync(SmsMessage message, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("SMS to {To}: {Body}", message.To, message.Body);
        return Task.CompletedTask;
    }
}
