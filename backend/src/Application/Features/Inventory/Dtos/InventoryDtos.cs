using BusinessOS.Domain.Inventory;

namespace BusinessOS.Application.Features.Inventory.Dtos;

public sealed record WarehouseDto(
    Guid Id,
    Guid TenantId,
    Guid BranchId,
    string BranchName,
    string Name,
    string Code,
    string? Description,
    bool IsActive,
    IReadOnlyList<StockLocationDto> Locations,
    DateTime CreatedAt,
    DateTime? UpdatedAt);

public sealed record StockLocationDto(
    Guid Id,
    Guid WarehouseId,
    string Code,
    string Name,
    bool IsActive);

public sealed record StockLocationInput(Guid? Id, string Code, string Name);

public sealed record StockBalanceDto(
    Guid WarehouseId,
    Guid StockLocationId,
    Guid ProductId,
    Guid? VariantId,
    decimal Quantity);

public sealed record StockMovementDto(
    Guid Id,
    StockMovementType Type,
    decimal QuantityDelta,
    string? Reason,
    DateTime EffectiveAt,
    Guid? CreatedBy,
    DateTime CreatedAt);

public sealed record TransferDto(
    Guid Id,
    Guid SourceWarehouseId,
    string SourceWarehouseName,
    Guid? SourceLocationId,
    Guid DestinationWarehouseId,
    string DestinationWarehouseName,
    Guid? DestinationLocationId,
    TransferStatus Status,
    string? ReferenceType,
    Guid? ReferenceId,
    string? Reason,
    DateTime? CompletedAt,
    DateTime? CancelledAt,
    IReadOnlyList<TransferLineDto> Lines,
    DateTime CreatedAt);

public sealed record TransferLineDto(
    Guid Id,
    Guid ProductId,
    string ProductName,
    Guid? VariantId,
    decimal Quantity,
    Guid? BatchId);

public sealed record TransferSummaryDto(
    Guid Id,
    string SourceWarehouseName,
    string DestinationWarehouseName,
    TransferStatus Status,
    int LineCount,
    string? Reason,
    DateTime CreatedAt);

public sealed record StockCountDto(
    Guid Id,
    Guid WarehouseId,
    string WarehouseName,
    Guid? StockLocationId,
    Guid ProductId,
    string ProductName,
    Guid? VariantId,
    decimal CountedQuantity,
    decimal SystemQuantity,
    decimal Difference,
    string? Notes,
    CountStatus Status,
    DateTime? CompletedAt,
    DateTime? CancelledAt,
    DateTime CreatedAt);

public sealed record StockCountSummaryDto(
    Guid Id,
    string WarehouseName,
    string ProductName,
    decimal CountedQuantity,
    CountStatus Status,
    DateTime CreatedAt);

public sealed record StockBatchDto(
    Guid Id,
    Guid ProductId,
    string ProductName,
    Guid? VariantId,
    string BatchNumber,
    DateTime? ManufacturerDate,
    DateTime? ExpiryDate,
    Guid? SupplierId,
    string? Notes,
    bool IsActive,
    DateTime CreatedAt);
