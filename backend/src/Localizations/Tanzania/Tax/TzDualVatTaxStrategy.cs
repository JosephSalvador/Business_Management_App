using BusinessOS.Application.Tax;
using BusinessOS.Application.Tax.Strategies;
using BusinessOS.Domain.Sales;

namespace BusinessOS.Localizations.Tanzania.Tax;

/// <summary>
/// TRA dual-VAT selection (the server-side equivalent of the client POS logic), driven by the
/// payment context: cash → A (18); electronic without TIN → B (16); electronic with TIN and
/// VAT-registered → A; electronic with TIN and not VAT-registered → B. For inclusive prices the
/// embedded shelf rate (the highest effective rate, i.e. 18%) is extracted before applying the
/// selected rate, which reproduces the client's dual-VAT totals.
/// </summary>
/// <remarks>
/// This is a localization plug-in: it implements the core <see cref="ITaxCalculationStrategy"/>
/// contract and never requires core changes. The engine selects it solely through the
/// <see cref="TaxRule.CalculationStrategyKey"/> stored in the database.
/// </remarks>
public sealed class TzDualVatTaxStrategy : ITaxCalculationStrategy
{
    public string Key => TaxCalculationStrategies.TzDualVat;

    public TaxLineSnapshot Calculate(
        TaxCalculationLineItem item,
        IReadOnlyList<TaxRule> effectiveRules,
        TaxCalculationContext context)
    {
        var gross = item.UnitPrice * item.Quantity;

        return new TaxLineSnapshot(
            item.ItemId,
            "NONE",
            0m,
            TaxMath.RoundMoney(gross),
            0m,
            gross,
            null);
    }

    internal static TaxRule? SelectRule(IReadOnlyList<TaxRule> effectiveRules, TaxCalculationContext context)
    {
        var targetCode = ResolveTargetCode(context);
        var rule = effectiveRules
            .Where(r => r.Code == targetCode)
            .OrderByDescending(r => r.EffectiveFrom)
            .FirstOrDefault();

        return rule ?? DefaultPercentageTaxStrategy.LatestEffective(effectiveRules);
    }

    private static string ResolveTargetCode(TaxCalculationContext context)
    {
        if (!context.IsElectronicPayment)
        {
            return "A";
        }

        if (string.IsNullOrWhiteSpace(context.CustomerTin))
        {
            return "B";
        }

        return context.IsVatRegistered == true ? "A" : "B";
    }
}
