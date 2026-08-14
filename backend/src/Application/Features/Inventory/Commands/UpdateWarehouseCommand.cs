using BusinessOS.Application.Features.Inventory.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Inventory.Commands;

public sealed record UpdateWarehouseCommand(
    Guid Id,
    string Name,
    string? Description) : IRequest<Result<WarehouseDto>>, IRequiresTenantAdvisoryLock;

public sealed class UpdateWarehouseCommandHandler
    : IRequestHandler<UpdateWarehouseCommand, Result<WarehouseDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IWarehouseRepository _warehouses;

    public UpdateWarehouseCommandHandler(ITenantContext tenantContext, IWarehouseRepository warehouses)
    {
        _tenantContext = tenantContext;
        _warehouses = warehouses;
    }

    public async Task<Result<WarehouseDto>> Handle(
        UpdateWarehouseCommand command, CancellationToken cancellationToken)
    {
        var warehouse = await _warehouses.GetByIdAsync(
            _tenantContext.TenantId, command.Id, cancellationToken);
        if (warehouse is null)
        {
            return Error.NotFound("Warehouse not found.");
        }

        warehouse.UpdateProfile(command.Name, command.Description);
        return Result.Success(WarehouseMappers.ToDto(warehouse));
    }
}
