using Asp.Versioning.Builder;
using BusinessOS.Api.Authorization;
using BusinessOS.Api.Http;
using BusinessOS.Application.Features.Crm.Commands;
using BusinessOS.Application.Features.Crm.Queries;
using BusinessOS.Domain.Identity;
using MediatR;

namespace BusinessOS.Api.Endpoints;

public static class CustomerEndpoints
{
    public static IEndpointRouteBuilder MapCustomerEndpoints(this IEndpointRouteBuilder app)
    {
        var api = app.MapGroup("/api/v{version:apiVersion}");
        var versionSet = api.NewApiVersionSet()
            .HasApiVersion(new Asp.Versioning.ApiVersion(1, 0))
            .ReportApiVersions()
            .Build();

        var customers = api.MapGroup("/customers")
            .WithApiVersionSet(versionSet)
            .WithTags("Customers")
            .RequireAuthorization()
            .RequireRateLimiting("global");

        customers.MapGet("/", ListCustomersAsync)
            .RequirePermission(PermissionNames.CustomersView)
            .WithName("ListCustomers");
        customers.MapGet("/{id:guid}", GetCustomerAsync)
            .RequirePermission(PermissionNames.CustomersView)
            .WithName("GetCustomer");
        customers.MapPost("/", CreateCustomerAsync)
            .RequirePermission(PermissionNames.CustomersCreate)
            .WithName("CreateCustomer");
        customers.MapPut("/{id:guid}", UpdateCustomerAsync)
            .RequirePermission(PermissionNames.CustomersUpdate)
            .WithName("UpdateCustomer");

        return app;
    }

    private static async Task<IResult> ListCustomersAsync(
        int? page,
        int? pageSize,
        string? search,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new ListCustomersQuery(page ?? 1, pageSize ?? 20, search),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> GetCustomerAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetCustomerQuery(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> CreateCustomerAsync(
        CreateCustomerRequest request,
        HttpRequest httpRequest,
        ISender sender,
        CancellationToken cancellationToken)
    {
        var idempotencyKey = httpRequest.Headers.TryGetValue("Idempotency-Key", out var value)
            ? value.ToString()
            : null;
        var customerId = Guid.TryParse(idempotencyKey, out var keyId)
            ? keyId
            : request.Id;

        return (await sender.Send(
            new CreateCustomerCommand(
                request.Name, request.ContactName, request.Email, request.Phone,
                request.Address, request.Tin, request.IsVatRegistered, request.Notes,
                customerId),
            cancellationToken)).ToApiResult();
    }

    private static async Task<IResult> UpdateCustomerAsync(
        Guid id,
        UpdateCustomerRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new UpdateCustomerCommand(
                id, request.Name, request.ContactName, request.Email, request.Phone,
                request.Address, request.Tin, request.IsVatRegistered, request.Notes),
            cancellationToken)).ToApiResult();

    private sealed record CreateCustomerRequest(
        string Name, string? ContactName, string? Email, string? Phone,
        string? Address, string? Tin, bool IsVatRegistered, string? Notes,
        Guid? Id = null);

    private sealed record UpdateCustomerRequest(
        string? Name, string? ContactName, string? Email, string? Phone,
        string? Address, string? Tin, bool? IsVatRegistered, string? Notes);
}
