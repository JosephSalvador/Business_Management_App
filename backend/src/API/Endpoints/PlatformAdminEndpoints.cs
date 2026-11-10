using Asp.Versioning.Builder;
using BusinessOS.Api.Authorization;
using BusinessOS.Api.Http;
using BusinessOS.Application.Features.Tenants;
using BusinessOS.Domain.Identity;
using MediatR;

namespace BusinessOS.Api.Endpoints;

public static class PlatformAdminEndpoints
{
    public static IEndpointRouteBuilder MapPlatformAdminEndpoints(this IEndpointRouteBuilder app)
    {
        var api = app.MapGroup("/api/v{version:apiVersion}");
        var versionSet = api.NewApiVersionSet()
            .HasApiVersion(new Asp.Versioning.ApiVersion(1, 0))
            .ReportApiVersions()
            .Build();

        var admin = api.MapGroup("/admin")
            .WithApiVersionSet(versionSet)
            .WithTags("PlatformAdmin")
            .RequireAuthorization()
            .RequireRateLimiting("global");

        // ── 1. Fleet & Statistics ─────────────────────────────────────
        admin.MapGet("/fleet/summary", GetFleetSummaryAsync)
            .RequirePlatformStaffOrSuperAdmin()
            .WithName("GetFleetSummary");

        admin.MapGet("/fleet/tenants", ListTenantsAsync)
            .RequirePlatformStaffOrSuperAdmin()
            .WithName("ListFleetTenants");

        admin.MapGet("/fleet/tenants/{tenantId:guid}", GetTenantDetailAsync)
            .RequirePlatformStaffOrSuperAdmin()
            .WithName("GetFleetTenantDetail");

        // ── 2. Omni-Tenant Workspace Control ─────────────────────────
        // Products & Stock
        admin.MapGet("/tenants/{tenantId:guid}/products", ListTenantProductsAsync)
            .RequirePlatformStaffOrSuperAdmin()
            .WithName("ListTenantProductsAdmin");

        admin.MapPut("/tenants/{tenantId:guid}/products/{productId:guid}", UpdateTenantProductAsync)
            .RequirePlatformStaffOrSuperAdmin()
            .WithName("UpdateTenantProductAdmin");

        admin.MapPost("/tenants/{tenantId:guid}/products/{productId:guid}/stock", AdjustTenantStockAsync)
            .RequirePlatformStaffOrSuperAdmin()
            .WithName("AdjustTenantStockAdmin");

        admin.MapPost("/tenants/{tenantId:guid}/seed-starter-catalog", SeedStarterCatalogAsync)
            .RequirePlatformStaffOrSuperAdmin()
            .WithName("SeedTenantStarterCatalogAdmin");

        // Sales & Cash Sessions
        admin.MapGet("/tenants/{tenantId:guid}/sales", ListTenantSalesAsync)
            .RequirePlatformStaffOrSuperAdmin()
            .WithName("ListTenantSalesAdmin");

        admin.MapGet("/tenants/{tenantId:guid}/sales/{saleId:guid}", GetTenantSaleDetailAsync)
            .RequirePlatformStaffOrSuperAdmin()
            .WithName("GetTenantSaleDetailAdmin");

        admin.MapPost("/tenants/{tenantId:guid}/sales/{saleId:guid}/void", VoidTenantSaleAsync)
            .RequirePlatformSuperAdmin()
            .WithName("VoidTenantSaleAdmin");

        admin.MapGet("/tenants/{tenantId:guid}/cash-sessions", ListTenantCashSessionsAsync)
            .RequirePlatformStaffOrSuperAdmin()
            .WithName("ListTenantCashSessionsAdmin");

        // Invoices
        admin.MapGet("/tenants/{tenantId:guid}/invoices", ListTenantInvoicesAsync)
            .RequirePlatformStaffOrSuperAdmin()
            .WithName("ListTenantInvoicesAdmin");

        admin.MapPut("/tenants/{tenantId:guid}/invoices/{invoiceId:guid}/status", UpdateTenantInvoiceStatusAsync)
            .RequirePlatformStaffOrSuperAdmin()
            .WithName("UpdateTenantInvoiceStatusAdmin");

        // Impersonation & Features
        admin.MapPost("/tenants/{tenantId:guid}/impersonate", ImpersonateTenantAsync)
            .RequirePlatformStaffOrSuperAdmin()
            .WithName("ImpersonateTenantAdmin");

        admin.MapPut("/tenants/{tenantId:guid}/features", UpdateTenantFeaturesAsync)
            .RequirePlatformStaffOrSuperAdmin()
            .WithName("UpdateTenantFeaturesAdmin");

        // ── 3. Platform Team Management ──────────────────────────────
        admin.MapGet("/platform-team", ListPlatformTeamAsync)
            .RequirePlatformSuperAdmin()
            .WithName("ListPlatformTeam");

        admin.MapPost("/platform-team", AssignPlatformRoleAsync)
            .RequirePlatformSuperAdmin()
            .WithName("AssignPlatformRole");

        admin.MapDelete("/platform-team/{id:guid}", RevokePlatformRoleAsync)
            .RequirePlatformSuperAdmin()
            .WithName("RevokePlatformRole");

        return app;
    }

    // Handlers
    private static async Task<IResult> GetFleetSummaryAsync(ISender sender, CancellationToken ct)
        => (await sender.Send(new GetFleetSummaryQuery(), ct)).ToApiResult();

