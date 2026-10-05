using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Sales;

/// <summary>
/// An immutable audit-log entry recording every time a receipt is printed for a sale.
/// The first print is the <see cref="PrintType.Original"/>; subsequent prints are
/// <see cref="PrintType.Reprint"/> or <see cref="PrintType.CustomerCopy"/>. The
/// renderer detects reprints and injects a visible "REPRINT" watermark to prevent
/// cashiers from reusing printed slips for fraud or double-claiming expenses.
/// This entity is write-once: it is never updated or deleted.
/// </summary>
public sealed class ReceiptPrintEvent : Entity
{
    private ReceiptPrintEvent(
        Guid saleId,
        Guid tenantId,
        Guid printedByUserId,
        DateTime printedAt,
        PrintType type,
        Guid? layoutVersionId,
        string? deviceId,
        string? notes)
    {
        SaleId = saleId;
        TenantId = tenantId;
        PrintedByUserId = printedByUserId;
        PrintedAt = printedAt;
        Type = type;
        LayoutVersionId = layoutVersionId;
        DeviceId = deviceId;
        Notes = notes;
    }

    public Guid SaleId { get; private set; }
    public Guid TenantId { get; private set; }
    public Guid PrintedByUserId { get; private set; }
    public DateTime PrintedAt { get; private set; }

    /// <summary>Original, CustomerCopy, or Reprint.</summary>
    public PrintType Type { get; private set; }

    /// <summary>The layout version used for this particular print.</summary>
    public Guid? LayoutVersionId { get; private set; }

    /// <summary>Optional device identifier for the audit trail (e.g. POS terminal, printer id).</summary>
    public string? DeviceId { get; private set; }

    /// <summary>Optional reason or notes for the print (especially for reprints).</summary>
    public string? Notes { get; private set; }

    public static ReceiptPrintEvent Create(
        Guid saleId,
        Guid tenantId,
        Guid printedByUserId,
        PrintType type,
        Guid? layoutVersionId = null,
        string? deviceId = null,
        string? notes = null)
    {
        if (saleId == Guid.Empty)
        {
            throw new ArgumentException("A sale is required.", nameof(saleId));
        }

        if (tenantId == Guid.Empty)
        {
            throw new ArgumentException("A tenant is required.", nameof(tenantId));
        }

        if (printedByUserId == Guid.Empty)
        {
            throw new ArgumentException("A printing user is required.", nameof(printedByUserId));
        }

        return new ReceiptPrintEvent(
            saleId,
            tenantId,
            printedByUserId,
            DateTime.UtcNow,
            type,
            layoutVersionId,
            Normalize(deviceId),
            Normalize(notes));
    }

    private static string? Normalize(string? value)
        => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
