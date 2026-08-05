using BusinessOS.Infrastructure.Health;
using BusinessOS.Shared.Health;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace BusinessOS.Api.Health;

public static class PlatformHealthExtensions
{
    public static IServiceCollection AddPlatformHealthChecks(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddSingleton<WorkerHeartbeatRegistry>();

        services.AddScoped<DatabaseHealthCheck>();
        services.AddScoped<RedisHealthCheck>();
        services.AddScoped<StorageHealthCheck>();
        services.AddScoped<WorkerHealthCheck>();

        services.AddHealthChecks()
            .AddCheck<DatabaseHealthCheck>("database")
            .AddCheck<RedisHealthCheck>("redis")
            .AddCheck<StorageHealthCheck>("storage")
            .AddCheck<WorkerHealthCheck>("workers");

        return services;
    }

    public static IApplicationBuilder MapPlatformHealthEndpoints(this IApplicationBuilder app)
    {
        if (app is not IEndpointRouteBuilder endpoints)
        {
            throw new InvalidOperationException(
                $"{nameof(MapPlatformHealthEndpoints)} requires an application that implements {nameof(IEndpointRouteBuilder)}.");
        }

        endpoints.MapHealthChecks("/health/live", new HealthCheckOptions
        {
            Predicate = _ => false,
        });

        endpoints.MapHealthChecks("/health/ready", new HealthCheckOptions
        {
            Predicate = _ => true,
            AllowCachingResponses = false,
        });

        return app;
    }
}
