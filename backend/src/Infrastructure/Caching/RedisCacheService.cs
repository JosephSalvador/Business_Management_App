using System.Text.Json;
using BusinessOS.Application.Ports;
using Microsoft.Extensions.Caching.Distributed;

namespace BusinessOS.Infrastructure.Caching;

/// <summary>Redis-backed cache. Used when a Redis connection string is configured.</summary>
public sealed class RedisCacheService : ICacheService
{
    private readonly IDistributedCache _cache;

    public RedisCacheService(IDistributedCache cache) => _cache = cache;

    public async Task<T?> GetAsync<T>(string key, CancellationToken cancellationToken = default)
    {
        var payload = await _cache.GetStringAsync(key, cancellationToken);
        return payload is null ? default : JsonSerializer.Deserialize<T>(payload);
    }

    public Task SetAsync<T>(string key, T value, TimeSpan? ttl = null, CancellationToken cancellationToken = default)
    {
        var options = new DistributedCacheEntryOptions();
        if (ttl is not null)
        {
            options.AbsoluteExpirationRelativeToNow = ttl;
        }

        return _cache.SetStringAsync(key, JsonSerializer.Serialize(value), options, cancellationToken);
    }

    public Task RemoveAsync(string key, CancellationToken cancellationToken = default)
        => _cache.RemoveAsync(key, cancellationToken);
}
