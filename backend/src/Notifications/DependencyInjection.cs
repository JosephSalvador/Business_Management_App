using BusinessOS.Application.Ports;
using BusinessOS.Domain.Events;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace BusinessOS.Notifications;

public static class DependencyInjection
{
    public static IServiceCollection AddNotifications(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddScoped<INotificationService, LoggingNotificationService>();
        services.AddScoped<IDomainEventHandler<UserRegisteredEvent>, UserRegisteredNotificationHandler>();
        return services;
    }
}
