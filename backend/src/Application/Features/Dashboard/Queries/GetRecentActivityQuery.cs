using BusinessOS.Application.Features.Dashboard.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Dashboard.Queries;

public sealed record GetRecentActivityQuery(int Limit = 20) : IRequest<Result<DashboardActivityDto>>;

public sealed class GetRecentActivityQueryHandler
    : IRequestHandler<GetRecentActivityQuery, Result<DashboardActivityDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IDashboardRepository _dashboard;

    public GetRecentActivityQueryHandler(ITenantContext tenantContext, IDashboardRepository dashboard)
    {
        _tenantContext = tenantContext;
        _dashboard = dashboard;
    }

    public async Task<Result<DashboardActivityDto>> Handle(
        GetRecentActivityQuery request, CancellationToken cancellationToken)
    {
        var items = await _dashboard.ListRecentActivityAsync(
            _tenantContext.TenantId, request.Limit, cancellationToken);
        return Result.Success(DashboardMappers.ToActivityDto(items));
    }
}
