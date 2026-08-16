using BusinessOS.Domain.Sales;

namespace BusinessOS.Application.Tax.Strategies;

/// <summary>
/// A data-driven calculation strategy referenced by
/// <see cref="TaxRule.CalculationStrategyKey"/>. Pure math: given the line and the effective
/// rules for its category (in the tenant's regime), produce the line snapshot.
/// </summary>
public interface ITaxCalculationStrategy
{
    string Key { get; }

    TaxLineSnapshot Calculate(
        TaxCalculationLineItem item,
        IReadOnlyList<TaxRule> effectiveRules,
        TaxCalculationContext context);
}
