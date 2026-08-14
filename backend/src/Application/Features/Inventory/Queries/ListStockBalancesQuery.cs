using BusinessOS.Application.Features.Common;
using BusinessOS.Application.Features.Inventory.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Inventory.Queries;

public sealed record ListStockBalancesQuery(
    int Page,
    int PageSize,
    Guid? WarehouseId = null,
    Guid? ProductId = null,
    string? Search = null) : IRequest<Result<PagedResult<StockBalanceDto>>>;

public sealed class ListStockBalancesQueryHandler
    : IRequestHandler<ListStockBalancesQuery, Result<PagedResult<StockBalanceDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IStockRepository _stock;

    public ListStockBalancesQueryHandler(ITenantContext tenantContext, IStockRepository stock)
    {
        _tenantContext = tenantContext;
        _stock = stock;
    }

    public async Task<Result<PagedResult<StockBalanceDto>>> Handle(
        ListStockBalancesQuery request, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var balances = await _stock.ListBalancesAsync(
            tenantId, request.Page, request.PageSize, request.WarehouseId, request.ProductId, request.Search,
            cancellationToken);
        var total = await _stock.CountBalancesAsync(
            tenantId, request.WarehouseId, request.ProductId, request.Search, cancellationToken);

        var items = balances.Select(WarehouseMappers.ToBalanceDto).ToList();
        return Result.Success(new PagedResult<StockBalanceDto>(items, request.Page, request.PageSize, total));
    }
}
