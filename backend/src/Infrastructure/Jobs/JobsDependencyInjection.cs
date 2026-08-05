using BusinessOS.Application.Ports;
using Microsoft.Extensions.DependencyInjection;

namespace BusinessOS.Infrastructure.Jobs;

public static class JobsDependencyInjection
{
    public static IServiceCollection AddJobQueue(this IServiceCollection services)
    {
        services.AddScoped<IJobQueue, OutboxJobQueue>();
        return services;
    }
}
