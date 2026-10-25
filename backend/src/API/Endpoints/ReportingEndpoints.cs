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

        reports.MapGet("/sales-summary", GetSalesSummaryAsync)
            .RequirePermission(PermissionNames.SalesReportsView)
            .WithName("GetSalesSummary");
        reports.MapGet("/top-products", GetTopProductsAsync)
            .RequirePermission(PermissionNames.SalesReportsView)
            .WithName("GetTopProducts");
        reports.MapGet("/sales-trend", GetSalesTrendAsync)
            .RequirePermission(PermissionNames.SalesReportsView)
            .WithName("GetSalesTrend");

        reports.MapPost("/export/sales-summary", ExportSalesSummaryAsync)
            .RequirePermission(PermissionNames.SalesReportsExport)
            .WithName("ExportSalesSummary");
        reports.MapPost("/export/top-products", ExportTopProductsAsync)
            .RequirePermission(PermissionNames.SalesReportsExport)
            .WithName("ExportTopProducts");
        reports.MapGet("/business-overview", GetBusinessOverviewAsync)
            .RequirePermission(PermissionNames.SalesReportsView)
            .WithName("GetBusinessOverview");
        reports.MapGet("/money-movement", GetMoneyMovementAsync)
            .RequirePermission(PermissionNames.SalesReportsView)
            .WithName("GetMoneyMovement");
        reports.MapGet("/purchases-summary", GetPurchasesSummaryAsync)
            .RequirePermission(PermissionNames.PurchasingView)
            .WithName("GetPurchasesSummary");
        reports.MapGet("/sales-by-payment", GetSalesByPaymentMethodAsync)
            .RequirePermission(PermissionNames.SalesReportsView)
            .WithName("GetSalesByPaymentMethod");
        reports.MapGet("/sales-by-category", GetSalesByCategoryAsync)
            .RequirePermission(PermissionNames.SalesReportsView)
            .WithName("GetSalesByCategory");
        reports.MapGet("/sales-by-staff", GetSalesByStaffAsync)
            .RequirePermission(PermissionNames.SalesReportsView)
            .WithName("GetSalesByStaff");
        reports.MapGet("/sales-by-customer", GetSalesByCustomerAsync)
            .RequirePermission(PermissionNames.SalesReportsView)
            .WithName("GetSalesByCustomer");
        reports.MapGet("/stock-summary", GetStockSummaryAsync)
            .RequirePermission(PermissionNames.InventoryView)
            .WithName("GetStockSummary");
        reports.MapGet("/stock-movements", GetStockMovementSummaryAsync)
            .RequirePermission(PermissionNames.InventoryView)
            .WithName("GetStockMovementSummary");
        reports.MapGet("/low-stock", GetLowStockReportAsync)
            .RequirePermission(PermissionNames.InventoryView)
            .WithName("GetLowStockReport");
        reports.MapGet("/stock-velocity", GetStockVelocityAsync)
            .RequirePermission(PermissionNames.InventoryView)
            .WithName("GetStockVelocity");
        reports.MapGet("/expense-trend", GetExpenseTrendAsync)
            .RequirePermission(PermissionNames.ExpensesView)
            .WithName("GetExpenseTrend");
        reports.MapGet("/expense-by-payment", GetExpenseByPaymentMethodAsync)
            .RequirePermission(PermissionNames.ExpensesView)
            .WithName("GetExpenseByPaymentMethod");
        reports.MapGet("/purchases-by-supplier", GetPurchasesBySupplierAsync)
            .RequirePermission(PermissionNames.PurchasingView)
            .WithName("GetPurchasesBySupplier");
        reports.MapPost("/export/sales-by-payment", ExportSalesByPaymentMethodAsync)
            .RequirePermission(PermissionNames.SalesReportsExport)
            .WithName("ExportSalesByPaymentMethod");
        reports.MapPost("/export/stock-summary", ExportStockSummaryAsync)
            .RequirePermission(PermissionNames.SalesReportsExport)
            .WithName("ExportStockSummary");
        reports.MapPost("/export/expenses", ExportExpenseSummaryAsync)
            .RequirePermission(PermissionNames.SalesReportsExport)
            .WithName("ExportExpenseSummary");

        return app;
    }

    private static async Task<IResult> GetSalesSummaryAsync(
        DateTime? from, DateTime? to, Guid? branchId, ISender sender, CancellationToken cancellationToken)
    {
        var effectiveTo = to ?? DateTime.UtcNow;
        var effectiveFrom = from ?? effectiveTo.AddDays(-30);
        return (await sender.Send(new SalesSummaryQuery(effectiveFrom, effectiveTo, branchId), cancellationToken)).ToApiResult();
    }

    private static async Task<IResult> GetTopProductsAsync(
        DateTime? from, DateTime? to, int limit, Guid? branchId, ISender sender, CancellationToken cancellationToken)
    {
        var effectiveTo = to ?? DateTime.UtcNow;
        var effectiveFrom = from ?? effectiveTo.AddDays(-30);
        return (await sender.Send(new TopProductsQuery(effectiveFrom, effectiveTo, limit, branchId), cancellationToken)).ToApiResult();
    }

    private static async Task<IResult> GetSalesTrendAsync(
        int? days, Guid? branchId, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(new SalesTrendQuery(days ?? 30, branchId), cancellationToken)).ToApiResult();

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

    private static async Task<IResult> GetBusinessOverviewAsync(
        DateTime? from, DateTime? to, Guid? branchId, ISender sender, CancellationToken cancellationToken)
    {
        var effectiveTo = to ?? DateTime.UtcNow;
        var effectiveFrom = from ?? effectiveTo.AddDays(-30);
        return (await sender.Send(new BusinessOverviewQuery(effectiveFrom, effectiveTo, branchId), cancellationToken)).ToApiResult();
    }

    private static async Task<IResult> GetMoneyMovementAsync(
        DateTime? from, DateTime? to, ISender sender, CancellationToken cancellationToken)
    {
        var effectiveTo = to ?? DateTime.UtcNow;
        var effectiveFrom = from ?? effectiveTo.AddDays(-30);
        return (await sender.Send(new MoneyMovementQuery(effectiveFrom, effectiveTo), cancellationToken)).ToApiResult();
    }

    private static async Task<IResult> GetPurchasesSummaryAsync(
        DateTime? from, DateTime? to, ISender sender, CancellationToken cancellationToken)
    {
        var effectiveTo = to ?? DateTime.UtcNow;
        var effectiveFrom = from ?? effectiveTo.AddDays(-30);
        return (await sender.Send(new PurchasesSummaryQuery(effectiveFrom, effectiveTo), cancellationToken)).ToApiResult();
    }

    private static async Task<IResult> GetSalesByPaymentMethodAsync(
        DateTime? from, DateTime? to, Guid? branchId, ISender sender, CancellationToken cancellationToken)
    {
        var effectiveTo = to ?? DateTime.UtcNow;
        var effectiveFrom = from ?? effectiveTo.AddDays(-30);
        return (await sender.Send(new SalesByPaymentMethodQuery(effectiveFrom, effectiveTo, branchId), cancellationToken)).ToApiResult();
    }

    private static async Task<IResult> GetSalesByCategoryAsync(
        DateTime? from, DateTime? to, Guid? branchId, ISender sender, CancellationToken cancellationToken)
    {
        var effectiveTo = to ?? DateTime.UtcNow;
        var effectiveFrom = from ?? effectiveTo.AddDays(-30);
        return (await sender.Send(new SalesByCategoryQuery(effectiveFrom, effectiveTo, branchId), cancellationToken)).ToApiResult();
    }

    private static async Task<IResult> GetSalesByStaffAsync(
        DateTime? from, DateTime? to, Guid? branchId, ISender sender, CancellationToken cancellationToken)
    {
        var effectiveTo = to ?? DateTime.UtcNow;
        var effectiveFrom = from ?? effectiveTo.AddDays(-30);
        return (await sender.Send(new SalesByStaffQuery(effectiveFrom, effectiveTo, branchId), cancellationToken)).ToApiResult();
    }

    private static async Task<IResult> GetSalesByCustomerAsync(
        DateTime? from, DateTime? to, Guid? branchId, ISender sender, CancellationToken cancellationToken)
    {
        var effectiveTo = to ?? DateTime.UtcNow;
        var effectiveFrom = from ?? effectiveTo.AddDays(-30);
        return (await sender.Send(new SalesByCustomerQuery(effectiveFrom, effectiveTo, branchId), cancellationToken)).ToApiResult();
    }

    private static async Task<IResult> GetStockSummaryAsync(
        DateTime? from, DateTime? to, Guid? warehouseId, ISender sender, CancellationToken cancellationToken)
    {
        var effectiveTo = to ?? DateTime.UtcNow;
        var effectiveFrom = from ?? effectiveTo.AddDays(-30);
        return (await sender.Send(new StockSummaryQuery(effectiveFrom, effectiveTo, warehouseId), cancellationToken)).ToApiResult();
    }

    private static async Task<IResult> GetStockMovementSummaryAsync(
        DateTime? from, DateTime? to, Guid? warehouseId, ISender sender, CancellationToken cancellationToken)
    {
        var effectiveTo = to ?? DateTime.UtcNow;
        var effectiveFrom = from ?? effectiveTo.AddDays(-30);
        return (await sender.Send(new StockMovementSummaryQuery(effectiveFrom, effectiveTo, warehouseId), cancellationToken)).ToApiResult();
    }

    private static async Task<IResult> GetLowStockReportAsync(
        decimal? threshold, Guid? warehouseId, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(new LowStockReportQuery(threshold, warehouseId), cancellationToken)).ToApiResult();

    private static async Task<IResult> GetStockVelocityAsync(
        DateTime? from, DateTime? to, ISender sender, CancellationToken cancellationToken)
    {
        var effectiveTo = to ?? DateTime.UtcNow;
        var effectiveFrom = from ?? effectiveTo.AddDays(-30);
        return (await sender.Send(new StockVelocityQuery(effectiveFrom, effectiveTo), cancellationToken)).ToApiResult();
    }

    private static async Task<IResult> GetExpenseTrendAsync(
        DateTime? from, DateTime? to, ISender sender, CancellationToken cancellationToken)
    {
        var effectiveTo = to ?? DateTime.UtcNow;
        var effectiveFrom = from ?? effectiveTo.AddDays(-30);
        return (await sender.Send(new ExpenseTrendQuery(effectiveFrom, effectiveTo), cancellationToken)).ToApiResult();
    }

    private static async Task<IResult> GetExpenseByPaymentMethodAsync(
        DateTime? from, DateTime? to, ISender sender, CancellationToken cancellationToken)
    {
        var effectiveTo = to ?? DateTime.UtcNow;
        var effectiveFrom = from ?? effectiveTo.AddDays(-30);
        return (await sender.Send(new ExpenseByPaymentMethodQuery(effectiveFrom, effectiveTo), cancellationToken)).ToApiResult();
    }

    private static async Task<IResult> GetPurchasesBySupplierAsync(
        DateTime? from, DateTime? to, ISender sender, CancellationToken cancellationToken)
    {
        var effectiveTo = to ?? DateTime.UtcNow;
        var effectiveFrom = from ?? effectiveTo.AddDays(-30);
        return (await sender.Send(new PurchasesBySupplierQuery(effectiveFrom, effectiveTo), cancellationToken)).ToApiResult();
    }

    private static async Task<IResult> ExportSalesByPaymentMethodAsync(
        ExportSalesByPaymentMethodRequest request, ISender sender, CancellationToken cancellationToken)
    {
        var result = await sender.Send(
            new ExportSalesByPaymentMethodCommand(request.From, request.To, request.BranchId), cancellationToken);
        return result.IsSuccess
            ? Results.File(result.Value.FileBytes, result.Value.ContentType, result.Value.FileName)
            : result.ToApiResult();
    }

    private static async Task<IResult> ExportStockSummaryAsync(
        ExportStockSummaryRequest request, ISender sender, CancellationToken cancellationToken)
    {
        var result = await sender.Send(
            new ExportStockSummaryCommand(request.From, request.To, request.WarehouseId), cancellationToken);
        return result.IsSuccess
            ? Results.File(result.Value.FileBytes, result.Value.ContentType, result.Value.FileName)
            : result.ToApiResult();
    }

    private static async Task<IResult> ExportExpenseSummaryAsync(
        ExportExpenseSummaryRequest request, ISender sender, CancellationToken cancellationToken)
    {
        var result = await sender.Send(
            new ExportExpenseSummaryCommand(request.From, request.To), cancellationToken);
        return result.IsSuccess
            ? Results.File(result.Value.FileBytes, result.Value.ContentType, result.Value.FileName)
            : result.ToApiResult();
    }

    private sealed record ExportSalesSummaryRequest(DateTime From, DateTime To, Guid? BranchId);
    private sealed record ExportTopProductsRequest(DateTime From, DateTime To, int Limit, Guid? BranchId);
    private sealed record ExportSalesByPaymentMethodRequest(DateTime From, DateTime To, Guid? BranchId);
    private sealed record ExportStockSummaryRequest(DateTime From, DateTime To, Guid? WarehouseId);
    private sealed record ExportExpenseSummaryRequest(DateTime From, DateTime To);
}
