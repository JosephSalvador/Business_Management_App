using BusinessOS.Application.Features.Dashboard.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Dashboard.Queries;

public sealed record GetLowStockQuery(decimal MaxQuantity = 0, int Limit = 20)
    : IRequest<Result<DashboardLowStockDto>>;

public sealed class GetLowStockQueryHandler
    : IRequestHandler<GetLowStockQuery, Result<DashboardLowStockDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IDashboardRepository _dashboard;

    public GetLowStockQueryHandler(ITenantContext tenantContext, IDashboardRepository dashboard)
    {
        _tenantContext = tenantContext;
        _dashboard = dashboard;
    }

    public async Task<Result<DashboardLowStockDto>> Handle(
        GetLowStockQuery request, CancellationToken cancellationToken)
    {
        var items = await _dashboard.ListLowStockAsync(
            _tenantContext.TenantId, request.MaxQuantity, request.Limit, cancellationToken);
        return Result.Success(DashboardMappers.ToLowStockDto(items));
    }
}
