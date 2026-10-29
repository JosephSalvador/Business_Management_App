using Asp.Versioning.Builder;
using BusinessOS.Api.Authorization;
using BusinessOS.Api.Http;
using BusinessOS.Application.Features.Purchasing.Commands;
using BusinessOS.Application.Features.Purchasing.Queries;
using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Purchasing;
using MediatR;

namespace BusinessOS.Api.Endpoints;

public static class PurchasingEndpoints
{
    public static IEndpointRouteBuilder MapPurchasingEndpoints(this IEndpointRouteBuilder app)
    {
        var api = app.MapGroup("/api/v{version:apiVersion}");
        var versionSet = api.NewApiVersionSet()
            .HasApiVersion(new Asp.Versioning.ApiVersion(1, 0))
            .ReportApiVersions()
            .Build();

        // ── Suppliers ──────────────────────────────────────────────
        var suppliers = api.MapGroup("/suppliers")
            .WithApiVersionSet(versionSet)
            .WithTags("Suppliers")
            .RequireAuthorization()
            .RequireRateLimiting("global");

        suppliers.MapGet("/", ListSuppliersAsync)
            .RequirePermission(PermissionNames.PurchasingView)
            .WithName("ListSuppliers");
        suppliers.MapGet("/{id:guid}", GetSupplierAsync)
            .RequirePermission(PermissionNames.PurchasingView)
            .WithName("GetSupplier");
        suppliers.MapPost("/", CreateSupplierAsync)
            .RequirePermission(PermissionNames.PurchasingManage)
            .WithName("CreateSupplier");
        suppliers.MapPut("/{id:guid}", UpdateSupplierAsync)
            .RequirePermission(PermissionNames.PurchasingManage)
            .WithName("UpdateSupplier");

        // ── Purchase Orders ────────────────────────────────────────
        var purchaseOrders = api.MapGroup("/purchase-orders")
            .WithApiVersionSet(versionSet)
            .WithTags("PurchaseOrders")
            .RequireAuthorization()
            .RequireRateLimiting("global");

        purchaseOrders.MapGet("/", ListPurchaseOrdersAsync)
            .RequirePermission(PermissionNames.PurchasingView)
            .WithName("ListPurchaseOrders");
        purchaseOrders.MapGet("/{id:guid}", GetPurchaseOrderAsync)
            .RequirePermission(PermissionNames.PurchasingView)
            .WithName("GetPurchaseOrder");
        purchaseOrders.MapPost("/", CreatePurchaseOrderAsync)
            .RequirePermission(PermissionNames.PurchasingManage)
            .WithName("CreatePurchaseOrder");
        purchaseOrders.MapPost("/{id:guid}/submit", SubmitPurchaseOrderAsync)
            .RequirePermission(PermissionNames.PurchasingManage)
            .WithName("SubmitPurchaseOrder");
        purchaseOrders.MapPost("/{id:guid}/receive", ReceivePurchaseOrderAsync)
            .RequirePermission(PermissionNames.PurchasingManage)
            .WithName("ReceivePurchaseOrder");
        purchaseOrders.MapPost("/{id:guid}/cancel", CancelPurchaseOrderAsync)
            .RequirePermission(PermissionNames.PurchasingManage)
            .WithName("CancelPurchaseOrder");

        // ── Supplier Bills ─────────────────────────────────────────
        var supplierBills = api.MapGroup("/supplier-bills")
            .WithApiVersionSet(versionSet)
            .WithTags("SupplierBills")
            .RequireAuthorization()
            .RequireRateLimiting("global");

        supplierBills.MapGet("/", ListSupplierBillsAsync)
            .RequirePermission(PermissionNames.PurchasingView)
            .WithName("ListSupplierBills");
        supplierBills.MapGet("/{id:guid}", GetSupplierBillAsync)
            .RequirePermission(PermissionNames.PurchasingView)
            .WithName("GetSupplierBill");
        supplierBills.MapPost("/", CreateSupplierBillAsync)
            .RequirePermission(PermissionNames.PurchasingManage)
            .WithName("CreateSupplierBill");
        supplierBills.MapPost("/{id:guid}/approve", ApproveSupplierBillAsync)
            .RequirePermission(PermissionNames.PurchasingManage)
            .WithName("ApproveSupplierBill");
        supplierBills.MapPost("/{id:guid}/void", VoidSupplierBillAsync)
            .RequirePermission(PermissionNames.PurchasingManage)
            .WithName("VoidSupplierBill");
        supplierBills.MapPost("/{id:guid}/payments", CreateSupplierPaymentAsync)
            .RequirePermission(PermissionNames.PurchasingManage)
            .WithName("CreateSupplierPayment");

        return app;
    }

