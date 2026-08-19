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
        inventory.MapPost("/stock/adjustments", AdjustStockAsync)
            .RequirePermission(PermissionNames.InventoryManage)
            .WithName("AdjustStock");

        inventory.MapPost("/transfers", CreateTransferAsync)
            .RequirePermission(PermissionNames.InventoryManage)
            .WithName("CreateTransfer");
        inventory.MapGet("/transfers", ListTransfersAsync)
            .RequirePermission(PermissionNames.InventoryView)
            .WithName("ListTransfers");
        inventory.MapGet("/transfers/{id:guid}", GetTransferAsync)
            .RequirePermission(PermissionNames.InventoryView)
            .WithName("GetTransfer");
        inventory.MapPost("/transfers/{id:guid}/complete", CompleteTransferAsync)
            .RequirePermission(PermissionNames.InventoryManage)
            .WithName("CompleteTransfer");
        inventory.MapPost("/transfers/{id:guid}/cancel", CancelTransferAsync)
            .RequirePermission(PermissionNames.InventoryManage)
            .WithName("CancelTransfer");

        inventory.MapPost("/counts", CreateStockCountAsync)
            .RequirePermission(PermissionNames.InventoryManage)
            .WithName("CreateStockCount");
        inventory.MapGet("/counts", ListStockCountsAsync)
            .RequirePermission(PermissionNames.InventoryView)
            .WithName("ListStockCounts");
        inventory.MapGet("/counts/{id:guid}", GetStockCountAsync)
            .RequirePermission(PermissionNames.InventoryView)
            .WithName("GetStockCount");
        inventory.MapPost("/counts/{id:guid}/complete", CompleteStockCountAsync)
            .RequirePermission(PermissionNames.InventoryManage)
            .WithName("CompleteStockCount");
        inventory.MapPost("/counts/{id:guid}/cancel", CancelStockCountAsync)
            .RequirePermission(PermissionNames.InventoryManage)
            .WithName("CancelStockCount");

        inventory.MapPost("/batches", CreateStockBatchAsync)
            .RequirePermission(PermissionNames.InventoryManage)
            .WithName("CreateStockBatch");
        inventory.MapGet("/batches", ListStockBatchesAsync)
            .RequirePermission(PermissionNames.InventoryView)
            .WithName("ListStockBatches");
        inventory.MapGet("/batches/{id:guid}", GetStockBatchAsync)
            .RequirePermission(PermissionNames.InventoryView)
            .WithName("GetStockBatch");
        inventory.MapPatch("/batches/{id:guid}/status", SetStockBatchStatusAsync)
            .RequirePermission(PermissionNames.InventoryManage)
            .WithName("SetStockBatchStatus");

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

    private static async Task<IResult> AdjustStockAsync(
        AdjustStockRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new AdjustStockCommand(
                request.WarehouseId,
                request.LocationId,
                request.ProductId,
                request.VariantId,
                request.QuantityDelta,
                request.Reason,
                request.EffectiveAt),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> CreateTransferAsync(
        CreateTransferRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new CreateTransferCommand(
                request.SourceWarehouseId,
                request.SourceLocationId,
                request.DestinationWarehouseId,
                request.DestinationLocationId,
                request.ReferenceType,
                request.ReferenceId,
                request.Reason,
                request.Lines),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> ListTransfersAsync(
        int page,
        int pageSize,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new ListTransfersQuery(page, pageSize),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> GetTransferAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetTransferQuery(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> CompleteTransferAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new CompleteTransferCommand(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> CancelTransferAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new CancelTransferCommand(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> CreateStockCountAsync(
        CreateStockCountRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new CreateStockCountCommand(
                request.WarehouseId,
                request.StockLocationId,
                request.ProductId,
                request.VariantId,
                request.CountedQuantity,
                request.Notes),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> ListStockCountsAsync(
        int page,
        int pageSize,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new ListStockCountsQuery(page, pageSize),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> GetStockCountAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetStockCountQuery(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> CompleteStockCountAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new CompleteStockCountCommand(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> CancelStockCountAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new CancelStockCountCommand(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> CreateStockBatchAsync(
        CreateStockBatchRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new CreateStockBatchCommand(
                request.ProductId,
                request.VariantId,
                request.BatchNumber,
                request.ManufacturerDate,
                request.ExpiryDate,
                request.SupplierId,
                request.Notes),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> ListStockBatchesAsync(
        int page,
        int pageSize,
        Guid? productId,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new ListStockBatchesQuery(page, pageSize, productId),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> GetStockBatchAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetStockBatchQuery(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> SetStockBatchStatusAsync(
        Guid id,
        SetStockBatchStatusRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new SetStockBatchStatusCommand(id, request.IsActive),
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
        string? Reason,
        Guid? BatchId = null);

    private sealed record AdjustStockRequest(
        Guid WarehouseId,
        Guid? LocationId,
        Guid ProductId,
        Guid? VariantId,
        decimal QuantityDelta,
        string Reason,
        DateTime EffectiveAt,
        Guid? BatchId = null);

    private sealed record CreateTransferRequest(
        Guid SourceWarehouseId,
        Guid? SourceLocationId,
        Guid DestinationWarehouseId,
        Guid? DestinationLocationId,
        string? ReferenceType,
        Guid? ReferenceId,
        string? Reason,
        IReadOnlyList<TransferLineInput> Lines);

    private sealed record CreateStockCountRequest(
        Guid WarehouseId,
        Guid? StockLocationId,
        Guid ProductId,
        Guid? VariantId,
        decimal CountedQuantity,
        string? Notes);

    private sealed record CreateStockBatchRequest(
        Guid ProductId,
        Guid? VariantId,
        string BatchNumber,
        DateTime? ManufacturerDate,
        DateTime? ExpiryDate,
        Guid? SupplierId,
        string? Notes);

    private sealed record SetStockBatchStatusRequest(bool IsActive);
}
