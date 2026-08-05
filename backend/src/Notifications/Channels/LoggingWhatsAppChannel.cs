using System.Collections.Concurrent;
using Microsoft.Extensions.Logging;
using WhatsAppMessage = BusinessOS.Application.Notifications.WhatsAppMessage;

namespace BusinessOS.Notifications.Channels;

public sealed class LoggingWhatsAppChannel
{
    private readonly ILogger<LoggingWhatsAppChannel> _logger;

    public LoggingWhatsAppChannel(ILogger<LoggingWhatsAppChannel> logger) => _logger = logger;

    public static ConcurrentQueue<string> SentLog { get; } = new();

    public Task SendWhatsAppAsync(WhatsAppMessage message, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "WHATSAPP to {PhoneNumber}: {Text}",
            message.PhoneNumber, message.Text);
        SentLog.Enqueue($"WHATSAPP to {message.PhoneNumber}: {message.Text}");
        return Task.CompletedTask;
    }
}
