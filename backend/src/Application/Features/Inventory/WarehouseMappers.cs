using BusinessOS.Application.Features.Inventory.Dtos;
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

    internal static StockBalanceDto ToBalanceDto(StockBalance balance) => new(
        balance.WarehouseId,
        balance.StockLocationId,
        balance.ProductId,
        balance.VariantId,
        balance.Quantity);

    internal static StockMovementDto ToMovementDto(StockMovement movement) => new(
        movement.Id,
        movement.MovementType,
        movement.Quantity,
        movement.Reason,
        movement.OccurredAt,
        movement.CreatedBy,
        movement.CreatedAt);
}
