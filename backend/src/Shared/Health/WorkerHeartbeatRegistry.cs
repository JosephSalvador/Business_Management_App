using System.Collections.Concurrent;

namespace BusinessOS.Shared.Health;

/// <summary>
/// Thread-safe singleton registry of worker heartbeats, shared between the API
/// (readiness reporting) and the worker processes (heartbeat producers).
/// </summary>
public sealed class WorkerHeartbeatRegistry
{
    private readonly ConcurrentDictionary<string, DateTimeOffset> _heartbeats = new();

    public void Register(string workerName, DateTimeOffset? initial = null)
        => _heartbeats.TryAdd(workerName, initial ?? DateTimeOffset.UtcNow);

    public void Beat(string workerName, DateTimeOffset at)
        => _heartbeats[workerName] = at;

    public DateTimeOffset? LastHeartbeat(string workerName)
        => _heartbeats.TryGetValue(workerName, out var at) ? at : null;

    public bool IsStale(string workerName, TimeSpan threshold)
        => _heartbeats.TryGetValue(workerName, out var at) && DateTimeOffset.UtcNow - at > threshold;

    public IReadOnlyCollection<string> WorkerNames => (IReadOnlyCollection<string>)_heartbeats.Keys;
}
