namespace BusinessOS.Application.Features.Organizations.Dtos;

public sealed record OrganizationDto(
    Guid Id,
    string Name,
    string? ContactEmail,
    string? ContactPhone,
    string? Address,
    string Currency,
    string CountryCode,
    string? TaxId,
    bool IsActive,
    string? LogoBase64 = null,
    string? BankName = null,
    string? BankAccountName = null,
    string? BankAccountNumber = null,
    string? BankBranchOrSwift = null,
    string? MobileMoneyDetails = null,
    string? InvoiceTerms = null,
    string? AuthorizedSignatoryName = null,
    string? AuthorizedSignatoryTitle = null)
{
    public string? Email => ContactEmail;
    public string? Phone => ContactPhone;
}

public sealed record TenantOrganizationDto(
    Guid Id,
    string Name,
    string? Email,
    string? Phone,
    string? Address,
    string Currency,
    string CountryCode,
    string? Tin,
    string? LogoBase64 = null,
    string? BankName = null,
    string? BankAccountName = null,
    string? BankAccountNumber = null,
    string? BankBranchOrSwift = null,
    string? MobileMoneyDetails = null,
    string? InvoiceTerms = null,
    string? AuthorizedSignatoryName = null,
    string? AuthorizedSignatoryTitle = null)
{
    public static TenantOrganizationDto From(OrganizationDto org) => new(
        org.Id,
        org.Name,
        org.Email,
        org.Phone,
        org.Address,
        org.Currency,
        org.CountryCode,
        org.TaxId,
        org.LogoBase64,
        org.BankName,
        org.BankAccountName,
        org.BankAccountNumber,
        org.BankBranchOrSwift,
        org.MobileMoneyDetails,
        org.InvoiceTerms,
        org.AuthorizedSignatoryName,
        org.AuthorizedSignatoryTitle);
}

