using BusinessOS.Application.Tax.Strategies;
using BusinessOS.Localizations.Tanzania.Tax;
using Microsoft.Extensions.DependencyInjection;

namespace BusinessOS.Localizations;

/// <summary>
/// Mounts the shipped localization plug-ins. The core engine stays agnostic: each strategy is
/// selected at sale time through the <see cref="TaxRule.CalculationStrategyKey"/> persisted on
/// the tenant's regime rules, never by the core referencing a country directly.
/// </summary>
public static class DependencyInjection
{
    public static IServiceCollection AddLocalizations(this IServiceCollection services)
    {
        services.AddSingleton<ITaxCalculationStrategy, TzDualVatTaxStrategy>();
        return services;
    }
}
