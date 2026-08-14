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
