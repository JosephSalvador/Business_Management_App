namespace BusinessOS.Application.Tax;

/// <summary>
/// Shared money math for tax calculations: 2-dp rounding (midpoint away from zero, receipt-safe)
/// and VAT extraction from inclusive shelf prices (gross ÷ (1 + embedded rate)).
/// </summary>
public static class TaxMath
{
    public static decimal RoundMoney(decimal value)
        => Math.Round(value, 2, MidpointRounding.AwayFromZero);

    /// <summary>
    /// Unrounded VAT-exclusive base extracted from an inclusive gross at the shelf rate. Kept
    /// unrounded so the 18% case lands exactly on the shelf price after per-line rounding of
    /// base and tax (matching the client POS totals).
    /// </summary>
    public static decimal ExtractInclusiveBase(decimal gross, decimal embeddedRate)
        => gross / (1m + embeddedRate);

    /// <summary>
    /// Zero-tax snapshot used for the no-regime/no-rule fallback and for exempt lines without a
    /// seeded zero rule. The gross is kept as the line total (no embedded-tax extraction), so a
    /// fallback never silently changes what the customer pays.
    /// </summary>
    public static TaxLineSnapshot ZeroSnapshot(TaxCalculationLineItem item, string code, decimal rate)
    {
        var gross = RoundMoney(item.UnitPrice * item.Quantity);
        return new TaxLineSnapshot(item.ItemId, code, rate, gross, 0m, gross, AppliedRuleId: null);
    }
}
