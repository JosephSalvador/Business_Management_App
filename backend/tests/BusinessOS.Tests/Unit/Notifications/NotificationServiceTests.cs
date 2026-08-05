using BusinessOS.Notifications;
using BusinessOS.Notifications.Channels;
using BusinessOS.Shared.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using EmailMessage = BusinessOS.Application.Notifications.EmailMessage;
using PushMessage = BusinessOS.Application.Notifications.PushMessage;
using SmsMessage = BusinessOS.Application.Notifications.SmsMessage;
using WhatsAppMessage = BusinessOS.Application.Notifications.WhatsAppMessage;

namespace BusinessOS.Tests.Unit.Notifications;

public sealed class NotificationServiceTests
{
    private static EmailChannel CreateEmailChannel()
        => new(Options.Create(new SmtpOptions()), NullLogger<EmailChannel>.Instance);

    private static NotificationService CreateService()
        => new(
            CreateEmailChannel(),
            new LoggingSmsChannel(NullLogger<LoggingSmsChannel>.Instance),
            new LoggingPushChannel(NullLogger<LoggingPushChannel>.Instance),
            new LoggingWhatsAppChannel(NullLogger<LoggingWhatsAppChannel>.Instance),
            NullLogger<NotificationService>.Instance);

    [Fact]
    public async Task SendEmailAsync_RoutesToEmailChannel_NoOpsWhenSmtpNotConfigured()
    {
        LoggingSmsChannel.SentLog.Clear();
        LoggingPushChannel.SentLog.Clear();
        LoggingWhatsAppChannel.SentLog.Clear();
        var service = CreateService();

        await service.SendEmailAsync(new EmailMessage("recipient@example.com", "Subject", "<p>Hello</p>"));

        Assert.Empty(LoggingSmsChannel.SentLog);
        Assert.Empty(LoggingPushChannel.SentLog);
        Assert.Empty(LoggingWhatsAppChannel.SentLog);
    }

    [Fact]
    public async Task SendSmsAsync_RoutesToSmsChannel_AndLogsPhoneAndText()
    {
        LoggingSmsChannel.SentLog.Clear();
        var service = CreateService();

        await service.SendSmsAsync(new SmsMessage("+255700000000", "Your code is 1234"));

        var entry = Assert.Single(LoggingSmsChannel.SentLog);
        Assert.Contains("+255700000000", entry);
        Assert.Contains("Your code is 1234", entry);
    }

    [Fact]
    public async Task SendPushAsync_RoutesToPushChannel_AndLogsTokenAndTitle()
    {
        LoggingPushChannel.SentLog.Clear();
        var service = CreateService();

        await service.SendPushAsync(new PushMessage("device-123", "Invoice ready", "Your invoice #9 is ready"));

        var entry = Assert.Single(LoggingPushChannel.SentLog);
        Assert.Contains("device-123", entry);
        Assert.Contains("Invoice ready", entry);
        Assert.Contains("Your invoice #9 is ready", entry);
    }

    [Fact]
    public async Task SendWhatsAppAsync_RoutesToWhatsAppChannel_AndLogsPhoneAndText()
    {
        LoggingWhatsAppChannel.SentLog.Clear();
        var service = CreateService();

        await service.SendWhatsAppAsync(new WhatsAppMessage("+255711111111", "Karibu Business OS"));

        var entry = Assert.Single(LoggingWhatsAppChannel.SentLog);
        Assert.Contains("+255711111111", entry);
        Assert.Contains("Karibu Business OS", entry);
    }
}
