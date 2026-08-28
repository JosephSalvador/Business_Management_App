using BusinessOS.Shared.Events;

namespace BusinessOS.Application.Jobs;

public sealed record SendEmailJob(
    Guid EventId,
    DateTime OccurredAt,
    Guid TenantId,
    string To,
    string Subject,
    string HtmlBody) : IDomainEvent, ITenantScopedEvent
{
    public static SendEmailJob Create(Guid tenantId, string to, string subject, string htmlBody)
        => new(Guid.NewGuid(), DateTime.UtcNow, tenantId, to, subject, htmlBody);
}

public sealed record SendSmsJob(
    Guid EventId,
    DateTime OccurredAt,
    Guid TenantId,
    string PhoneNumber,
    string Text) : IDomainEvent, ITenantScopedEvent
{
    public static SendSmsJob Create(Guid tenantId, string phoneNumber, string text)
        => new(Guid.NewGuid(), DateTime.UtcNow, tenantId, phoneNumber, text);
}

public sealed record SendPushJob(
    Guid EventId,
    DateTime OccurredAt,
    Guid TenantId,
    string DeviceToken,
    string Title,
    string Body) : IDomainEvent, ITenantScopedEvent
{
    public static SendPushJob Create(Guid tenantId, string deviceToken, string title, string body)
        => new(Guid.NewGuid(), DateTime.UtcNow, tenantId, deviceToken, title, body);
}

public sealed record SendWhatsAppJob(
    Guid EventId,
    DateTime OccurredAt,
    Guid TenantId,
    string PhoneNumber,
    string Text) : IDomainEvent, ITenantScopedEvent
{
    public static SendWhatsAppJob Create(Guid tenantId, string phoneNumber, string text)
        => new(Guid.NewGuid(), DateTime.UtcNow, tenantId, phoneNumber, text);
}
