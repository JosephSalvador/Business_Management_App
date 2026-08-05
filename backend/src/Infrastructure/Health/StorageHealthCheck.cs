using BusinessOS.Shared.Storage;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace BusinessOS.Infrastructure.Health;

public sealed class StorageHealthCheck : IHealthCheck
{
    private readonly IFileStorage _storage;

    public StorageHealthCheck(IFileStorage storage) => _storage = storage;

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            const string probeKey = "health/.probe";
            await _storage.ExistsAsync(probeKey, cancellationToken);
            return HealthCheckResult.Healthy("Storage reachable.");
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy("Storage check failed.", ex);
        }
    }
}
