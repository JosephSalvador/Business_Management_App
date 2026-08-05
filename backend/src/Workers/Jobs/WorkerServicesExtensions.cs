using BusinessOS.Application.Jobs;
using BusinessOS.Application.Ports;
using Microsoft.Extensions.DependencyInjection;

namespace BusinessOS.Workers.Jobs;

public static class WorkerServicesExtensions
{
    public static IServiceCollection AddBackgroundJobs(this IServiceCollection services)
    {
        services.AddScoped<IDomainEventHandler<SendEmailJob>, JobExecutionService>();
        services.AddScoped<IDomainEventHandler<SendSmsJob>, JobExecutionService>();
        services.AddScoped<IDomainEventHandler<SendPushJob>, JobExecutionService>();
        services.AddScoped<IDomainEventHandler<SendWhatsAppJob>, JobExecutionService>();
        services.AddHostedService<ScheduledJobRunner>();
        return services;
    }
}
