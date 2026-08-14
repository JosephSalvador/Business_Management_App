using BusinessOS.Application.Features.Common;
using BusinessOS.Application.Features.Inventory.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Inventory.Queries;

public sealed record ListWarehousesQuery(int Page, int PageSize, string? Search, Guid? BranchId)
    : IRequest<Result<PagedResult<WarehouseDto>>>;

public sealed class ListWarehousesQueryHandler
    : IRequestHandler<ListWarehousesQuery, Result<PagedResult<WarehouseDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IWarehouseRepository _warehouses;

    public ListWarehousesQueryHandler(ITenantContext tenantContext, IWarehouseRepository warehouses)
    {
        _tenantContext = tenantContext;
        _warehouses = warehouses;
    }

    public async Task<Result<PagedResult<WarehouseDto>>> Handle(
        ListWarehousesQuery request, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var warehouses = await _warehouses.ListAsync(
            tenantId, request.Page, request.PageSize, request.Search, request.BranchId, cancellationToken);
        var total = await _warehouses.CountAsync(tenantId, request.Search, request.BranchId, cancellationToken);

        var items = warehouses.Select(WarehouseMappers.ToDto).ToList();
        return Result.Success(new PagedResult<WarehouseDto>(items, request.Page, request.PageSize, total));
    }
}
