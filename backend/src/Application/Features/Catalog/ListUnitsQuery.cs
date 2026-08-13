using BusinessOS.Application.Features.Catalog.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Catalog;

public sealed record ListUnitsQuery() : IRequest<Result<IReadOnlyList<UnitOfMeasureDto>>>;

public sealed class ListUnitsQueryHandler : IRequestHandler<ListUnitsQuery, Result<IReadOnlyList<UnitOfMeasureDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IUnitOfMeasureRepository _units;

    public ListUnitsQueryHandler(ITenantContext tenantContext, IUnitOfMeasureRepository units)
    {
        _tenantContext = tenantContext;
        _units = units;
    }

    public async Task<Result<IReadOnlyList<UnitOfMeasureDto>>> Handle(
        ListUnitsQuery request, CancellationToken cancellationToken)
    {
        var units = await _units.ListAsync(_tenantContext.TenantId, cancellationToken);
        return Result.Success<IReadOnlyList<UnitOfMeasureDto>>(units.Select(CatalogMappers.ToUnitDto).ToArray());
    }
}
