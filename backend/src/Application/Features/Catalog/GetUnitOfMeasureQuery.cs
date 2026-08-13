using BusinessOS.Application.Features.Catalog.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Catalog;

public sealed record GetUnitOfMeasureQuery(Guid Id) : IRequest<Result<UnitOfMeasureDto>>;

public sealed class GetUnitOfMeasureQueryHandler : IRequestHandler<GetUnitOfMeasureQuery, Result<UnitOfMeasureDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IUnitOfMeasureRepository _units;

    public GetUnitOfMeasureQueryHandler(ITenantContext tenantContext, IUnitOfMeasureRepository units)
    {
        _tenantContext = tenantContext;
        _units = units;
    }

    public async Task<Result<UnitOfMeasureDto>> Handle(
        GetUnitOfMeasureQuery request, CancellationToken cancellationToken)
    {
        var unit = await _units.GetByIdAsync(_tenantContext.TenantId, request.Id, cancellationToken);
        if (unit is null)
        {
            return Error.NotFound("Unit of measure not found.");
        }

        return Result.Success(CatalogMappers.ToUnitDto(unit));
    }
}
