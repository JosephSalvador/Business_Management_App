using Asp.Versioning.Builder;
using BusinessOS.Api.Authorization;
using BusinessOS.Api.Http;
using BusinessOS.Application.Features.Billing.Commands;
using BusinessOS.Application.Features.Billing.Queries;
using BusinessOS.Domain.Identity;
using MediatR;

namespace BusinessOS.Api.Endpoints;

public static class BillingEndpoints
{
    public static IEndpointRouteBuilder MapBillingEndpoints(this IEndpointRouteBuilder app)
    {
        var api = app.MapGroup("/api/v{version:apiVersion}");
        var versionSet = api.NewApiVersionSet()
            .HasApiVersion(new Asp.Versioning.ApiVersion(1, 0))
            .ReportApiVersions()
            .Build();

        var billing = api.MapGroup("/billing")
            .WithApiVersionSet(versionSet)
            .WithTags("Billing")
            .RequireAuthorization()
            .RequireRateLimiting("global");

        billing.MapGet("/subscription", GetSubscriptionAsync)
            .WithName("GetSubscription");
        billing.MapPost("/subscription/evaluate", EvaluateSubscriptionAsync)
            .RequirePermission(PermissionNames.BillingView)
            .WithName("EvaluateSubscription");
        billing.MapGet("/plans", ListPlansAsync)
            .RequirePermission(PermissionNames.BillingView)
            .WithName("ListPlans");
        billing.MapPost("/vouchers/redeem", RedeemVoucherAsync)
            .RequirePermission(PermissionNames.BillingView)
            .WithName("RedeemVoucher");
        billing.MapGet("/invoices", ListInvoicesAsync)
            .RequirePermission(PermissionNames.BillingView)
            .WithName("ListInvoices");
        billing.MapGet("/invoices/{invoiceId:guid}", GetInvoiceAsync)
            .RequirePermission(PermissionNames.BillingView)
            .WithName("GetInvoice");
        billing.MapPost("/packages/{planCode}", ActivatePackageAsync)
            .RequirePermission(PermissionNames.BillingManage)
            .WithName("ActivatePackage");
        billing.MapDelete("/packages/{planCode}", RemovePackageAsync)
            .RequirePermission(PermissionNames.BillingManage)
            .WithName("RemovePackage");

        var admin = api.MapGroup("/admin/billing")
            .WithApiVersionSet(versionSet)
            .WithTags("BillingAdmin")
            .RequireAuthorization()
            .RequireRateLimiting("global");

        admin.MapGet("/debts", ListBillingDebtsAsync)
            .RequirePermission(PermissionNames.BillingManage)
            .WithName("ListBillingDebts");
        admin.MapPost("/invoices/{invoiceId:guid}/mark-paid", MarkInvoicePaidAsync)
            .RequirePermission(PermissionNames.BillingManage)
            .WithName("MarkInvoicePaid");
        admin.MapPost("/vouchers/issue", IssueVouchersAsync)
            .RequirePermission(PermissionNames.BillingManage)
            .WithName("IssueVouchers");

        return app;
    }

    private static async Task<IResult> GetSubscriptionAsync(
        ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(new GetSubscriptionQuery(), cancellationToken)).ToApiResult();

    private static async Task<IResult> EvaluateSubscriptionAsync(
        ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(new EvaluateSubscriptionCommand(), cancellationToken)).ToApiResult();

    private static async Task<IResult> ListPlansAsync(
        ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(new ListPlansQuery(), cancellationToken)).ToApiResult();

    private static async Task<IResult> RedeemVoucherAsync(
        RedeemVoucherRequest request, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(
            new RedeemVoucherCommand(request.Code), cancellationToken)).ToApiResult();

    private static async Task<IResult> ListInvoicesAsync(
        ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(new ListInvoicesQuery(), cancellationToken)).ToApiResult();

    private static async Task<IResult> GetInvoiceAsync(
        Guid invoiceId, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(
            new GetInvoiceQuery(invoiceId), cancellationToken)).ToApiResult();

    private static async Task<IResult> ActivatePackageAsync(
        string planCode, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(
            new ActivatePackageCommand(planCode), cancellationToken)).ToApiResult();

    private static async Task<IResult> RemovePackageAsync(
        string planCode, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(
            new RemovePackageCommand(planCode), cancellationToken)).ToApiResult();

    private static async Task<IResult> ListBillingDebtsAsync(
        ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(new ListBillingDebtsQuery(), cancellationToken)).ToApiResult();

    private static async Task<IResult> MarkInvoicePaidAsync(
        Guid invoiceId, MarkInvoicePaidRequest request, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(
            new MarkInvoicePaidCommand(invoiceId, request.Reference), cancellationToken)).ToApiResult();

    private static async Task<IResult> IssueVouchersAsync(
        IssueVouchersRequest request, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(
            new IssueVouchersCommand(request.Count, request.ValueDays, request.ExpiresAtUtc),
            cancellationToken)).ToApiResult();

    private sealed record RedeemVoucherRequest(string Code);

    private sealed record MarkInvoicePaidRequest(string Reference);

    private sealed record IssueVouchersRequest(int Count, int ValueDays, DateTime? ExpiresAtUtc);
}