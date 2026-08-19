using Asp.Versioning.Builder;
using BusinessOS.Api.Authorization;
using BusinessOS.Api.Http;
using BusinessOS.Application.Features.Reports.Queries;
using BusinessOS.Domain.Identity;
using MediatR;

namespace BusinessOS.Api.Endpoints;

public static class ReportingEndpoints
{
    public static IEndpointRouteBuilder MapReportingEndpoints(this IEndpointRouteBuilder app)
    {
        var api = app.MapGroup("/api/v{version:apiVersion}");
        var versionSet = api.NewApiVersionSet()
            .HasApiVersion(new Asp.Versioning.ApiVersion(1, 0))
            .ReportApiVersions()
            .Build();

        var reports = api.MapGroup("/reports")
            .WithApiVersionSet(versionSet)
            .WithTags("Reports")
            .RequireAuthorization()
            .RequireRateLimiting("global");

        reports.MapGet("/tax-summary", GetTaxSummaryAsync)
            .RequirePermission(PermissionNames.SalesReportsView)
            .WithName("GetTaxSummary");
        reports.MapGet("/sales-summary", GetSalesSummaryAsync)
            .RequirePermission(PermissionNames.SalesReportsView)
            .WithName("GetSalesSummary");
        reports.MapGet("/top-products", GetTopProductsAsync)
            .RequirePermission(PermissionNames.SalesReportsView)
            .WithName("GetTopProducts");
        reports.MapGet("/dashboard-tax-kpis", GetDashboardTaxKpisAsync)
            .RequirePermission(PermissionNames.SalesReportsView)
            .WithName("GetDashboardTaxKpis");

        reports.MapPost("/export/tax-summary", ExportTaxSummaryAsync)
            .RequirePermission(PermissionNames.SalesReportsExport)
            .WithName("ExportTaxSummary");
        reports.MapPost("/export/sales-summary", ExportSalesSummaryAsync)
            .RequirePermission(PermissionNames.SalesReportsExport)
            .WithName("ExportSalesSummary");
        reports.MapPost("/export/top-products", ExportTopProductsAsync)
            .RequirePermission(PermissionNames.SalesReportsExport)
            .WithName("ExportTopProducts");

        return app;
    }

    private static async Task<IResult> GetTaxSummaryAsync(
        DateTime from, DateTime to, Guid? branchId, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(new TaxSummaryQuery(from, to, branchId), cancellationToken)).ToApiResult();

    private static async Task<IResult> GetSalesSummaryAsync(
        DateTime from, DateTime to, Guid? branchId, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(new SalesSummaryQuery(from, to, branchId), cancellationToken)).ToApiResult();

    private static async Task<IResult> GetTopProductsAsync(
        DateTime from, DateTime to, [AsParameters] int limit, Guid? branchId, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(new TopProductsQuery(from, to, limit, branchId), cancellationToken)).ToApiResult();

    private static async Task<IResult> GetDashboardTaxKpisAsync(
        ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(new DashboardTaxKpisQuery(), cancellationToken)).ToApiResult();

    private static async Task<IResult> ExportTaxSummaryAsync(
        ExportTaxSummaryRequest request, ISender sender, CancellationToken cancellationToken)
    {
        var result = await sender.Send(
            new ExportTaxSummaryCommand(request.From, request.To, request.BranchId), cancellationToken);
        return result.IsSuccess
            ? Results.File(result.Value.FileBytes, result.Value.ContentType, result.Value.FileName)
            : result.ToApiResult();
    }

    private static async Task<IResult> ExportSalesSummaryAsync(
        ExportSalesSummaryRequest request, ISender sender, CancellationToken cancellationToken)
    {
        var result = await sender.Send(
            new ExportSalesSummaryCommand(request.From, request.To, request.BranchId), cancellationToken);
        return result.IsSuccess
            ? Results.File(result.Value.FileBytes, result.Value.ContentType, result.Value.FileName)
            : result.ToApiResult();
    }

    private static async Task<IResult> ExportTopProductsAsync(
        ExportTopProductsRequest request, ISender sender, CancellationToken cancellationToken)
    {
        var result = await sender.Send(
            new ExportTopProductsCommand(request.From, request.To, request.Limit, request.BranchId), cancellationToken);
        return result.IsSuccess
            ? Results.File(result.Value.FileBytes, result.Value.ContentType, result.Value.FileName)
            : result.ToApiResult();
    }

    private sealed record ExportTaxSummaryRequest(DateTime From, DateTime To, Guid? BranchId);
    private sealed record ExportSalesSummaryRequest(DateTime From, DateTime To, Guid? BranchId);
    private sealed record ExportTopProductsRequest(DateTime From, DateTime To, int Limit, Guid? BranchId);
}
