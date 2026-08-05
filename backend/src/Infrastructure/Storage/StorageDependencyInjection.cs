using BusinessOS.Shared.Configuration;
using BusinessOS.Shared.Storage;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace BusinessOS.Infrastructure.Storage;

public static class StorageDependencyInjection
{
    public static IServiceCollection AddFileStorage(this IServiceCollection services, IConfiguration configuration)
    {
        var options = configuration.GetSection(StorageOptions.SectionName).Get<StorageOptions>() ?? new StorageOptions();
        services.AddSingleton(options);

        if (string.Equals(options.Provider, "Local", StringComparison.OrdinalIgnoreCase))
        {
            services.AddSingleton<IFileStorage, LocalFileStorage>();
        }
        else
        {
            services.AddSingleton<IFileStorage, S3FileStorage>();
        }

        return services;
    }
}
