using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Sales;

/// <summary>
/// A country/authority tax pack (e.g. TZ_TRA). Platform-level; a tenant resolves one regime
/// through its <see cref="CountryCode"/>. Rules under a regime are effective-dated versions.
/// </summary>
public sealed class TaxRegime : Entity
{
    private TaxRegime(Guid id, string code, string name, string countryCode)
        : base(id)
    {
        Code = code;
        Name = name;
        CountryCode = countryCode;
    }

    public string Code { get; private set; }
    public string Name { get; private set; }
    public string CountryCode { get; private set; }

    public static TaxRegime Create(string code, string name, string countryCode)
        => new(Guid.NewGuid(), NormalizeCode(code), NormalizeName(name), NormalizeCountryCode(countryCode));

    public static TaxRegime Seed(string code, string name, string countryCode)
        => new(Guid.NewGuid(), NormalizeCode(code), NormalizeName(name), NormalizeCountryCode(countryCode));

    private static string NormalizeCode(string code)
    {
        if (string.IsNullOrWhiteSpace(code))
        {
            throw new ArgumentException("Tax regime code is required.", nameof(code));
        }

        return code.Trim().ToUpperInvariant();
    }

    private static string NormalizeName(string name)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            throw new ArgumentException("Tax regime name is required.", nameof(name));
        }

        return name.Trim();
    }

    private static string NormalizeCountryCode(string countryCode)
    {
        if (string.IsNullOrWhiteSpace(countryCode))
        {
            throw new ArgumentException("Country code is required.", nameof(countryCode));
        }

        return countryCode.Trim().ToUpperInvariant();
    }
}
