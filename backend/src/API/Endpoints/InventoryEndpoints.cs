using Asp.Versioning.Builder;
using BusinessOS.Api.Authorization;
using BusinessOS.Api.Http;
using BusinessOS.Application.Features.Inventory.Commands;
using BusinessOS.Application.Features.Inventory.Dtos;
using BusinessOS.Application.Features.Inventory.Queries;
using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Inventory;
using MediatR;

namespace BusinessOS.Api.Endpoints;

public static class InventoryEndpoints
{
    public static IEndpointRouteBuilder MapInventoryEndpoints(this IEndpointRouteBuilder app)
    {
        var api = app.MapGroup("/api/v{version:apiVersion}");
        var versionSet = api.NewApiVersionSet()
            .HasApiVersion(new Asp.Versioning.ApiVersion(1, 0))
            .ReportApiVersions()
            .Build();

        var warehouses = api.MapGroup("/warehouses")
            .WithApiVersionSet(versionSet)
            .WithTags("Warehouses")
            .RequireAuthorization()
            .RequireRateLimiting("global");
        warehouses.MapGet("/", ListWarehousesAsync)
            .RequirePermission(PermissionNames.WarehousesView)
            .WithName("ListWarehouses");
        warehouses.MapGet("/{id:guid}", GetWarehouseAsync)
            .RequirePermission(PermissionNames.WarehousesView)
            .WithName("GetWarehouse");
        warehouses.MapPost("/", CreateWarehouseAsync)
            .RequirePermission(PermissionNames.WarehousesCreate)
            .WithName("CreateWarehouse");
        warehouses.MapPut("/{id:guid}", UpdateWarehouseAsync)
            .RequirePermission(PermissionNames.WarehousesUpdate)
            .WithName("UpdateWarehouse");
        warehouses.MapPatch("/{id:guid}/status", SetWarehouseStatusAsync)
            .RequirePermission(PermissionNames.WarehousesUpdate)
            .WithName("SetWarehouseStatus");
        warehouses.MapDelete("/{id:guid}", DeleteWarehouseAsync)
            .RequirePermission(PermissionNames.WarehousesDelete)
            .WithName("DeleteWarehouse");
        warehouses.MapPut("/{id:guid}/locations", SetStockLocationsAsync)
            .RequirePermission(PermissionNames.WarehousesUpdate)
            .WithName("SetStockLocations");

        var inventory = api.MapGroup("/inventory")
            .WithApiVersionSet(versionSet)
            .WithTags("Inventory")
            .RequireAuthorization()
            .RequireRateLimiting("global");
        inventory.MapGet("/stock", ListStockBalancesAsync)
            .RequirePermission(PermissionNames.InventoryView)
            .WithName("ListStockBalances");
        inventory.MapGet("/movements", ListStockMovementsAsync)
            .RequirePermission(PermissionNames.InventoryView)
            .WithName("ListStockMovements");
        inventory.MapPost("/stock/opening", RecordOpeningStockAsync)
            .RequirePermission(PermissionNames.InventoryManage)
            .WithName("RecordOpeningStock");

        return app;
    }

    private static async Task<IResult> ListWarehousesAsync(
        int page,
        int pageSize,
        string? search,
        Guid? branchId,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new ListWarehousesQuery(page, pageSize, search, branchId),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> GetWarehouseAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetWarehouseQuery(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> CreateWarehouseAsync(
        CreateWarehouseCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command, cancellationToken)).ToApiResult();

    private static async Task<IResult> UpdateWarehouseAsync(
        Guid id,
        UpdateWarehouseCommand command,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(command with { Id = id }, cancellationToken)).ToApiResult();

    private static async Task<IResult> SetWarehouseStatusAsync(
        Guid id,
        SetWarehouseStatusRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new SetWarehouseStatusCommand(id, request.IsActive),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> DeleteWarehouseAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
    {
        var result = await sender.Send(new SetWarehouseStatusCommand(id, false), cancellationToken);
        return result.IsSuccess ? Results.NoContent() : result.ToApiResult();
    }

    private static async Task<IResult> SetStockLocationsAsync(
        Guid id,
        SetStockLocationsRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new SetStockLocationsCommand(id, request.Locations),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> ListStockBalancesAsync(
        int page,
        int pageSize,
        Guid? warehouseId,
        Guid? productId,
        string? search,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new ListStockBalancesQuery(page, pageSize, warehouseId, productId, search),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> ListStockMovementsAsync(
        int page,
        int pageSize,
        Guid? warehouseId,
        Guid? productId,
        StockMovementType? type,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new ListStockMovementsQuery(page, pageSize, warehouseId, productId, type),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> RecordOpeningStockAsync(
        RecordOpeningStockRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new RecordOpeningStockCommand(
                request.WarehouseId,
                request.LocationId,
                request.ProductId,
                request.VariantId,
                request.Quantity,
                request.UnitOfMeasureId,
                request.EffectiveAt,
                Reason: request.Reason),
            cancellationToken)).ToApiResult();

    private sealed record SetWarehouseStatusRequest(bool IsActive);

    private sealed record SetStockLocationsRequest(IReadOnlyList<StockLocationInput> Locations);

    private sealed record RecordOpeningStockRequest(
        Guid WarehouseId,
        Guid? LocationId,
        Guid ProductId,
        Guid? VariantId,
        decimal Quantity,
        Guid UnitOfMeasureId,
        DateTime EffectiveAt,
        string? Reason);
}
