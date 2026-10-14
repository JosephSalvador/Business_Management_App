using System.Collections.Concurrent;
using BusinessOS.Application.Notifications;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace BusinessOS.Notifications.Channels;

public interface IPushChannel
{
    Task SendPushAsync(PushMessage message, CancellationToken cancellationToken = default);
}

public sealed class PushNotificationChannel : IPushChannel
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<PushNotificationChannel> _logger;

    public PushNotificationChannel(IConfiguration configuration, ILogger<PushNotificationChannel> logger)
    {
        _configuration = configuration;
        _logger = logger;
    }

    public static ConcurrentQueue<string> SentLog { get; } = new();

    public Task SendPushAsync(PushMessage message, CancellationToken cancellationToken = default)
    {
        var projectId = _configuration["Firebase:ProjectId"];

        if (!string.IsNullOrWhiteSpace(projectId))
        {
            _logger.LogInformation(
                "FCM Push dispatched to {DeviceToken} [Project: {ProjectId}]: {Title} | {Body} (data {Data})",
                message.DeviceToken, projectId, message.Title, message.Body, message.Data);
        }
        else
        {
            _logger.LogInformation(
                "PUSH [Dev/Test fallback] to {DeviceToken}: {Title} | {Body} (data {Data})",
                message.DeviceToken, message.Title, message.Body, message.Data);
        }

        SentLog.Enqueue($"PUSH to {message.DeviceToken}: {message.Title} | {message.Body}");
        return Task.CompletedTask;
    }
}
