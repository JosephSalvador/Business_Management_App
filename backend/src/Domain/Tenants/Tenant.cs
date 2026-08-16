using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Tenants;

public sealed class Tenant : AggregateRoot
{
    public const string DefaultCurrency = "TZS";
    public const string DefaultCountryCode = "TZ";

    private Tenant(Guid id, string name, string currency, string? databaseSchema, string countryCode)
        : base(id)
    {
        Name = name;
        Currency = currency;
        DatabaseSchema = databaseSchema;
        CountryCode = countryCode;
    }

    public string Name { get; private set; }
    public string Currency { get; private set; }
    public string CountryCode { get; private set; }
    public string? ContactEmail { get; private set; }
    public string? ContactPhone { get; private set; }
    public string? Address { get; private set; }
    public string? TaxId { get; private set; }
    public string? DatabaseSchema { get; private set; }
    public bool IsActive { get; private set; } = true;

    public static Tenant Create(
        Guid id, string name, string? currency = null, string? databaseSchema = null, string? countryCode = null)
        => new(
            id,
            name,
            currency ?? DefaultCurrency,
            databaseSchema,
            (countryCode ?? DefaultCountryCode).Trim().ToUpperInvariant());

    public void UpdateCountryCode(string countryCode)
    {
        if (string.IsNullOrWhiteSpace(countryCode))
        {
            throw new ArgumentException("Country code is required.", nameof(countryCode));
        }

        CountryCode = countryCode.Trim().ToUpperInvariant();
    }

    public void UpdateProfile(string name, string? contactEmail, string? contactPhone, string? address, string? taxId)
    {
        Name = name.Trim();
        ContactEmail = contactEmail;
        ContactPhone = contactPhone;
        Address = address;
        TaxId = taxId;
    }

    public void Activate() => IsActive = true;

    public void Deactivate() => IsActive = false;
}