    private static async Task<IResult> ListTenantsAsync(
        string? search, string? status, string? health, int page, int pageSize,
        ISender sender, CancellationToken ct)
        => (await sender.Send(new ListTenantsAdminQuery(search, status, health, page, pageSize), ct)).ToApiResult();

    private static async Task<IResult> GetTenantDetailAsync(Guid tenantId, ISender sender, CancellationToken ct)
        => (await sender.Send(new GetTenantDetailAdminQuery(tenantId), ct)).ToApiResult();

    private static async Task<IResult> ListTenantProductsAsync(
        Guid tenantId, string? search, int page, int pageSize, ISender sender, CancellationToken ct)
        => (await sender.Send(new ListTenantProductsAdminQuery(tenantId, search, page, pageSize), ct)).ToApiResult();

    private static async Task<IResult> UpdateTenantProductAsync(
        Guid tenantId, Guid productId, UpdateTenantProductRequest request, ISender sender, CancellationToken ct)
        => (await sender.Send(new UpdateTenantProductAdminCommand(
            tenantId, productId, request.Name, request.SellingPrice, request.CostPrice, request.Barcode), ct)).ToApiResult();

    private static async Task<IResult> AdjustTenantStockAsync(
        Guid tenantId, Guid productId, AdjustStockRequest request, ISender sender, CancellationToken ct)
        => (await sender.Send(new AdjustTenantStockAdminCommand(
            tenantId, productId, request.WarehouseId, request.NewQuantity, request.Reason), ct)).ToApiResult();

    private static async Task<IResult> SeedStarterCatalogAsync(
        Guid tenantId, SeedStarterCatalogRequest request, ISender sender, CancellationToken ct)
        => (await sender.Send(new SeedTenantStarterCatalogCommand(tenantId, request.TemplateType), ct)).ToApiResult();

    private static async Task<IResult> ListTenantSalesAsync(
        Guid tenantId, DateTime? from, DateTime? to, int page, int pageSize, ISender sender, CancellationToken ct)
        => (await sender.Send(new ListTenantSalesAdminQuery(tenantId, from, to, page, pageSize), ct)).ToApiResult();

    private static async Task<IResult> GetTenantSaleDetailAsync(
        Guid tenantId, Guid saleId, ISender sender, CancellationToken ct)
        => (await sender.Send(new GetTenantSaleDetailAdminQuery(tenantId, saleId), ct)).ToApiResult();

    private static async Task<IResult> VoidTenantSaleAsync(
        Guid tenantId, Guid saleId, VoidSaleRequest request, ISender sender, CancellationToken ct)
        => (await sender.Send(new VoidTenantSaleAdminCommand(tenantId, saleId, request.Reason), ct)).ToApiResult();

    private static async Task<IResult> ListTenantCashSessionsAsync(
        Guid tenantId, int page, int pageSize, ISender sender, CancellationToken ct)
        => (await sender.Send(new ListTenantCashSessionsAdminQuery(tenantId, page, pageSize), ct)).ToApiResult();

    private static async Task<IResult> ListTenantInvoicesAsync(
        Guid tenantId, string? status, int page, int pageSize, ISender sender, CancellationToken ct)
        => (await sender.Send(new ListTenantInvoicesAdminQuery(tenantId, status, page, pageSize), ct)).ToApiResult();

    private static async Task<IResult> UpdateTenantInvoiceStatusAsync(
        Guid tenantId, Guid invoiceId, UpdateInvoiceStatusRequest request, ISender sender, CancellationToken ct)
        => (await sender.Send(new UpdateTenantInvoiceStatusAdminCommand(tenantId, invoiceId, request.NewStatus), ct)).ToApiResult();

    private static async Task<IResult> ImpersonateTenantAsync(
        Guid tenantId, ISender sender, CancellationToken ct)
        => (await sender.Send(new ImpersonateTenantCommand(tenantId), ct)).ToApiResult();

    private static async Task<IResult> UpdateTenantFeaturesAsync(
        Guid tenantId, UpdateFeaturesRequest request, ISender sender, CancellationToken ct)
        => (await sender.Send(new UpdateTenantFeaturesAdminCommand(tenantId, request.Features), ct)).ToApiResult();

    private static async Task<IResult> ListPlatformTeamAsync(ISender sender, CancellationToken ct)
        => (await sender.Send(new ListPlatformOperatorsQuery(), ct)).ToApiResult();

    private static async Task<IResult> AssignPlatformRoleAsync(
        AssignPlatformRoleRequest request, ISender sender, CancellationToken ct)
        => (await sender.Send(new AssignPlatformRoleCommand(request.Email, request.Role), ct)).ToApiResult();

    private static async Task<IResult> RevokePlatformRoleAsync(
        Guid id, ISender sender, CancellationToken ct)
        => (await sender.Send(new RevokePlatformRoleCommand(id), ct)).ToApiResult();

    // Request records
    private sealed record UpdateTenantProductRequest(string Name, decimal SellingPrice, decimal? CostPrice, string? Barcode);
    private sealed record AdjustStockRequest(Guid? WarehouseId, decimal NewQuantity, string Reason);
    private sealed record SeedStarterCatalogRequest(string TemplateType);
    private sealed record VoidSaleRequest(string Reason);
    private sealed record UpdateInvoiceStatusRequest(string NewStatus);
    private sealed record UpdateFeaturesRequest(string[] Features);
    private sealed record AssignPlatformRoleRequest(string Email, PlatformRoleType Role);
}
