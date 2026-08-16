using BusinessOS.Application.Features.Organizations.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Organizations.Commands;

public sealed record UpdateOrganizationCommand(
    string Name,
    string? ContactEmail,
    string? ContactPhone,
    string? Address,
    string CountryCode,
    string? TaxId) : IRequest<Result<OrganizationDto>>;

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

        tenant.UpdateProfile(
            command.Name.Trim(),
            command.ContactEmail?.Trim(),
            command.ContactPhone?.Trim(),
            command.Address?.Trim(),
            command.TaxId?.Trim());
        tenant.UpdateCountryCode(command.CountryCode);

        var dto = new OrganizationDto(
            tenant.Id,
            command.Name.Trim(),
            tenant.ContactEmail,
            tenant.ContactPhone,
            tenant.Address,
            tenant.Currency,
            tenant.CountryCode,
            tenant.TaxId,
            tenant.IsActive);

        return Result.Success(dto);
    }
}
