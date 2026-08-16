using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Sales;

/// <summary>
/// Abstract, platform-level tax classification that products and services reference.
/// Modules only ever touch categories, never country-specific rates or codes.
/// </summary>
public sealed class TaxCategory : Entity
{
    private TaxCategory(Guid id, string code, string name)
        : base(id)
    {
        Code = code;
        Name = name;
    }

    public string Code { get; private set; }
    public string Name { get; private set; }

    public static TaxCategory Create(string code, string name)
        => new(Guid.NewGuid(), NormalizeCode(code), NormalizeName(name));

    public static TaxCategory Seed(string code, string name)
        => new(Guid.NewGuid(), NormalizeCode(code), NormalizeName(name));

    private static string NormalizeCode(string code)
    {
        if (string.IsNullOrWhiteSpace(code))
        {
            throw new ArgumentException("Tax category code is required.", nameof(code));
        }

        return code.Trim().ToUpperInvariant();
    }

    private static string NormalizeName(string name)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            throw new ArgumentException("Tax category name is required.", nameof(name));
        }

        return name.Trim();
    }
}
