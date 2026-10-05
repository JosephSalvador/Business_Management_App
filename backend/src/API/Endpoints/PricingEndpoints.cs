using Asp.Versioning.Builder;
using BusinessOS.Api.Authorization;
using BusinessOS.Api.Http;
using BusinessOS.Application.Features.Pricing.Commands;
using BusinessOS.Application.Features.Pricing.Dtos;
using BusinessOS.Application.Features.Pricing.Queries;
using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Pricing;
using MediatR;

namespace BusinessOS.Api.Endpoints;

public static class PricingEndpoints
{
    public static IEndpointRouteBuilder MapPricingEndpoints(this IEndpointRouteBuilder app)
    {
        var api = app.MapGroup("/api/v{version:apiVersion}");
        var versionSet = api.NewApiVersionSet()
            .HasApiVersion(new Asp.Versioning.ApiVersion(1, 0))
            .ReportApiVersions()
            .Build();

        var priceLists = api.MapGroup("/price-lists")
            .WithApiVersionSet(versionSet)
            .WithTags("Price Lists")
            .RequireAuthorization()
            .RequireRateLimiting("global");
        priceLists.MapGet("/", ListPriceListsAsync)
            .RequirePermission(PermissionNames.PricingView)
            .WithName("ListPriceLists");
        priceLists.MapPost("/", CreatePriceListAsync)
            .RequirePermission(PermissionNames.PricingManage)
            .WithName("CreatePriceList");
        priceLists.MapGet("/{id:guid}", GetPriceListAsync)
            .RequirePermission(PermissionNames.PricingView)
            .WithName("GetPriceList");
        priceLists.MapPut("/{id:guid}", UpdatePriceListAsync)
            .RequirePermission(PermissionNames.PricingManage)
            .WithName("UpdatePriceList");
        priceLists.MapGet("/{id:guid}/prices", GetPriceListPricesAsync)
            .RequirePermission(PermissionNames.PricingView)
            .WithName("GetPriceListPrices");
        priceLists.MapPut("/{id:guid}/prices", SetProductPricesAsync)
            .RequirePermission(PermissionNames.PricingManage)
            .WithName("SetProductPrices");

        var pricing = api.MapGroup("/pricing")
            .WithApiVersionSet(versionSet)
            .WithTags("Pricing")
            .RequireAuthorization()
            .RequireRateLimiting("global");
        pricing.MapGet("/resolve", ResolvePriceAsync)
            .RequirePermission(PermissionNames.PricingView)
            .WithName("ResolvePrice");
        pricing.MapPost("/resolve-many", ResolvePricesAsync)
            .RequirePermission(PermissionNames.PricingView)
            .WithName("ResolvePrices");

        return app;
    }

    private static async Task<IResult> ListPriceListsAsync(
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new ListPriceListsQuery(), cancellationToken)).ToApiResult();

    private static async Task<IResult> CreatePriceListAsync(
        CreatePriceListRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new CreatePriceListCommand(
                request.Name, request.Currency, request.IsDefault, request.EffectiveFrom, request.EffectiveTo),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> GetPriceListAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetPriceListQuery(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> UpdatePriceListAsync(
        Guid id,
        UpdatePriceListRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new UpdatePriceListCommand(
                id,
                request.Name,
                request.Currency,
                request.IsDefault,
                request.IsActive,
                request.EffectiveFrom,
                request.EffectiveTo),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> GetPriceListPricesAsync(
        Guid id,
        Guid? productId,
        Guid? branchId,
        PriceType? priceType,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new GetPriceListPricesQuery(id, productId, branchId, priceType),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> SetProductPricesAsync(
        Guid id,
        SetProductPricesRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new SetProductPricesCommand(id, request.Prices),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> ResolvePriceAsync(
        Guid productId,
        Guid? variantId,
        Guid? branchId,
        PriceType priceType,
        decimal? quantity,
        DateTime? onDate,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new ResolvePriceQuery(
                productId, variantId, branchId, priceType, quantity ?? 1m, onDate),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> ResolvePricesAsync(
        ResolvePricesRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new ResolvePricesQuery(request.Lines, request.BranchId, request.PriceType, request.OnDate),
            cancellationToken)).ToApiResult();

    private sealed record ResolvePricesRequest(
        IReadOnlyList<ResolvePriceLineDto> Lines,
        Guid? BranchId,
        PriceType PriceType,
        DateTime? OnDate);

    private sealed record CreatePriceListRequest(
        string Name,
        string Currency,
        bool IsDefault,
        DateTime? EffectiveFrom,
        DateTime? EffectiveTo);

    private sealed record UpdatePriceListRequest(
        string Name,
        string Currency,
        bool IsDefault,
        bool IsActive,
        DateTime? EffectiveFrom,
        DateTime? EffectiveTo);

    private sealed record SetProductPricesRequest(IReadOnlyList<ProductPriceInputDto> Prices);
}
