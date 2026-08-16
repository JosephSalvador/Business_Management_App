namespace BusinessOS.Domain.Sales;

/// <summary>
/// Calculation-strategy keys referenced by <see cref="TaxRule.CalculationStrategyKey"/>.
/// Simple = plain percentage of the base. A regime may name a custom strategy for compound or
/// context-selected calculations (e.g. the TRA dual-VAT A/B selection).
/// </summary>
public static class TaxCalculationStrategies
{
    public const string Simple = "Simple";
    public const string TzDualVat = "TZ_DUAL_VAT";
}
