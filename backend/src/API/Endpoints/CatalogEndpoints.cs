using Asp.Versioning.Builder;
using BusinessOS.Api.Authorization;
using BusinessOS.Api.Http;
using BusinessOS.Application.Features.Products.Commands;
using BusinessOS.Application.Features.Products.Dtos;
using BusinessOS.Application.Features.Products.Queries;
using BusinessOS.Domain.Catalog;
using BusinessOS.Domain.Identity;
using MediatR;

namespace BusinessOS.Api.Endpoints;

public static class CatalogEndpoints
{
    public static IEndpointRouteBuilder MapCatalogEndpoints(this IEndpointRouteBuilder app)
    {
        var api = app.MapGroup("/api/v{version:apiVersion}");
        var versionSet = api.NewApiVersionSet()
            .HasApiVersion(new Asp.Versioning.ApiVersion(1, 0))
            .ReportApiVersions()
            .Build();

        var products = api.MapGroup("/products")
            .WithApiVersionSet(versionSet)
            .WithTags("Products")
            .RequireAuthorization()
            .RequireRateLimiting("global");
        products.MapGet("/", ListProductsAsync)
            .RequirePermission(PermissionNames.ProductsView)
            .WithName("ListProducts");
        products.MapGet("/{id:guid}", GetProductAsync)
            .RequirePermission(PermissionNames.ProductsView)
            .WithName("GetProduct");
        products.MapPost("/", CreateProductAsync)
            .RequirePermission(PermissionNames.ProductsCreate)
            .WithName("CreateProduct");
        products.MapPost("/quick-sale", EnsureQuickSaleProductAsync)
            .RequirePermission(PermissionNames.SalesCreate)
            .WithName("EnsureQuickSaleProduct");
        products.MapPut("/{id:guid}", UpdateProductAsync)
            .RequirePermission(PermissionNames.ProductsUpdate)
            .WithName("UpdateProduct");
        products.MapPatch("/{id:guid}/status", SetProductStatusAsync)
            .RequirePermission(PermissionNames.ProductsUpdate)
            .WithName("SetProductStatus");
        products.MapDelete("/{id:guid}", DeleteProductAsync)
            .RequirePermission(PermissionNames.ProductsDelete)
            .WithName("DeleteProduct");
        products.MapGet("/{id:guid}/variants", GetProductVariantsAsync)
            .RequirePermission(PermissionNames.ProductsView)
            .WithName("GetProductVariants");
        products.MapPut("/{id:guid}/variants", SetProductVariantsAsync)
            .RequirePermission(PermissionNames.ProductsUpdate)
            .WithName("SetProductVariants");

        return app;
    }

    private static async Task<IResult> ListProductsAsync(
        int page,
        int pageSize,
        string? search,
        Guid? categoryId,
        Guid? brandId,
        ProductType? type,
        ProductStatus? status,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new ListProductsQuery(page, pageSize, search, categoryId, brandId, type, status),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> GetProductAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetProductQuery(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> CreateProductAsync(
        CreateProductCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command, cancellationToken)).ToApiResult();

    private static async Task<IResult> EnsureQuickSaleProductAsync(
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new EnsureQuickSaleProductCommand(), cancellationToken)).ToApiResult();

    private static async Task<IResult> UpdateProductAsync(
        Guid id,
        UpdateProductCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command with { Id = id }, cancellationToken)).ToApiResult();

    private static async Task<IResult> SetProductStatusAsync(
        Guid id,
        SetProductStatusRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new SetProductStatusCommand(id, request.Status), cancellationToken)).ToApiResult();

    private static async Task<IResult> DeleteProductAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new DeleteProductCommand(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> GetProductVariantsAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetProductVariantsQuery(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> SetProductVariantsAsync(
        Guid id,
        SetProductVariantsRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new SetProductVariantsCommand(id, request.Variants),
            cancellationToken)).ToApiResult();

    private sealed record SetProductStatusRequest(ProductStatus Status);

    private sealed record SetProductVariantsRequest(IReadOnlyList<ProductVariantInputDto> Variants);
}
