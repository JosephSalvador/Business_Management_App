namespace BusinessOS.Domain.Sales;

/// <summary>
/// Whether a receipt print is the original, a customer-requested copy, or a later reprint.
/// Used by the audit trail to detect potential fraud (e.g. reprints of voided receipts).
/// </summary>
public enum PrintType
{
    Original = 0,
    CustomerCopy = 1,
    Reprint = 2,
}
