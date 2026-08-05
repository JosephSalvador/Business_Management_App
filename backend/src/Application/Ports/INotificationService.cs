using BusinessOS.Application.Notifications;

namespace BusinessOS.Application.Ports;

public interface INotificationService
{
    Task SendEmailAsync(EmailMessage message, CancellationToken cancellationToken = default);
    Task SendSmsAsync(SmsMessage message, CancellationToken cancellationToken = default);
    Task SendPushAsync(PushMessage message, CancellationToken cancellationToken = default);
    Task SendWhatsAppAsync(WhatsAppMessage message, CancellationToken cancellationToken = default);
}
