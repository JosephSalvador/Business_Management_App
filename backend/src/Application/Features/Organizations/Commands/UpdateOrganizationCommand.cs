using BusinessOS.Application.Features.Organizations.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Organizations.Commands;

public sealed record UpdateOrganizationCommand(
    string Name,
    string? ContactEmail = null,
    string? ContactPhone = null,
    string? Address = null,
    string CountryCode = "TZ",
    string? TaxId = null,
    string? Currency = null,
    string? Email = null,
    string? Phone = null,
    string? LogoBase64 = null,
    string? BankName = null,
    string? BankAccountName = null,
    string? BankAccountNumber = null,
    string? BankBranchOrSwift = null,
    string? MobileMoneyDetails = null,
    string? InvoiceTerms = null,
    string? AuthorizedSignatoryName = null,
    string? AuthorizedSignatoryTitle = null) : IRequest<Result<OrganizationDto>>;

public sealed class UpdateOrganizationCommandHandler
    : IRequestHandler<UpdateOrganizationCommand, Result<OrganizationDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ITenantRepository _tenants;

    public UpdateOrganizationCommandHandler(ITenantContext tenantContext, ITenantRepository tenants)
    {
        _tenantContext = tenantContext;
        _tenants = tenants;
    }

    public async Task<Result<OrganizationDto>> Handle(
        UpdateOrganizationCommand command, CancellationToken cancellationToken)
    {
        var tenant = await _tenants.GetByIdAsync(_tenantContext.TenantId, cancellationToken);
        if (tenant is null)
        {
            return Error.NotFound("Organization not found.");
        }

        var email = !string.IsNullOrWhiteSpace(command.ContactEmail) ? command.ContactEmail : command.Email;
        var phone = !string.IsNullOrWhiteSpace(command.ContactPhone) ? command.ContactPhone : command.Phone;

        tenant.UpdateProfile(
            command.Name.Trim(),
            email?.Trim(),
            phone?.Trim(),
            command.Address?.Trim(),
            command.TaxId?.Trim(),
            command.LogoBase64,
            command.BankName,
            command.BankAccountName,
            command.BankAccountNumber,
            command.BankBranchOrSwift,
            command.MobileMoneyDetails,
            command. InvoiceTerms,
            command.AuthorizedSignatoryName,
            command.AuthorizedSignatoryTitle);

        if (!string.IsNullOrWhiteSpace(command.CountryCode))
        {
            tenant.UpdateCountryCode(command.CountryCode);
        }

        if (!string.IsNullOrWhiteSpace(command.Currency))
        {
            tenant.UpdateCurrency(command.Currency);
        }

        var dto = new OrganizationDto(
            tenant.Id,
            tenant.Name,
            tenant.ContactEmail,
            tenant.ContactPhone,
            tenant.Address,
            tenant.Currency,
            tenant.CountryCode,
            tenant.TaxId,
            tenant.IsActive,
            tenant.LogoBase64,
            tenant.BankName,
            tenant.BankAccountName,
            tenant.BankAccountNumber,
            tenant.BankBranchOrSwift,
            tenant.MobileMoneyDetails,
            tenant.InvoiceTerms,
            tenant.AuthorizedSignatoryName,
            tenant.AuthorizedSignatoryTitle);

        return Result.Success(dto);
    }
}
