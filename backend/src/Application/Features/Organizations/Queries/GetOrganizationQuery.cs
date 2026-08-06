using BusinessOS.Application.Features.Organizations.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Organizations.Queries;

public sealed record GetOrganizationQuery : IRequest<Result<OrganizationDto>>;

public sealed class GetOrganizationQueryHandler : IRequestHandler<GetOrganizationQuery, Result<OrganizationDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ITenantRepository _tenants;

    public GetOrganizationQueryHandler(ITenantContext tenantContext, ITenantRepository tenants)
    {
        _tenantContext = tenantContext;
        _tenants = tenants;
    }

    public async Task<Result<OrganizationDto>> Handle(
        GetOrganizationQuery request, CancellationToken cancellationToken)
    {
        var tenant = await _tenants.GetByIdAsync(_tenantContext.TenantId, cancellationToken);
        if (tenant is null)
        {
            return Error.NotFound("Organization not found.");
        }

        var dto = new OrganizationDto(
            tenant.Id,
            tenant.Name,
            tenant.ContactEmail,
            tenant.ContactPhone,
            tenant.Address,
            tenant.Currency,
            tenant.TaxId,
            tenant.IsActive);

        return Result.Success(dto);
    }
}
