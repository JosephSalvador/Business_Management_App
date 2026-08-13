using BusinessOS.Application.Features.Catalog.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Catalog;

public sealed record UpdateBrandCommand(Guid Id, string Name) : IRequest<Result<BrandDto>>;

public sealed class UpdateBrandCommandHandler : IRequestHandler<UpdateBrandCommand, Result<BrandDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IBrandRepository _brands;

    public UpdateBrandCommandHandler(ITenantContext tenantContext, IBrandRepository brands)
    {
        _tenantContext = tenantContext;
        _brands = brands;
    }

    public async Task<Result<BrandDto>> Handle(UpdateBrandCommand command, CancellationToken cancellationToken)
    {
        var brand = await _brands.GetByIdAsync(_tenantContext.TenantId, command.Id, cancellationToken);
        if (brand is null)
        {
            return Error.NotFound("Brand not found.");
        }

        brand.Rename(command.Name);
        return Result.Success(CatalogMappers.ToBrandDto(brand));
    }
}
