using BusinessOS.Application.Features.Inventory.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Inventory.Commands;

public sealed record SetWarehouseStatusCommand(Guid Id, bool IsActive)
    : IRequest<Result<WarehouseDto>>, IRequiresTenantAdvisoryLock;

public sealed class SetWarehouseStatusCommandHandler
    : IRequestHandler<SetWarehouseStatusCommand, Result<WarehouseDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IWarehouseRepository _warehouses;

    public SetWarehouseStatusCommandHandler(ITenantContext tenantContext, IWarehouseRepository warehouses)
    {
        _tenantContext = tenantContext;
        _warehouses = warehouses;
    }

    public async Task<Result<WarehouseDto>> Handle(
        SetWarehouseStatusCommand command, CancellationToken cancellationToken)
    {
        var warehouse = await _warehouses.GetByIdAsync(
            _tenantContext.TenantId, command.Id, cancellationToken);
        if (warehouse is null)
        {
            return Error.NotFound("Warehouse not found.");
        }

        if (command.IsActive)
        {
            warehouse.Activate();
        }
        else
        {
            warehouse.Deactivate();
        }

        return Result.Success(WarehouseMappers.ToDto(warehouse));
    }
}
