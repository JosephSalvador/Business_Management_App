namespace BusinessOS.Application.Ports;

/// <summary>
/// Marker for requests whose mutation must run inside a per-tenant serialized transaction:
/// the pipeline begins a database transaction and acquires the tenant advisory lock before the
/// handler runs, and commits (or rolls back) with it.
/// </summary>
public interface IRequiresTenantAdvisoryLock;
