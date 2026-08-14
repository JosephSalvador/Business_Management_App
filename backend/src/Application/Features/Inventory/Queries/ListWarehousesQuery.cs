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
    private readonly IBranchRepository _branches;

    public ListWarehousesQueryHandler(
        ITenantContext tenantContext,
        IWarehouseRepository warehouses,
        IBranchRepository branches)
    {
        _tenantContext = tenantContext;
        _warehouses = warehouses;
        _branches = branches;
    }

    public async Task<Result<PagedResult<WarehouseDto>>> Handle(
        ListWarehousesQuery request, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var warehouses = await _warehouses.ListAsync(
            tenantId, request.Page, request.PageSize, request.Search, request.BranchId, cancellationToken);
        var total = await _warehouses.CountAsync(tenantId, request.Search, request.BranchId, cancellationToken);

        var branches = await _branches.ListByIdsAsync(
            tenantId, warehouses.Select(w => w.BranchId).Distinct(), cancellationToken);
        var branchNames = branches.ToDictionary(b => b.Id, b => b.Name);

        var items = warehouses
            .Select(w => WarehouseMappers.ToDto(
                w, branchNames.TryGetValue(w.BranchId, out var name) ? name : string.Empty))
            .ToList();
        return Result.Success(new PagedResult<WarehouseDto>(items, request.Page, request.PageSize, total));
    }
}
