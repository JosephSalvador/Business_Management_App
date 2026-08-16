namespace BusinessOS.Application.Tax;

/// <summary>
/// Stateless platform tax capability. Modules pass what is being transacted, where and when;
/// the engine resolves effective rules (and overrides) and returns per-line snapshots. Rate
/// selection strategies are data-driven via <see cref="Domain.Sales.TaxRule.CalculationStrategyKey"/>.
/// </summary>
public interface ITaxEngine
{
    Task<TaxCalculationResult> CalculateAsync(
        TaxCalculationContext context,
        CancellationToken cancellationToken = default);
}
