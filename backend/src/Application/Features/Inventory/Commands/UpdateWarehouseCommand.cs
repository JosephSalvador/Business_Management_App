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
    private readonly IBranchRepository _branches;

    public UpdateWarehouseCommandHandler(
        ITenantContext tenantContext,
        IWarehouseRepository warehouses,
        IBranchRepository branches)
    {
        _tenantContext = tenantContext;
        _warehouses = warehouses;
        _branches = branches;
    }

    public async Task<Result<WarehouseDto>> Handle(
        UpdateWarehouseCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var warehouse = await _warehouses.GetByIdAsync(tenantId, command.Id, cancellationToken);
        if (warehouse is null)
        {
            return Error.NotFound("Warehouse not found.");
        }

        warehouse.UpdateProfile(command.Name, command.Description);

        var branch = await _branches.GetByIdAsync(tenantId, warehouse.BranchId, cancellationToken);
        return Result.Success(WarehouseMappers.ToDto(warehouse, branch?.Name ?? string.Empty));
    }
}
