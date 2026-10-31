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
    public string? LogoBase64 { get; private set; }
    public string? BankName { get; private set; }
    public string? BankAccountName { get; private set; }
    public string? BankAccountNumber { get; private set; }
    public string? BankBranchOrSwift { get; private set; }
    public string? MobileMoneyDetails { get; private set; }
    public string? InvoiceTerms { get; private set; }
    public string? AuthorizedSignatoryName { get; private set; }
    public string? AuthorizedSignatoryTitle { get; private set; }
    public string? DatabaseSchema { get; private set; }
    public string? BusinessType { get; private set; }
    public DateTime? OnboardingCompletedAt { get; private set; }
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

    public void UpdateCurrency(string currency)
    {
        if (!string.IsNullOrWhiteSpace(currency) && currency.Trim().Length == 3)
        {
            Currency = currency.Trim().ToUpperInvariant();
        }
    }

    public void UpdateProfile(
        string name,
        string? contactEmail,
        string? contactPhone,
        string? address,
        string? taxId,
        string? logoBase64 = null,
        string? bankName = null,
        string? bankAccountName = null,
        string? bankAccountNumber = null,
        string? bankBranchOrSwift = null,
        string? mobileMoneyDetails = null,
        string? invoiceTerms = null,
        string? authorizedSignatoryName = null,
        string? authorizedSignatoryTitle = null)
    {
        Name = name.Trim();
        ContactEmail = contactEmail;
        ContactPhone = contactPhone;
        Address = address;
        TaxId = taxId;
        if (logoBase64 != null) LogoBase64 = string.IsNullOrWhiteSpace(logoBase64) ? null : logoBase64.Trim();
        if (bankName != null) BankName = string.IsNullOrWhiteSpace(bankName) ? null : bankName.Trim();
        if (bankAccountName != null) BankAccountName = string.IsNullOrWhiteSpace(bankAccountName) ? null : bankAccountName.Trim();
        if (bankAccountNumber != null) BankAccountNumber = string.IsNullOrWhiteSpace(bankAccountNumber) ? null : bankAccountNumber.Trim();
        if (bankBranchOrSwift != null) BankBranchOrSwift = string.IsNullOrWhiteSpace(bankBranchOrSwift) ? null : bankBranchOrSwift.Trim();
        if (mobileMoneyDetails != null) MobileMoneyDetails = string.IsNullOrWhiteSpace(mobileMoneyDetails) ? null : mobileMoneyDetails.Trim();
        if (invoiceTerms != null) InvoiceTerms = string.IsNullOrWhiteSpace(invoiceTerms) ? null : invoiceTerms.Trim();
        if (authorizedSignatoryName != null) AuthorizedSignatoryName = string.IsNullOrWhiteSpace(authorizedSignatoryName) ? null : authorizedSignatoryName.Trim();
        if (authorizedSignatoryTitle != null) AuthorizedSignatoryTitle = string.IsNullOrWhiteSpace(authorizedSignatoryTitle) ? null : authorizedSignatoryTitle.Trim();
    }

    /// <summary>
    /// Finalises the guided setup: profile fields, business type and currency in one
    /// mutation, stamping the completion timestamp that the workspace state is derived from.
    /// </summary>
    public void CompleteOnboarding(
        string name,
        string? businessType,
        string countryCode,
        string currency,
        string? contactPhone,
        string? taxId)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            throw new ArgumentException("Organization name is required.", nameof(name));
        }

        if (string.IsNullOrWhiteSpace(currency) || currency.Trim().Length != 3)
        {
            throw new ArgumentException("Currency must be an ISO 4217 code.", nameof(currency));
        }

        Name = name.Trim();
        BusinessType = string.IsNullOrWhiteSpace(businessType) ? null : businessType.Trim();
        ContactPhone = contactPhone?.Trim();
        TaxId = taxId?.Trim();
        UpdateCountryCode(countryCode);
        Currency = currency.Trim().ToUpperInvariant();
        OnboardingCompletedAt = DateTime.UtcNow;
    }

    public void Activate() => IsActive = true;

    public void Deactivate() => IsActive = false;
}
