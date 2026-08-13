namespace BusinessOS.Application.Ports;

/// <summary>
/// Serializes per-tenant operations that can violate a tenant invariant under concurrency
/// (e.g. removing the last active system Administrator). The lock is a PostgreSQL transaction
/// advisory lock (`pg_advisory_xact_lock`): it is acquired and released on the same database
/// transaction that performs the mutation, so the guard reads and the write are atomic.
/// </summary>
public interface ITenantAdvisoryLock
{
    Task AcquireAsync(Guid tenantId, CancellationToken cancellationToken = default);
}
