using Asp.Versioning.Builder;
using BusinessOS.Api.Authorization;
using BusinessOS.Api.Http;
using BusinessOS.Application.Features.Sales.Commands;
using BusinessOS.Application.Features.Sales.Dtos;
using BusinessOS.Application.Features.Sales.Queries;
using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Sales;
using MediatR;

namespace BusinessOS.Api.Endpoints;

public static class SalesEndpoints
{
    public static IEndpointRouteBuilder MapSalesEndpoints(this IEndpointRouteBuilder app)
    {
        var api = app.MapGroup("/api/v{version:apiVersion}");
        var versionSet = api.NewApiVersionSet()
            .HasApiVersion(new Asp.Versioning.ApiVersion(1, 0))
            .ReportApiVersions()
            .Build();

        var sales = api.MapGroup("/sales")
            .WithApiVersionSet(versionSet)
            .WithTags("Sales")
            .RequireAuthorization()
            .RequireRateLimiting("global");
        sales.MapPost("/", CreateSaleAsync)
            .RequirePermission(PermissionNames.SalesCreate)
            .WithName("CreateSale");
        sales.MapGet("/{id:guid}", GetSaleAsync)
            .RequirePermission(PermissionNames.SalesView)
            .WithName("GetSale");
        sales.MapGet("/", ListSalesAsync)
            .RequirePermission(PermissionNames.SalesView)
            .WithName("ListSales");
        sales.MapPost("/{id:guid}/void", VoidSaleAsync)
            .RequirePermission(PermissionNames.SalesDelete)
            .WithName("VoidSale");

        return app;
    }

    private static async Task<IResult> CreateSaleAsync(
        CreateSaleRequest request,
        HttpRequest httpRequest,
        ISender sender,
        CancellationToken cancellationToken)
    {
        var idempotencyKey = httpRequest.Headers.TryGetValue("Idempotency-Key", out var value)
            ? value.ToString()
            : null;
        var clientSaleId = Guid.TryParse(idempotencyKey, out var keyId)
            ? keyId
            : request.ClientSaleId;

        var command = new CreateSaleCommand(
            request.BranchId,
            request.WarehouseId,
            request.PriceListId,
            clientSaleId,
            request.Source,
            request.EffectiveAt,
            request.IsElectronicPayment,
            request.IsVatRegistered,
            request.Customer?.Name,
            request.Customer?.Phone,
            request.Customer?.Tin,
            request.Lines,
            request.Payments);

        return (await sender.Send(command, cancellationToken)).ToApiResult();
    }

    private static async Task<IResult> GetSaleAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetSaleQuery(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> ListSalesAsync(
        int page,
        int pageSize,
        Guid? branchId,
        DateTime? from,
        DateTime? to,
        SaleStatus? status,
        string? search,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new ListSalesQuery(page, pageSize, branchId, from, to, status, search),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> VoidSaleAsync(
        Guid id,
        VoidSaleRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new VoidSaleCommand(id, request.Reason),
            cancellationToken)).ToApiResult();

    private sealed record CreateSaleRequest(
        Guid BranchId,
        Guid? WarehouseId,
        Guid? PriceListId,
        Guid ClientSaleId,
        SaleSource Source,
        DateTime EffectiveAt,
        bool IsElectronicPayment,
        bool? IsVatRegistered,
        CreateSaleCustomerRequest? Customer,
        IReadOnlyList<CreateSaleLineInput> Lines,
        IReadOnlyList<CreateSalePaymentInput> Payments);

    private sealed record CreateSaleCustomerRequest(
        string? Name,
        string? Phone,
        string? Tin);
}
