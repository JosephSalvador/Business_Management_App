using BusinessOS.Application.Features.Common;
using BusinessOS.Application.Features.Inventory.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Inventory;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Inventory.Queries;

public sealed record ListStockMovementsQuery(
    int Page,
    int PageSize,
    Guid? WarehouseId = null,
    Guid? ProductId = null,
    StockMovementType? Type = null) : IRequest<Result<PagedResult<StockMovementDto>>>;

public sealed class ListStockMovementsQueryHandler
    : IRequestHandler<ListStockMovementsQuery, Result<PagedResult<StockMovementDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IStockRepository _stock;

    public ListStockMovementsQueryHandler(ITenantContext tenantContext, IStockRepository stock)
    {
        _tenantContext = tenantContext;
        _stock = stock;
    }

    public async Task<Result<PagedResult<StockMovementDto>>> Handle(
        ListStockMovementsQuery request, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var movements = await _stock.ListMovementsAsync(
            tenantId, request.Page, request.PageSize, request.WarehouseId, request.ProductId, request.Type,
            cancellationToken);
        var total = await _stock.CountMovementsAsync(
            tenantId, request.WarehouseId, request.ProductId, request.Type, cancellationToken);

        var items = movements.Select(WarehouseMappers.ToMovementDto).ToList();
        return Result.Success(new PagedResult<StockMovementDto>(items, request.Page, request.PageSize, total));
    }
}
