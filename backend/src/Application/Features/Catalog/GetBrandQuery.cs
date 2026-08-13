using BusinessOS.Application.Features.Catalog.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Catalog;

public sealed record GetBrandQuery(Guid Id) : IRequest<Result<BrandDto>>;

public sealed class GetBrandQueryHandler : IRequestHandler<GetBrandQuery, Result<BrandDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IBrandRepository _brands;

    public GetBrandQueryHandler(ITenantContext tenantContext, IBrandRepository brands)
    {
        _tenantContext = tenantContext;
        _brands = brands;
    }

    public async Task<Result<BrandDto>> Handle(GetBrandQuery request, CancellationToken cancellationToken)
    {
        var brand = await _brands.GetByIdAsync(_tenantContext.TenantId, request.Id, cancellationToken);
        if (brand is null)
        {
            return Error.NotFound("Brand not found.");
        }

        return Result.Success(CatalogMappers.ToBrandDto(brand));
    }
}
