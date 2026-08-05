using BusinessOS.Application.Ports;
using Microsoft.Extensions.DependencyInjection;

namespace BusinessOS.Infrastructure.Authorization;

public static class PermissionDependencyInjection
{
    public static IServiceCollection AddPermissionEngine(this IServiceCollection services)
    {
        services.AddScoped<IPermissionService, PermissionCacheService>();
        return services;
    }
}
