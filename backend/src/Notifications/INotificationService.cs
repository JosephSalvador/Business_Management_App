namespace BusinessOS.Notifications;

public sealed record EmailMessage(string To, string Subject, string Body, string? From = null);

public sealed record SmsMessage(string To, string Body);

public interface INotificationService
{
    Task SendEmailAsync(EmailMessage message, CancellationToken cancellationToken = default);
    Task SendSmsAsync(SmsMessage message, CancellationToken cancellationToken = default);
}