    // ── Supplier handlers ──────────────────────────────────────────
    private static async Task<IResult> ListSuppliersAsync(
        int page,
        int pageSize,
        string? search,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new ListSuppliersQuery(page, pageSize, search), cancellationToken)).ToApiResult();

    private static async Task<IResult> GetSupplierAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetSupplierQuery(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> CreateSupplierAsync(
        HttpContext context,
        CreateSupplierRequest request,
        ISender sender,
        CancellationToken cancellationToken)
    {
        var id = request.Id;
        if (!id.HasValue &&
            context.Request.Headers.TryGetValue("Idempotency-Key", out var rawKey) &&
            Guid.TryParse(rawKey.ToString(), out var idempotencyGuid))
        {
            id = idempotencyGuid;
        }

        return (await sender.Send(
            new CreateSupplierCommand(
                request.Name, request.ContactName, request.Email,
                request.Phone, request.Address, request.Tin, request.Notes, id),
            cancellationToken)).ToApiResult();
    }

    private static async Task<IResult> UpdateSupplierAsync(
        Guid id,
        UpdateSupplierRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new UpdateSupplierCommand(
                id, request.Name, request.ContactName, request.Email,
                request.Phone, request.Address, request.Tin, request.Notes, request.IsActive),
            cancellationToken)).ToApiResult();

    // ── Purchase Order handlers ────────────────────────────────────
    private static async Task<IResult> ListPurchaseOrdersAsync(
        int page,
        int pageSize,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new ListPurchaseOrdersQuery(page, pageSize), cancellationToken)).ToApiResult();

    private static async Task<IResult> GetPurchaseOrderAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetPurchaseOrderQuery(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> CreatePurchaseOrderAsync(
        HttpContext httpContext,
        CreatePurchaseOrderRequest request,
        ISender sender,
        CancellationToken cancellationToken)
    {
        Guid? resolvedId = request.Id;
        if (!resolvedId.HasValue &&
            httpContext.Request.Headers.TryGetValue("Idempotency-Key", out var ik) &&
            Guid.TryParse(ik.ToString(), out var parsedIk))
        {
            resolvedId = parsedIk;
        }

        return (await sender.Send(
            new CreatePurchaseOrderCommand(
                request.SupplierId,
                request.WarehouseId,
                request.BranchId,
                request.Reference,
                request.ExpectedDate,
                request.Notes,
                request.Lines,
                resolvedId),
            cancellationToken)).ToApiResult();
    }

    private static async Task<IResult> SubmitPurchaseOrderAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new SubmitPurchaseOrderCommand(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> ReceivePurchaseOrderAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new ReceivePurchaseOrderCommand(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> CancelPurchaseOrderAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new CancelPurchaseOrderCommand(id), cancellationToken)).ToApiResult();

    // ── Supplier Bill handlers ─────────────────────────────────────
    private static async Task<IResult> ListSupplierBillsAsync(
        int page,
        int pageSize,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new ListSupplierBillsQuery(page, pageSize), cancellationToken)).ToApiResult();

    private static async Task<IResult> GetSupplierBillAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetSupplierBillQuery(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> CreateSupplierBillAsync(
        CreateSupplierBillRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new CreateSupplierBillCommand(
                request.PurchaseOrderId, request.Subtotal, request.TaxAmount,
                request.BillNumber, request.BillDate, request.Notes),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> ApproveSupplierBillAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new ApproveSupplierBillCommand(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> VoidSupplierBillAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new VoidSupplierBillCommand(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> CreateSupplierPaymentAsync(
        Guid id,
        CreateSupplierPaymentRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new CreateSupplierPaymentCommand(
                id, request.Method, request.Amount,
                request.Provider, request.Reference, request.PhoneNumber),
            cancellationToken)).ToApiResult();

    // ── Request DTOs ───────────────────────────────────────────────
    private sealed record CreateSupplierRequest(
        string Name,
        string? ContactName,
        string? Email,
        string? Phone,
        string? Address,
        string? Tin,
        string? Notes,
        Guid? Id = null);

    private sealed record UpdateSupplierRequest(
        string Name,
        string? ContactName,
        string? Email,
        string? Phone,
        string? Address,
        string? Tin,
        string? Notes,
        bool IsActive);

    private sealed record CreatePurchaseOrderRequest(
        Guid SupplierId,
        Guid WarehouseId,
        Guid? BranchId,
        string? Reference,
        DateTime? ExpectedDate,
        string? Notes,
        IReadOnlyList<PurchaseOrderLineInput> Lines,
        Guid? Id = null);

    private sealed record CreateSupplierBillRequest(
        Guid PurchaseOrderId,
        decimal Subtotal,
        decimal TaxAmount,
        string? BillNumber,
        DateTime? BillDate,
        string? Notes);

    private sealed record CreateSupplierPaymentRequest(
        SupplierPaymentMethod Method,
        decimal Amount,
        string? Provider,
        string? Reference,
        string? PhoneNumber);
}
