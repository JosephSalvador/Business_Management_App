using BusinessOS.Application.Ports;
using BusinessOS.Domain.Events;
using BusinessOS.Notifications.Channels;
using BusinessOS.Notifications.Events;
using Microsoft.Extensions.DependencyInjection;
using INotificationService = BusinessOS.Application.Ports.INotificationService;

namespace BusinessOS.Notifications;

public static class NotificationEngineExtensions
{
    public static IServiceCollection AddNotificationEngine(this IServiceCollection services)
    {
        services.AddOptions();

        services.AddScoped<EmailChannel>();
        services.AddScoped<LoggingSmsChannel>();
        services.AddScoped<LoggingPushChannel>();
        services.AddScoped<LoggingWhatsAppChannel>();
        services.AddScoped<INotificationService, NotificationService>();
        services.AddScoped<IDomainEventHandler<UserRegisteredEvent>, UserRegisteredNotificationHandler>();
        services.AddScoped<IDomainEventHandler<UserRegisteredEvent>, UserRegisteredAnalyticsHandler>();
        services.AddScoped<IDomainEventHandler<UserRegisteredEvent>, UserRegisteredActivityFeedHandler>();

        return services;
    }
}
