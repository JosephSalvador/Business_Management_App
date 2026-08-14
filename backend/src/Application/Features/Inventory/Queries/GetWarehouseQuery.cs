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
    private readonly IBranchRepository _branches;

    public GetWarehouseQueryHandler(
        ITenantContext tenantContext,
        IWarehouseRepository warehouses,
        IBranchRepository branches)
    {
        _tenantContext = tenantContext;
        _warehouses = warehouses;
        _branches = branches;
    }

    public async Task<Result<WarehouseDto>> Handle(
        GetWarehouseQuery request, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var warehouse = await _warehouses.GetByIdAsync(tenantId, request.Id, cancellationToken);
        if (warehouse is null)
        {
            return Error.NotFound("Warehouse not found.");
        }

        var branch = await _branches.GetByIdAsync(tenantId, warehouse.BranchId, cancellationToken);
        return Result.Success(WarehouseMappers.ToDto(warehouse, branch?.Name ?? string.Empty));
    }
}
