using Asp.Versioning.Builder;
using BusinessOS.Api.Authorization;
using BusinessOS.Api.Http;
using BusinessOS.Application.Features.Catalog;
using BusinessOS.Domain.Identity;
using MediatR;

namespace BusinessOS.Api.Endpoints;

public static class ReferenceDataEndpoints
{
    public static IEndpointRouteBuilder MapReferenceDataEndpoints(this IEndpointRouteBuilder app)
    {
        var api = app.MapGroup("/api/v{version:apiVersion}");
        var versionSet = api.NewApiVersionSet()
            .HasApiVersion(new Asp.Versioning.ApiVersion(1, 0))
            .ReportApiVersions()
            .Build();

        var categories = api.MapGroup("/categories")
            .WithApiVersionSet(versionSet)
            .WithTags("Categories")
            .RequireAuthorization()
            .RequireRateLimiting("global");
        categories.MapGet("/", ListCategoriesAsync)
            .RequirePermission(PermissionNames.CategoriesView)
            .WithName("ListCategories");
        categories.MapPost("/", CreateCategoryAsync)
            .RequirePermission(PermissionNames.CategoriesManage)
            .WithName("CreateCategory");
        categories.MapGet("/{id:guid}", GetCategoryAsync)
            .RequirePermission(PermissionNames.CategoriesView)
            .WithName("GetCategory");
        categories.MapPut("/{id:guid}", UpdateCategoryAsync)
            .RequirePermission(PermissionNames.CategoriesManage)
            .WithName("UpdateCategory");

        var brands = api.MapGroup("/brands")
            .WithApiVersionSet(versionSet)
            .WithTags("Brands")
            .RequireAuthorization()
            .RequireRateLimiting("global");
        brands.MapGet("/", ListBrandsAsync)
            .RequirePermission(PermissionNames.BrandsView)
            .WithName("ListBrands");
        brands.MapPost("/", CreateBrandAsync)
            .RequirePermission(PermissionNames.BrandsManage)
            .WithName("CreateBrand");
        brands.MapGet("/{id:guid}", GetBrandAsync)
            .RequirePermission(PermissionNames.BrandsView)
            .WithName("GetBrand");
        brands.MapPut("/{id:guid}", UpdateBrandAsync)
            .RequirePermission(PermissionNames.BrandsManage)
            .WithName("UpdateBrand");

        var units = api.MapGroup("/units")
            .WithApiVersionSet(versionSet)
            .WithTags("Units of Measure")
            .RequireAuthorization()
            .RequireRateLimiting("global");
        units.MapGet("/", ListUnitsAsync)
            .RequirePermission(PermissionNames.UnitsView)
            .WithName("ListUnits");
        units.MapPost("/", CreateUnitAsync)
            .RequirePermission(PermissionNames.UnitsManage)
            .WithName("CreateUnit");
        units.MapGet("/{id:guid}", GetUnitAsync)
            .RequirePermission(PermissionNames.UnitsView)
            .WithName("GetUnit");
        units.MapPut("/{id:guid}", UpdateUnitAsync)
            .RequirePermission(PermissionNames.UnitsManage)
            .WithName("UpdateUnit");

        var taxCategories = api.MapGroup("/tax-categories")
            .WithApiVersionSet(versionSet)
            .WithTags("Tax Categories")
            .RequireAuthorization()
            .RequireRateLimiting("global");
        taxCategories.MapGet("/", ListTaxCategoriesAsync)
            .RequirePermission(PermissionNames.ProductsView)
            .WithName("ListTaxCategories");

        return app;
    }

    private static async Task<IResult> ListCategoriesAsync(
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new ListCategoriesQuery(), cancellationToken)).ToApiResult();

    private static async Task<IResult> CreateCategoryAsync(
        CreateCategoryCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command, cancellationToken)).ToApiResult();

    private static async Task<IResult> GetCategoryAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetCategoryQuery(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> UpdateCategoryAsync(
        Guid id,
        UpdateCategoryCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command with { Id = id }, cancellationToken)).ToApiResult();

    private static async Task<IResult> ListBrandsAsync(
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new ListBrandsQuery(), cancellationToken)).ToApiResult();

    private static async Task<IResult> CreateBrandAsync(
        CreateBrandCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command, cancellationToken)).ToApiResult();

    private static async Task<IResult> GetBrandAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetBrandQuery(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> UpdateBrandAsync(
        Guid id,
        UpdateBrandCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command with { Id = id }, cancellationToken)).ToApiResult();

    private static async Task<IResult> ListUnitsAsync(
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new ListUnitsQuery(), cancellationToken)).ToApiResult();

    private static async Task<IResult> CreateUnitAsync(
        CreateUnitOfMeasureCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command, cancellationToken)).ToApiResult();

    private static async Task<IResult> GetUnitAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetUnitOfMeasureQuery(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> UpdateUnitAsync(
        Guid id,
        UpdateUnitOfMeasureCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command with { Id = id }, cancellationToken)).ToApiResult();

    private static async Task<IResult> ListTaxCategoriesAsync(
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new ListTaxCategoriesQuery(), cancellationToken)).ToApiResult();
}
