using BusinessOS.Application.Jobs;
using BusinessOS.Application.Notifications;
using BusinessOS.Application.Ports;
using Microsoft.Extensions.Logging;

namespace BusinessOS.Workers.Jobs;

public sealed class JobExecutionService : IDomainEventHandler<SendEmailJob>, IDomainEventHandler<SendSmsJob>, IDomainEventHandler<SendPushJob>, IDomainEventHandler<SendWhatsAppJob>
{
    private readonly INotificationService _notifications;
    private readonly ILogger<JobExecutionService> _logger;

    public JobExecutionService(INotificationService notifications, ILogger<JobExecutionService> logger)
    {
        _notifications = notifications;
        _logger = logger;
    }

    public async Task HandleAsync(SendEmailJob domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Executing SendEmailJob {JobId} for tenant {TenantId}", domainEvent.EventId, domainEvent.TenantId);
        await _notifications.SendEmailAsync(
            new EmailMessage(domainEvent.To, domainEvent.Subject, domainEvent.HtmlBody), cancellationToken);
    }

    public async Task HandleAsync(SendSmsJob domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Executing SendSmsJob {JobId} for tenant {TenantId}", domainEvent.EventId, domainEvent.TenantId);
        await _notifications.SendSmsAsync(
            new SmsMessage(domainEvent.PhoneNumber, domainEvent.Text), cancellationToken);
    }

    public async Task HandleAsync(SendPushJob domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Executing SendPushJob {JobId} for tenant {TenantId}", domainEvent.EventId, domainEvent.TenantId);
        await _notifications.SendPushAsync(
            new PushMessage(domainEvent.DeviceToken, domainEvent.Title, domainEvent.Body), cancellationToken);
    }

    public async Task HandleAsync(SendWhatsAppJob domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Executing SendWhatsAppJob {JobId} for tenant {TenantId}", domainEvent.EventId, domainEvent.TenantId);
        await _notifications.SendWhatsAppAsync(
            new WhatsAppMessage(domainEvent.PhoneNumber, domainEvent.Text), cancellationToken);
    }
}
