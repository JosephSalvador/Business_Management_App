using Asp.Versioning.Builder;
using BusinessOS.Api.Authorization;
using BusinessOS.Api.Http;
using BusinessOS.Application.Features.Dashboard.Queries;
using BusinessOS.Domain.Identity;
using MediatR;

namespace BusinessOS.Api.Endpoints;

public static class DashboardEndpoints
{
    public static IEndpointRouteBuilder MapDashboardEndpoints(this IEndpointRouteBuilder app)
    {
        var api = app.MapGroup("/api/v{version:apiVersion}");
        var versionSet = api.NewApiVersionSet()
            .HasApiVersion(new Asp.Versioning.ApiVersion(1, 0))
            .ReportApiVersions()
            .Build();

        var dashboard = api.MapGroup("/dashboard")
            .WithApiVersionSet(versionSet)
            .WithTags("Dashboard")
            .RequireAuthorization()
            .RequireRateLimiting("global");
        dashboard.MapGet("/summary", GetSummaryAsync)
            .RequirePermission(PermissionNames.DashboardView)
            .WithName("GetDashboardSummary");
        dashboard.MapGet("/low-stock", GetLowStockAsync)
            .RequirePermission(PermissionNames.DashboardView)
            .WithName("GetDashboardLowStock");
        dashboard.MapGet("/recent-activity", GetRecentActivityAsync)
            .RequirePermission(PermissionNames.DashboardView)
            .WithName("GetDashboardRecentActivity");

        return app;
    }

    private static async Task<IResult> GetSummaryAsync(
        ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(new GetDashboardSummaryQuery(), cancellationToken)).ToApiResult();

    private static async Task<IResult> GetLowStockAsync(
        ISender sender,
        decimal maxQuantity = 0,
        int limit = 20,
        CancellationToken cancellationToken = default)
        => (await sender.Send(
            new GetLowStockQuery(maxQuantity, limit),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> GetRecentActivityAsync(
        ISender sender,
        int limit = 20,
        CancellationToken cancellationToken = default)
        => (await sender.Send(
            new GetRecentActivityQuery(limit),
            cancellationToken)).ToApiResult();
}
