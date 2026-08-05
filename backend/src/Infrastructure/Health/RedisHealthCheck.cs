using BusinessOS.Shared.Configuration;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using StackExchange.Redis;

namespace BusinessOS.Infrastructure.Health;

public sealed class RedisHealthCheck : IHealthCheck
{
    private readonly IConfiguration _configuration;

    public RedisHealthCheck(IConfiguration configuration) => _configuration = configuration;

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        var options = _configuration.GetSection(RedisOptions.SectionName).Get<RedisOptions>() ?? new RedisOptions();
        if (!options.Enabled || string.IsNullOrWhiteSpace(options.ConnectionString))
        {
            return HealthCheckResult.Healthy("Redis not configured (skipped).");
        }

        try
        {
            await using var muxer = await ConnectionMultiplexer.ConnectAsync(
                options.ConnectionString,
                static redis => redis.AbortOnConnectFail = false,
                TextWriter.Null);

            await muxer.GetDatabase().PingAsync();

            return HealthCheckResult.Healthy("Redis reachable.");
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy("Redis check failed.", ex);
        }
    }
}
