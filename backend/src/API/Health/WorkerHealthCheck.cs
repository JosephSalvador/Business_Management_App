using BusinessOS.Shared.Health;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace BusinessOS.Api.Health;

public sealed class WorkerHealthCheck : IHealthCheck
{
    private readonly WorkerHeartbeatRegistry _registry;
    private readonly TimeSpan _staleness;

    public WorkerHealthCheck(WorkerHeartbeatRegistry registry, IConfiguration configuration)
    {
        _registry = registry;
        var minutes = configuration.GetValue<int>("Health:WorkerStalenessMinutes", 2);
        _staleness = TimeSpan.FromMinutes(minutes);
    }

    public Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        var names = _registry.WorkerNames;
        if (names.Count == 0)
        {
            return Task.FromResult(HealthCheckResult.Healthy("No workers registered (skipped)."));
        }

        var stale = names.Where(name => _registry.IsStale(name, _staleness)).ToList();
        var fresh = names.Count - stale.Count;

        var description = stale.Count == 0
            ? $"All {names.Count} worker(s) heartbeating within {_staleness.TotalMinutes:0} min."
            : $"Stale workers: {string.Join(", ", stale)}";

        return Task.FromResult(fresh > 0
            ? HealthCheckResult.Healthy(description)
            : HealthCheckResult.Unhealthy(description));
    }
}
