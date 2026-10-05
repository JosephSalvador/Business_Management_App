using Asp.Versioning.Builder;
using BusinessOS.Api.Authorization;
using BusinessOS.Api.Http;
using BusinessOS.Application.Features.Crm.Commands;
using BusinessOS.Application.Features.Crm.Queries;
using BusinessOS.Domain.Identity;
using MediatR;

namespace BusinessOS.Api.Endpoints;

public static class CreditEndpoints
{
    public static IEndpointRouteBuilder MapCreditEndpoints(this IEndpointRouteBuilder app)
    {
        var api = app.MapGroup("/api/v{version:apiVersion}");
        var versionSet = api.NewApiVersionSet()
            .HasApiVersion(new Asp.Versioning.ApiVersion(1, 0))
            .ReportApiVersions()
            .Build();

        // ── Customer Credit ──────────────────────────────────────
        var credit = api.MapGroup("/customers/{customerId:guid}/credit")
            .WithApiVersionSet(versionSet)
            .WithTags("CustomerCredit")
            .RequireAuthorization()
            .RequireRateLimiting("global");

        credit.MapGet("/", GetCustomerCreditAsync)
            .RequirePermission(PermissionNames.CustomersView)
            .WithName("GetCustomerCredit");
        credit.MapPut("/limit", SetCreditLimitAsync)
            .RequirePermission(PermissionNames.CustomersUpdate)
            .WithName("SetCreditLimit");
        credit.MapPost("/sale", RecordCreditSaleAsync)
            .RequirePermission(PermissionNames.SalesCreate)
            .WithName("RecordCreditSale");
        credit.MapPost("/payment", RecordCreditPaymentAsync)
            .RequirePermission(PermissionNames.CustomersUpdate)
            .WithName("RecordCreditPayment");
        credit.MapGet("/transactions", ListCreditTransactionsAsync)
            .RequirePermission(PermissionNames.CustomersView)
            .WithName("ListCreditTransactions");

        // ── Outstanding Credit (all customers) ───────────────────
        var outstanding = api.MapGroup("/credit/outstanding")
            .WithApiVersionSet(versionSet)
            .WithTags("CustomerCredit")
            .RequireAuthorization()
            .RequireRateLimiting("global");

        outstanding.MapGet("/", ListOutstandingCreditAsync)
            .RequirePermission(PermissionNames.CustomersView)
            .WithName("ListOutstandingCredit");

        return app;
    }

    private static async Task<IResult> GetCustomerCreditAsync(
        Guid customerId, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(new GetCustomerCreditQuery(customerId), cancellationToken)).ToApiResult();

    private static async Task<IResult> SetCreditLimitAsync(
        Guid customerId, SetCreditLimitRequest request, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(new SetCreditLimitCommand(customerId, request.Limit), cancellationToken)).ToApiResult();

    private static async Task<IResult> RecordCreditSaleAsync(
        Guid customerId, RecordCreditSaleRequest request, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(
            new RecordCreditSaleCommand(customerId, request.Amount, request.Description, request.RelatedSaleId),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> RecordCreditPaymentAsync(
        Guid customerId, RecordCreditPaymentRequest request, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(
            new RecordCreditPaymentCommand(customerId, request.Amount, request.Description),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> ListCreditTransactionsAsync(
        Guid customerId, int? page, int? pageSize, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(
            new ListCreditTransactionsQuery(customerId, page ?? 1, pageSize ?? 20),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> ListOutstandingCreditAsync(
        ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(new ListOutstandingCreditQuery(), cancellationToken)).ToApiResult();

    private sealed record SetCreditLimitRequest(decimal Limit);
    private sealed record RecordCreditSaleRequest(decimal Amount, string Description, Guid? RelatedSaleId);
    private sealed record RecordCreditPaymentRequest(decimal Amount, string Description);
}
