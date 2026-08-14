using BusinessOS.Application.Features.Inventory.Dtos;
using BusinessOS.Domain.Inventory;

namespace BusinessOS.Application.Features.Inventory;

internal static class WarehouseMappers
{
    internal static WarehouseDto ToDto(Warehouse warehouse) => new(
        warehouse.Id,
        warehouse.TenantId,
        warehouse.BranchId,
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
}
