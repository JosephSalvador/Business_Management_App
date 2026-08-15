using BusinessOS.Application.Features.Dashboard.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Dashboard.Queries;

public sealed record GetDashboardSummaryQuery() : IRequest<Result<DashboardSummaryDto>>;

public sealed class GetDashboardSummaryQueryHandler
    : IRequestHandler<GetDashboardSummaryQuery, Result<DashboardSummaryDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IDashboardRepository _dashboard;

    public GetDashboardSummaryQueryHandler(ITenantContext tenantContext, IDashboardRepository dashboard)
    {
        _tenantContext = tenantContext;
        _dashboard = dashboard;
    }

    public async Task<Result<DashboardSummaryDto>> Handle(
        GetDashboardSummaryQuery request, CancellationToken cancellationToken)
    {
        var snapshot = await _dashboard.GetSummaryAsync(_tenantContext.TenantId, cancellationToken);
        return Result.Success(DashboardMappers.ToSummaryDto(snapshot));
    }
}
