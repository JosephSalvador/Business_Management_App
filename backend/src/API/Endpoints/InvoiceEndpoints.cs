using Asp.Versioning.Builder;
using BusinessOS.Api.Authorization;
using BusinessOS.Api.Http;
using BusinessOS.Application.Features.Invoicing.Commands;
using BusinessOS.Application.Features.Invoicing.Queries;
using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Invoicing;
using MediatR;

namespace BusinessOS.Api.Endpoints;

public static class InvoiceEndpoints
{
    public static IEndpointRouteBuilder MapInvoiceEndpoints(this IEndpointRouteBuilder app)
    {
        var api = app.MapGroup("/api/v{version:apiVersion}");
        var versionSet = api.NewApiVersionSet()
            .HasApiVersion(new Asp.Versioning.ApiVersion(1, 0))
            .ReportApiVersions()
            .Build();

        var invoices = api.MapGroup("/invoices")
            .WithApiVersionSet(versionSet)
            .WithTags("Invoices")
            .RequireAuthorization()
            .RequireRateLimiting("global");

        invoices.MapGet("/", ListInvoicesAsync)
            .RequirePermission(PermissionNames.InvoicesView)
            .WithName("ListCustomerInvoices");
        invoices.MapGet("/{invoiceId:guid}", GetInvoiceAsync)
            .RequirePermission(PermissionNames.InvoicesView)
            .WithName("GetCustomerInvoice");
        invoices.MapPost("/", CreateInvoiceAsync)
            .RequirePermission(PermissionNames.InvoicesCreate)
            .WithName("CreateCustomerInvoice");
        invoices.MapPost("/{invoiceId:guid}/payments", RecordPaymentAsync)
            .RequirePermission(PermissionNames.InvoicesManage)
            .WithName("RecordCustomerInvoicePayment");
        invoices.MapPost("/{invoiceId:guid}/void", VoidInvoiceAsync)
            .RequirePermission(PermissionNames.InvoicesManage)
            .WithName("VoidCustomerInvoice");

        return app;
    }

    private static async Task<IResult> ListInvoicesAsync(
        int? page, int? pageSize, CustomerInvoiceStatus? status, Guid? customerId, string? search,
        ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(
            new ListCustomerInvoicesQuery(
                page ?? 1, pageSize ?? 20, status, customerId, search),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> GetInvoiceAsync(
        Guid invoiceId, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(new GetCustomerInvoiceQuery(invoiceId), cancellationToken))
            .ToApiResult();

    private static async Task<IResult> CreateInvoiceAsync(
        CreateInvoiceRequest request, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(
            new CreateCustomerInvoiceCommand(
                request.Lines,
                request.CustomerId,
                request.Currency,
                request.IssueDate,
                request.DueDate,
                request.Notes,
                request.DocumentTitle,
                request.ReferenceNumber,
                request.PaymentTerms,
                request.CustomerName,
                request.CustomerAttention,
                request.CustomerPhone,
                request.CustomerEmail,
                request.CustomerAddress,
                request.CustomerTin,
                request.DiscountAmount,
                request.InitialAmountPaid,
                request.PaymentMethod,
                request.PaymentReference,
                request.PaymentInstructions,
                request.AuthorizedSignatoryName,
                request.AuthorizedSignatoryTitle,
                request.Id),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> RecordPaymentAsync(
        Guid invoiceId, RecordPaymentRequest request, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(
            new RecordCustomerInvoicePaymentCommand(
                invoiceId, request.Amount, request.Method, request.Reference),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> VoidInvoiceAsync(
        Guid invoiceId, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(new VoidCustomerInvoiceCommand(invoiceId), cancellationToken))
            .ToApiResult();

    private sealed record CreateInvoiceRequest(
        IReadOnlyList<CustomerInvoiceLineRequest> Lines,
        Guid? CustomerId = null,
        string Currency = "TZS",
        DateTime? IssueDate = null,
        DateTime? DueDate = null,
        string? Notes = null,
        string? DocumentTitle = null,
        string? ReferenceNumber = null,
        string? PaymentTerms = null,
        string? CustomerName = null,
        string? CustomerAttention = null,
        string? CustomerPhone = null,
        string? CustomerEmail = null,
        string? CustomerAddress = null,
        string? CustomerTin = null,
        decimal DiscountAmount = 0m,
        decimal InitialAmountPaid = 0m,
        string? PaymentMethod = null,
        string? PaymentReference = null,
        string? PaymentInstructions = null,
        string? AuthorizedSignatoryName = null,
        string? AuthorizedSignatoryTitle = null,
        Guid? Id = null);

    private sealed record RecordPaymentRequest(
        decimal Amount,
        string? Method = null,
        string? Reference = null);
}
