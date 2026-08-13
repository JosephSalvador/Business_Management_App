using BusinessOS.Application.Ports;
using BusinessOS.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Infrastructure.Locking;

/// <summary>
/// Acquires a PostgreSQL transaction advisory lock keyed on the tenant id. Because the lock is
/// an `xact` lock it is tied to the current database transaction: the caller must begin the
/// transaction on the same <see cref="BusinessDbContext"/> before acquiring, and the lock is
/// released when that transaction commits or rolls back. Executing this via the context ensures
/// the lock and the mutation share one connection and one transaction.
/// </summary>
public sealed class TenantAdvisoryLock : ITenantAdvisoryLock
{
    private const string AcquireSql =
        "SELECT pg_advisory_xact_lock(hashtextextended(CAST({0} AS text), 0))";

    private readonly BusinessDbContext _db;

    public TenantAdvisoryLock(BusinessDbContext db) => _db = db;

    public async Task AcquireAsync(Guid tenantId, CancellationToken cancellationToken = default)
        => await _db.Database.ExecuteSqlRawAsync(AcquireSql, new object[] { tenantId }, cancellationToken);
}
