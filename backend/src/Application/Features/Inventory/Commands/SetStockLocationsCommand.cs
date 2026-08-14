using BusinessOS.Application.Features.Inventory.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Inventory;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Inventory.Commands;

public sealed record SetStockLocationsCommand(
    Guid WarehouseId,
    IReadOnlyList<StockLocationInput> Locations)
    : IRequest<Result<IReadOnlyList<StockLocationDto>>>, IRequiresTenantAdvisoryLock;

public sealed class SetStockLocationsCommandHandler
    : IRequestHandler<SetStockLocationsCommand, Result<IReadOnlyList<StockLocationDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IWarehouseRepository _warehouses;

    public SetStockLocationsCommandHandler(ITenantContext tenantContext, IWarehouseRepository warehouses)
    {
        _tenantContext = tenantContext;
        _warehouses = warehouses;
    }

    public async Task<Result<IReadOnlyList<StockLocationDto>>> Handle(
        SetStockLocationsCommand command, CancellationToken cancellationToken)
    {
        var warehouse = await _warehouses.GetByIdAsync(
            _tenantContext.TenantId, command.WarehouseId, cancellationToken);
        if (warehouse is null)
        {
            return Error.NotFound("Warehouse not found.");
        }

        var codes = command.Locations.Select(l => Warehouse.NormalizeCode(l.Code)).ToArray();
        if (codes.Length != codes.Distinct().Count())
        {
            return Error.Validation("Location codes must be unique.");
        }

        warehouse.SetLocations(command.Locations.Select(WarehouseMappers.ToSpec));

        return Result.Success<IReadOnlyList<StockLocationDto>>(
            warehouse.Locations
                .OrderBy(l => l.Code)
                .Select(l => new StockLocationDto(l.Id, l.WarehouseId, l.Code, l.Name, l.IsActive))
                .ToArray());
    }
}
