using BusinessOS.Notifications.Channels;
using Microsoft.Extensions.Logging;
using EmailMessage = BusinessOS.Application.Notifications.EmailMessage;
using INotificationService = BusinessOS.Application.Ports.INotificationService;
using PushMessage = BusinessOS.Application.Notifications.PushMessage;
using SmsMessage = BusinessOS.Application.Notifications.SmsMessage;
using WhatsAppMessage = BusinessOS.Application.Notifications.WhatsAppMessage;

namespace BusinessOS.Notifications;

public sealed class NotificationService : INotificationService
{
    private readonly EmailChannel _email;
    private readonly LoggingSmsChannel _sms;
    private readonly LoggingPushChannel _push;
    private readonly LoggingWhatsAppChannel _whatsapp;
    private readonly ILogger<NotificationService> _logger;

    public NotificationService(
        EmailChannel email,
        LoggingSmsChannel sms,
        LoggingPushChannel push,
        LoggingWhatsAppChannel whatsapp,
        ILogger<NotificationService> logger)
    {
        _email = email;
        _sms = sms;
        _push = push;
        _whatsapp = whatsapp;
        _logger = logger;
    }

    public Task SendEmailAsync(EmailMessage message, CancellationToken cancellationToken = default)
        => _email.SendEmailAsync(message, cancellationToken);

    public Task SendSmsAsync(SmsMessage message, CancellationToken cancellationToken = default)
        => _sms.SendSmsAsync(message, cancellationToken);

    public Task SendPushAsync(PushMessage message, CancellationToken cancellationToken = default)
        => _push.SendPushAsync(message, cancellationToken);

    public Task SendWhatsAppAsync(WhatsAppMessage message, CancellationToken cancellationToken = default)
        => _whatsapp.SendWhatsAppAsync(message, cancellationToken);
}
