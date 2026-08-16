using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Sales;

/// <summary>
/// A versioned mapping of a tax category within a regime to a code, rate and optional
/// calculation strategy. Effective-dated so a line's snapshot references the exact rule
/// version that was in force on the sale date.
/// </summary>
public sealed class TaxRule : Entity
{
    private TaxRule(
        Guid id,
        Guid regimeId,
        Guid categoryId,
        string code,
        decimal rate,
        string? calculationStrategyKey,
        DateTime? effectiveFrom,
        DateTime? effectiveTo)
        : base(id)
    {
        RegimeId = regimeId;
        CategoryId = categoryId;
        Code = code;
        Rate = rate;
        CalculationStrategyKey = calculationStrategyKey;
        EffectiveFrom = effectiveFrom;
        EffectiveTo = effectiveTo;
    }

    public Guid RegimeId { get; private set; }
    public Guid CategoryId { get; private set; }
    public string Code { get; private set; }
    public decimal Rate { get; private set; }
    public string? CalculationStrategyKey { get; private set; }
    public DateTime? EffectiveFrom { get; private set; }
    public DateTime? EffectiveTo { get; private set; }

    public static TaxRule Create(
        Guid regimeId,
        Guid categoryId,
        string code,
        decimal rate,
        string? calculationStrategyKey = null,
        DateTime? effectiveFrom = null,
        DateTime? effectiveTo = null)
        => new(
            Guid.NewGuid(),
            regimeId,
            categoryId,
            NormalizeCode(code),
            ValidateRate(rate),
            calculationStrategyKey,
            effectiveFrom,
            effectiveTo);

    public static TaxRule Seed(
        Guid regimeId,
        Guid categoryId,
        string code,
        decimal rate,
        string? calculationStrategyKey = null,
        DateTime? effectiveFrom = null,
        DateTime? effectiveTo = null)
        => Create(regimeId, categoryId, code, rate, calculationStrategyKey, effectiveFrom, effectiveTo);

    public bool IsEffectiveAt(DateTime onDate)
        => (EffectiveFrom is null || EffectiveFrom <= onDate)
            && (EffectiveTo is null || EffectiveTo >= onDate);

    public bool HasSameSelectionKey(TaxRule other)
        => RegimeId == other.RegimeId
            && CategoryId == other.CategoryId
            && Code == other.Code;

    private static string NormalizeCode(string code)
    {
        if (string.IsNullOrWhiteSpace(code))
        {
            throw new ArgumentException("Tax rule code is required.", nameof(code));
        }

        return code.Trim().ToUpperInvariant();
    }

    private static decimal ValidateRate(decimal rate)
    {
        if (rate < 0 || rate > 1)
        {
            throw new ArgumentOutOfRangeException(nameof(rate), "Rate must be between 0 and 1.");
        }

        return rate;
    }
}
