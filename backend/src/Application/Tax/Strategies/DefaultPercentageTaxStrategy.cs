using BusinessOS.Domain.Sales;

namespace BusinessOS.Application.Tax.Strategies;

/// <summary>
/// Plain percentage of the base. Works for the majority of jurisdictions: picks the latest
/// effective rule for the line's category; for inclusive prices the shelf price embeds the
/// highest effective rate for the category, which is extracted first. This is the core
/// fallback — localization strategies may reuse <see cref="LatestEffective"/> and
/// <see cref="EmbeddedRate"/>.
/// </summary>
public sealed class DefaultPercentageTaxStrategy : ITaxCalculationStrategy
{
    public string Key => TaxCalculationStrategies.Simple;

    public TaxLineSnapshot Calculate(
        TaxCalculationLineItem item,
        IReadOnlyList<TaxRule> effectiveRules,
        TaxCalculationContext context)
    {
        var rule = LatestEffective(effectiveRules);
        var gross = item.UnitPrice * item.Quantity;
        var baseAmount = item.IsPriceTaxInclusive
            ? TaxMath.ExtractInclusiveBase(gross, EmbeddedRate(effectiveRules))
            : gross;
        var baseRounded = TaxMath.RoundMoney(baseAmount);
        var taxAmount = TaxMath.RoundMoney(baseAmount * rule.Rate);

        return new TaxLineSnapshot(
            item.ItemId,
            rule.Code,
            rule.Rate,
            baseRounded,
            taxAmount,
            TaxMath.RoundMoney(baseRounded + taxAmount),
            rule.Id);
    }

    public static TaxRule LatestEffective(IReadOnlyList<TaxRule> rules)
        => rules.OrderByDescending(r => r.EffectiveFrom).First();

    public static decimal EmbeddedRate(IReadOnlyList<TaxRule> rules)
        => rules.Max(r => r.Rate);
}
