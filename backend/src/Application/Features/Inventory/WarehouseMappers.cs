using BusinessOS.Application.Features.Inventory.Commands;
using BusinessOS.Application.Features.Inventory.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Inventory;

namespace BusinessOS.Application.Features.Inventory;

internal static class WarehouseMappers
{
    internal static WarehouseDto ToDto(Warehouse warehouse, string branchName) => new(
        warehouse.Id,
        warehouse.TenantId,
        warehouse.BranchId,
        branchName,
        warehouse.Name,
        warehouse.Code,
        warehouse.Description,
        warehouse.IsActive,
        warehouse.Locations
            .OrderBy(l => l.Code)
            .Select(l => new StockLocationDto(l.Id, l.WarehouseId, l.Code, l.Name, l.IsActive))
            .ToArray(),
        warehouse.CreatedAt,
        warehouse.UpdatedAt);

    internal static StockLocationSpec ToSpec(StockLocationInput input)
        => new(input.Id ?? Guid.Empty, input.Code, input.Name);

    internal static StockBalanceDto ToBalanceDto(StockBalanceView balance) => new(
        balance.WarehouseId,
        balance.WarehouseName,
        balance.StockLocationId,
        balance.StockLocationName,
        balance.ProductId,
        balance.ProductName,
        balance.Sku,
        balance.Barcode,
        balance.VariantId,
        balance.UnitOfMeasureName,
        balance.Quantity);

    internal static StockBalanceDto ToBalanceDto(
        StockBalance balance,
        string warehouseName,
        string stockLocationName,
        string productName,
        string? sku,
        string? barcode,
        string unitOfMeasureName) => new(
        balance.WarehouseId,
        warehouseName,
        balance.StockLocationId,
        stockLocationName,
        balance.ProductId,
        productName,
        sku,
        barcode,
        balance.VariantId,
        unitOfMeasureName,
        balance.Quantity);

    internal static StockMovementDto ToMovementDto(StockMovementView movement) => new(
        movement.Id,
        movement.ProductId,
        movement.ProductName,
        movement.Sku,
        movement.Barcode,
        movement.WarehouseId,
        movement.WarehouseName,
        movement.StockLocationId,
        movement.StockLocationName,
        movement.Type,
        movement.QuantityDelta,
        movement.Reason,
        movement.EffectiveAt,
        movement.CreatedBy,
        movement.CreatedAt);

    internal static TransferDto ToTransferDto(
        Transfer transfer,
        string sourceWarehouseName,
        string destinationWarehouseName,
        IReadOnlyDictionary<Guid, string> productNames) => new(
        transfer.Id,
        transfer.SourceWarehouseId,
        sourceWarehouseName,
        transfer.SourceLocationId,
        transfer.DestinationWarehouseId,
        destinationWarehouseName,
        transfer.DestinationLocationId,
        transfer.Status,
        transfer.ReferenceType,
        transfer.ReferenceId,
        transfer.Reason,
        transfer.CompletedAt,
        transfer.CancelledAt,
        transfer.Lines.Select(l => new TransferLineDto(
            l.Id,
            l.ProductId,
            productNames.TryGetValue(l.ProductId, out var name) ? name : string.Empty,
            l.VariantId,
            l.Quantity,
            l.BatchId)).ToList(),
        transfer.CreatedAt);

    internal static StockCountDto ToStockCountDto(
        StockCount count,
        string warehouseName,
        string productName) => new(
        count.Id,
        count.WarehouseId,
        warehouseName,
        count.StockLocationId,
        count.ProductId,
        productName,
        count.VariantId,
        count.CountedQuantity,
        count.SystemQuantity,
        count.Difference,
        count.Notes,
        count.Status,
        count.CompletedAt,
        count.CancelledAt,
        count.CreatedAt);

    internal static StockBatchDto ToStockBatchDto(
        StockBatch batch,
        string productName) => new(
        batch.Id,
        batch.ProductId,
        productName,
        batch.VariantId,
        batch.BatchNumber,
        batch.ManufacturerDate,
        batch.ExpiryDate,
        batch.SupplierId,
        batch.Notes,
        batch.IsActive,
        batch.CreatedAt);
}
