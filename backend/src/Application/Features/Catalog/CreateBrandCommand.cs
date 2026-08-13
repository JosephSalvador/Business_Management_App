using BusinessOS.Application.Features.Catalog.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Catalog;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Catalog;

public sealed record CreateBrandCommand(string Name) : IRequest<Result<BrandDto>>;

public sealed class CreateBrandCommandHandler : IRequestHandler<CreateBrandCommand, Result<BrandDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IBrandRepository _brands;

    public CreateBrandCommandHandler(ITenantContext tenantContext, IBrandRepository brands)
    {
        _tenantContext = tenantContext;
        _brands = brands;
    }

    public async Task<Result<BrandDto>> Handle(CreateBrandCommand command, CancellationToken cancellationToken)
    {
        var brand = Brand.Create(_tenantContext.TenantId, command.Name);
        await _brands.AddAsync(brand, cancellationToken);

        return Result.Success(CatalogMappers.ToBrandDto(brand));
    }
}
