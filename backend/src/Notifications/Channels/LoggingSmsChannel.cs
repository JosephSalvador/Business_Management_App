using System.Collections.Concurrent;
using Microsoft.Extensions.Logging;
using SmsMessage = BusinessOS.Application.Notifications.SmsMessage;

namespace BusinessOS.Notifications.Channels;

public sealed class LoggingSmsChannel
{
    private readonly ILogger<LoggingSmsChannel> _logger;

    public LoggingSmsChannel(ILogger<LoggingSmsChannel> logger) => _logger = logger;

    public static ConcurrentQueue<string> SentLog { get; } = new();

    public Task SendSmsAsync(SmsMessage message, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "SMS to {PhoneNumber}: {Text} (sender {SenderId})",
            message.PhoneNumber, message.Text, message.SenderId);
        SentLog.Enqueue($"SMS to {message.PhoneNumber}: {message.Text}");
        return Task.CompletedTask;
    }
}
