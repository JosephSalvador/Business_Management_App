using BusinessOS.Application.Features.Common;
using BusinessOS.Application.Features.Sales.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Sales;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Sales.Queries;

public sealed record ListSalesQuery(
    int Page,
    int PageSize,
    Guid? BranchId,
    DateTime? FromDate,
    DateTime? ToDate,
    SaleStatus? Status,
    string? Search) : IRequest<Result<PagedResult<SaleDto>>>;

public sealed class ListSalesQueryHandler
    : IRequestHandler<ListSalesQuery, Result<PagedResult<SaleDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ISaleRepository _sales;

    public ListSalesQueryHandler(ITenantContext tenantContext, ISaleRepository sales)
    {
        _tenantContext = tenantContext;
        _sales = sales;
    }

    public async Task<Result<PagedResult<SaleDto>>> Handle(
        ListSalesQuery request, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var filter = new SaleListFilter(
            request.BranchId, request.FromDate, request.ToDate, request.Status, request.Search);

        var sales = await _sales.ListAsync(tenantId, request.Page, request.PageSize, filter, cancellationToken);
        var total = await _sales.CountAsync(tenantId, filter, cancellationToken);

        var items = sales.Select(SalesMappers.ToDto).ToList();
        return Result.Success(new PagedResult<SaleDto>(items, request.Page, request.PageSize, total));
    }
}
