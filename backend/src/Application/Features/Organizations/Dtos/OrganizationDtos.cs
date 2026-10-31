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

