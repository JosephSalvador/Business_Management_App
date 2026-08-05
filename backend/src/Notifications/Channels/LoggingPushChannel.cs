using System.Collections.Concurrent;
using Microsoft.Extensions.Logging;
using PushMessage = BusinessOS.Application.Notifications.PushMessage;

namespace BusinessOS.Notifications.Channels;

public sealed class LoggingPushChannel
{
    private readonly ILogger<LoggingPushChannel> _logger;

    public LoggingPushChannel(ILogger<LoggingPushChannel> logger) => _logger = logger;

    public static ConcurrentQueue<string> SentLog { get; } = new();

    public Task SendPushAsync(PushMessage message, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "PUSH to {DeviceToken}: {Title} | {Body} (data {Data})",
            message.DeviceToken, message.Title, message.Body, message.Data);
        SentLog.Enqueue($"PUSH to {message.DeviceToken}: {message.Title} | {message.Body}");
        return Task.CompletedTask;
    }
}
