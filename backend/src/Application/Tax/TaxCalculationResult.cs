namespace BusinessOS.Application.Tax;

/// <summary>
/// Immutable per-line tax snapshot. Persisted verbatim onto the sale line so historical
/// invoices keep the exact code, rate and rule version in force on the sale date (EFD-ready).
/// <see cref="AppliedRuleId"/> is null only for the zero-tax fallback (no regime/rule applies).
/// </summary>
public sealed record TaxLineSnapshot(
    Guid ItemId,
    string TaxCode,
    decimal AppliedRate,
    decimal BaseAmount,
    decimal TaxAmount,
    decimal LineTotal,
    Guid? AppliedRuleId);

/// <summary>
/// Result of a tax calculation. The header never re-computes tax; totals are aggregates of the
/// per-line snapshots.
/// </summary>
public sealed record TaxCalculationResult(
    decimal TotalBaseAmount,
    decimal TotalTaxAmount,
    IReadOnlyList<TaxLineSnapshot> Lines);
