namespace BusinessOS.Application.Ports;

/// <summary>The invoicing documents that draw numbers from a per-tenant sequence.</summary>
public enum DocumentKind
{
    CustomerInvoice = 0,
    DeliveryNote = 1,
}

/// <summary>
/// Allocates the next sequential document number (e.g. <c>CINV-2026-000042</c>) for a tenant.
/// <para>
/// Must be called inside the caller's database transaction: the sequence row is locked
/// (<c>SELECT … FOR UPDATE</c> under the tenant advisory lock) and incremented in that same
/// transaction, so a rolled-back document never burns a number (no gaps) and concurrent
/// cashiers are serialised (no collisions).
/// </para>
/// </summary>
public interface IInvoiceNumberSequenceService
{
    Task<string> NextAsync(
        Guid tenantId, DocumentKind kind, DateTime date, CancellationToken cancellationToken = default);
}
