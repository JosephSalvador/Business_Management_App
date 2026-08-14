using BusinessOS.Application.Features.Inventory.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Inventory.Queries;

public sealed record GetWarehouseQuery(Guid Id) : IRequest<Result<WarehouseDto>>;

public sealed class GetWarehouseQueryHandler
    : IRequestHandler<GetWarehouseQuery, Result<WarehouseDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IWarehouseRepository _warehouses;

    public GetWarehouseQueryHandler(ITenantContext tenantContext, IWarehouseRepository warehouses)
    {
        _tenantContext = tenantContext;
        _warehouses = warehouses;
    }

    public async Task<Result<WarehouseDto>> Handle(
        GetWarehouseQuery request, CancellationToken cancellationToken)
    {
        var warehouse = await _warehouses.GetByIdAsync(
            _tenantContext.TenantId, request.Id, cancellationToken);
        if (warehouse is null)
        {
            return Error.NotFound("Warehouse not found.");
        }

        return Result.Success(WarehouseMappers.ToDto(warehouse));
    }
}
