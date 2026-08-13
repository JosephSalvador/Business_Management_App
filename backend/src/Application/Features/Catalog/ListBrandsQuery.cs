using BusinessOS.Application.Features.Catalog.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Catalog;

public sealed record ListBrandsQuery() : IRequest<Result<IReadOnlyList<BrandDto>>>;

public sealed class ListBrandsQueryHandler : IRequestHandler<ListBrandsQuery, Result<IReadOnlyList<BrandDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IBrandRepository _brands;

    public ListBrandsQueryHandler(ITenantContext tenantContext, IBrandRepository brands)
    {
        _tenantContext = tenantContext;
        _brands = brands;
    }

    public async Task<Result<IReadOnlyList<BrandDto>>> Handle(
        ListBrandsQuery request, CancellationToken cancellationToken)
    {
        var brands = await _brands.ListAsync(_tenantContext.TenantId, cancellationToken);
        return Result.Success<IReadOnlyList<BrandDto>>(brands.Select(CatalogMappers.ToBrandDto).ToArray());
    }
}
