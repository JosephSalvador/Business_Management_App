using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Billing;

/// <summary>
/// A platform-level subscription plan a tenant subscribes to. Plans are a global catalog
/// (like tax regimes): seeded by the <c>DatabaseSeeder</c>, readable everywhere, and never
/// tenant-scoped. Quotas are optional — a null limit means "unlimited".
/// </summary>
public sealed class Plan : Entity
{
    public const string FreeCode = "Free";
    public const string ProCode = "Pro";
    public const string InvoiceManagerCode = "invoice-manager";
    public const string DefaultCurrency = "TZS";
    public const decimal ProMonthlyPriceDefaultTzs = 25_000m;
    public const decimal InvoiceManagerMonthlyPriceDefaultTzs = 15_000m;

    private Plan(
        Guid id,
        string code,
        string name,
        decimal monthlyPrice,
        string currency,
        string[] featureKeys,
        int? maxBranches,
        int? maxUsers,
        int? maxProducts,
        bool isPackage)
        : base(id)
    {
        Code = code;
        Name = name;
        MonthlyPrice = monthlyPrice;
        Currency = currency;
        FeatureKeys = featureKeys;
        MaxBranches = maxBranches;
        MaxUsers = maxUsers;
        MaxProducts = maxProducts;
        IsPackage = isPackage;
    }

    public string Code { get; private set; }
    public string Name { get; private set; }
    public decimal MonthlyPrice { get; private set; }
    public string Currency { get; private set; }

    /// <summary>Feature-flag keys the plan unlocks (persisted as a JSON array).</summary>
    public string[] FeatureKeys { get; private set; }

    public int? MaxBranches { get; private set; }
    public int? MaxUsers { get; private set; }
    public int? MaxProducts { get; private set; }
    public bool IsActive { get; private set; } = true;

    public bool IsPackage { get; private set; }

    public static Plan Create(
        string code,
        string name,
        decimal monthlyPrice,
        string currency,
        string[] featureKeys,
        int? maxBranches = null,
        int? maxUsers = null,
        int? maxProducts = null,
        bool isPackage = false)
        => new(
            Guid.NewGuid(),
            NormalizeCode(code),
            NormalizeName(name),
            ValidatePrice(monthlyPrice),
            NormalizeCurrency(currency),
            NormalizeFeatureKeys(featureKeys),
            maxBranches,
            maxUsers,
            maxProducts,
            isPackage);

    public static Plan Seed(
        string code,
        string name,
        decimal monthlyPrice,
        string currency,
        string[] featureKeys,
        int? maxBranches = null,
        int? maxUsers = null,
        int? maxProducts = null,
        bool isPackage = false)
        => Create(code, name, monthlyPrice, currency, featureKeys, maxBranches, maxUsers, maxProducts, isPackage);

    public void Deactivate() => IsActive = false;

    public void Reactivate() => IsActive = true;

    private static string NormalizeCode(string code) => code.Trim();

    private static string NormalizeName(string name)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            throw new ArgumentException("Plan name is required.", nameof(name));
        }

        return name.Trim();
    }

    private static decimal ValidatePrice(decimal monthlyPrice)
    {
        if (monthlyPrice < 0)
        {
            throw new ArgumentException("Monthly price cannot be negative.", nameof(monthlyPrice));
        }

        return monthlyPrice;
    }

    private static string NormalizeCurrency(string currency)
    {
        if (string.IsNullOrWhiteSpace(currency) || currency.Trim().Length != 3)
        {
            throw new ArgumentException("Currency must be an ISO 4217 code.", nameof(currency));
        }

        return currency.Trim().ToUpperInvariant();
    }

    private static string[] NormalizeFeatureKeys(string[] featureKeys)
    {
        if (featureKeys.Length == 0)
        {
            throw new ArgumentException("A plan must unlock at least one feature.", nameof(featureKeys));
        }

        return featureKeys.Distinct(StringComparer.Ordinal).ToArray();
    }
}