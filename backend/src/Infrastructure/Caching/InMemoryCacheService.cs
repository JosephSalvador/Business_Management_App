using System.Text.Json;
using BusinessOS.Application.Ports;

namespace BusinessOS.Infrastructure.Caching;

/// <summary>
/// Dev-safe cache used when Redis is not configured. Same contract, no external dependency.
/// </summary>
public sealed class InMemoryCacheService : ICacheService
{
    private readonly object _lock = new();
    private readonly Dictionary<string, (string Payload, DateTime? ExpiresAt)> _store = new();

    public Task<T?> GetAsync<T>(string key, CancellationToken cancellationToken = default)
    {
        lock (_lock)
        {
            if (!_store.TryGetValue(key, out var entry))
            {
                return Task.FromResult<T?>(default);
            }

            if (entry.ExpiresAt is { } expires && expires <= DateTime.UtcNow)
            {
                _store.Remove(key);
                return Task.FromResult<T?>(default);
            }

            var value = JsonSerializer.Deserialize<T>(entry.Payload);
            return Task.FromResult<T?>(value);
        }
    }

    public Task SetAsync<T>(string key, T value, TimeSpan? ttl = null, CancellationToken cancellationToken = default)
    {
        lock (_lock)
        {
            _store[key] = (
                JsonSerializer.Serialize(value),
                ttl is null ? null : DateTime.UtcNow.Add(ttl.Value));
            return Task.CompletedTask;
        }
    }

    public Task RemoveAsync(string key, CancellationToken cancellationToken = default)
    {
        lock (_lock)
        {
            _store.Remove(key);
            return Task.CompletedTask;
        }
    }
}
