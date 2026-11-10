using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Tenants;

public sealed record GetFleetSummaryQuery : IRequest<Result<FleetSummaryDto>>;

public sealed class GetFleetSummaryQueryHandler : IRequestHandler<GetFleetSummaryQuery, Result<FleetSummaryDto>>
{
    private readonly IFleetAdminRepository _fleet;

    public GetFleetSummaryQueryHandler(IFleetAdminRepository fleet) => _fleet = fleet;

    public async Task<Result<FleetSummaryDto>> Handle(GetFleetSummaryQuery request, CancellationToken cancellationToken)
    {
        var summary = await _fleet.GetFleetSummaryAsync(cancellationToken);
        return Result.Success(summary);
    }
}

public sealed record ListTenantsAdminQuery(
    string? Search = null,
    string? Status = null,
    string? Health = null,
    int Page = 1,
    int PageSize = 20) : IRequest<Result<PagedResult<TenantAdminSummaryDto>>>;

public sealed class ListTenantsAdminQueryHandler : IRequestHandler<ListTenantsAdminQuery, Result<PagedResult<TenantAdminSummaryDto>>>
{
    private readonly IFleetAdminRepository _fleet;

    public ListTenantsAdminQueryHandler(IFleetAdminRepository fleet) => _fleet = fleet;

    public async Task<Result<PagedResult<TenantAdminSummaryDto>>> Handle(
        ListTenantsAdminQuery request, CancellationToken cancellationToken)
    {
        var result = await _fleet.ListTenantsAsync(
            request.Search, request.Status, request.Health, request.Page, request.PageSize, cancellationToken);
        return Result.Success(result);
    }
}

public sealed record GetTenantDetailAdminQuery(Guid TenantId) : IRequest<Result<TenantAdminDetailDto>>;

public sealed class GetTenantDetailAdminQueryHandler : IRequestHandler<GetTenantDetailAdminQuery, Result<TenantAdminDetailDto>>
{
    private readonly IFleetAdminRepository _fleet;

    public GetTenantDetailAdminQueryHandler(IFleetAdminRepository fleet) => _fleet = fleet;

    public async Task<Result<TenantAdminDetailDto>> Handle(
        GetTenantDetailAdminQuery request, CancellationToken cancellationToken)
    {
        var detail = await _fleet.GetTenantDetailAsync(request.TenantId, cancellationToken);
        if (detail is null)
        {
            return Error.NotFound($"Tenant {request.TenantId} was not found.");
        }

        return Result.Success(detail);
    }
}
