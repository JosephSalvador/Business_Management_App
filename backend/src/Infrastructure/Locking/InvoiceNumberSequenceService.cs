using BusinessOS.Application.Ports;
using BusinessOS.Infrastructure.Persistence;

namespace BusinessOS.Infrastructure.Locking;

/// <summary>
/// Concurrency-safe numbering for invoices and delivery notes. It refuses to run outside a
/// transaction (a number allocated outside one could not be rolled back, which would leave
/// gaps), re-takes the per-tenant transaction advisory lock (re-entrant within the same
/// session, so it is safe when the pipeline already holds it) and then increments the
/// <c>NumberSequences</c> row under <c>SELECT … FOR UPDATE</c>.
/// </summary>
public sealed class InvoiceNumberSequenceService : IInvoiceNumberSequenceService
{
    private readonly BusinessDbContext _db;
    private readonly ITenantAdvisoryLock _advisoryLock;
    private readonly INumberSequenceRepository _sequences;

    public InvoiceNumberSequenceService(
        BusinessDbContext db,
        ITenantAdvisoryLock advisoryLock,
        INumberSequenceRepository sequences)
    {
        _db = db;
        _advisoryLock = advisoryLock;
        _sequences = sequences;
    }

    public async Task<string> NextAsync(
        Guid tenantId, DocumentKind kind, DateTime date, CancellationToken cancellationToken = default)
    {
        if (tenantId == Guid.Empty)
        {
            throw new ArgumentException("A tenant is required to allocate a document number.", nameof(tenantId));
        }

        if (_db.Database.CurrentTransaction is null)
        {
            throw new InvalidOperationException(
                "Document numbers must be allocated inside a database transaction so that a " +
                "rolled-back document does not consume a number.");
        }

        await _advisoryLock.AcquireAsync(tenantId, cancellationToken);
        return await _sequences.AllocateAsync(tenantId, ScopeFor(kind), date, cancellationToken);
    }

    private static string ScopeFor(DocumentKind kind) => kind switch
    {
        DocumentKind.CustomerInvoice => "CustomerInvoice",
        DocumentKind.DeliveryNote => "DeliveryNote",
        _ => throw new ArgumentOutOfRangeException(nameof(kind), kind, "Unknown document kind."),
    };
}
