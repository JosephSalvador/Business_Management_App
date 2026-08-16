using BusinessOS.Application.Ports;
using BusinessOS.Application.Tax.Strategies;
using BusinessOS.Domain.Sales;

namespace BusinessOS.Application.Tax;

/// <summary>
/// Data-driven tax engine: resolves the tenant's regime, applies temporal rule matching,
/// category fallback, exemption overrides, then dispatches each line to the calculation
/// strategy named by its rules. Pure orchestration — all math lives in the strategies.
/// </summary>
public sealed class TaxService : ITaxEngine
{
    private readonly ITaxRuleRepository _rules;
    private readonly IReadOnlyDictionary<string, ITaxCalculationStrategy> _strategies;

    public TaxService(
        ITaxRuleRepository rules,
        IEnumerable<ITaxCalculationStrategy> strategies)
    {
        _rules = rules;
        var byKey = strategies.ToDictionary(s => s.Key, StringComparer.Ordinal);
        byKey.TryAdd(TaxCalculationStrategies.Simple, new DefaultPercentageTaxStrategy());
        _strategies = byKey;
    }

    public async Task<TaxCalculationResult> CalculateAsync(
        TaxCalculationContext context, CancellationToken cancellationToken)
    {
        if (context.Items.Any(i => i.Quantity <= 0))
        {
            throw new ArgumentOutOfRangeException(nameof(context), "Line quantities must be positive.");
        }

        var regime = await _rules.GetRegimeForTenantAsync(context.TenantId, cancellationToken);
        var exemptions = regime is null
            ? Array.Empty<TaxExemption>()
            : await _rules.ListExemptionsAsync(context.TenantId, cancellationToken);
        var effectiveRules = regime is null
            ? Array.Empty<TaxRule>()
            : await _rules.ListEffectiveRulesAsync(regime.Id, context.TransactionDate, cancellationToken);
        var categories = await _rules.ListCategoriesByCodesAsync(
            context.Items.Select(i => i.TaxCategoryCode).Distinct(), cancellationToken);
        var categoryByCode = categories.ToDictionary(c => c.Code, StringComparer.Ordinal);

        var snapshots = new List<TaxLineSnapshot>(context.Items.Count);
        foreach (var item in context.Items)
        {
            snapshots.Add(CalculateLine(item, effectiveRules, exemptions, categoryByCode, context));
        }

        return new TaxCalculationResult(
            snapshots.Sum(s => s.BaseAmount),
            snapshots.Sum(s => s.TaxAmount),
            snapshots);
    }

    private TaxLineSnapshot CalculateLine(
        TaxCalculationLineItem item,
        IReadOnlyList<TaxRule> effectiveRules,
        IReadOnlyList<TaxExemption> exemptions,
        IReadOnlyDictionary<string, TaxCategory> categoryByCode,
        TaxCalculationContext context)
    {
        if (!categoryByCode.TryGetValue(item.TaxCategoryCode, out var category))
        {
            return TaxMath.ZeroSnapshot(item, "NONE", rate: 0m);
        }

        var categoryRules = effectiveRules.Where(r => r.CategoryId == category.Id).ToArray();
        if (categoryRules.Length == 0)
        {
            return TaxMath.ZeroSnapshot(item, "NONE", rate: 0m);
        }

        if (IsExempt(category.Id, exemptions, context))
        {
            return ExemptSnapshot(item, categoryRules);
        }

        return ResolveStrategy(categoryRules).Calculate(item, categoryRules, context);
    }

    private ITaxCalculationStrategy ResolveStrategy(IReadOnlyList<TaxRule> categoryRules)
    {
        var key = categoryRules
            .Where(r => r.CalculationStrategyKey is not null && r.CalculationStrategyKey != TaxCalculationStrategies.Simple)
            .OrderByDescending(r => r.EffectiveFrom)
            .Select(r => r.CalculationStrategyKey!)
            .FirstOrDefault();

        return key is not null && _strategies.TryGetValue(key, out var strategy)
            ? strategy
            : _strategies[TaxCalculationStrategies.Simple];
    }

    private static bool IsExempt(
        Guid categoryId, IReadOnlyList<TaxExemption> exemptions, TaxCalculationContext context)
        => exemptions.Any(e =>
            e.CategoryId == categoryId && e.AppliesTo(transactionType: null, context.CustomerId, context.TransactionDate));

    private static TaxLineSnapshot ExemptSnapshot(
        TaxCalculationLineItem item, IReadOnlyList<TaxRule> categoryRules)
    {
        var zeroRule = categoryRules
            .Where(r => r.Rate == 0m)
            .OrderByDescending(r => r.EffectiveFrom)
            .FirstOrDefault();

        if (zeroRule is null)
        {
            return TaxMath.ZeroSnapshot(item, "EXEMPT", rate: 0m);
        }

        var gross = TaxMath.RoundMoney(item.UnitPrice * item.Quantity);
        return new TaxLineSnapshot(item.ItemId, zeroRule.Code, 0m, gross, 0m, gross, zeroRule.Id);
    }
}
