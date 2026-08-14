using BusinessOS.Application.Features.Inventory.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Inventory;
using BusinessOS.Domain.Tenants;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Inventory.Commands;

public sealed record CreateWarehouseCommand(
    string Name,
    string Code,
    Guid BranchId,
    string? Description) : IRequest<Result<WarehouseDto>>, IRequiresTenantAdvisoryLock;

public sealed class CreateWarehouseCommandHandler
    : IRequestHandler<CreateWarehouseCommand, Result<WarehouseDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IWarehouseRepository _warehouses;
    private readonly IBranchRepository _branches;

    public CreateWarehouseCommandHandler(
        ITenantContext tenantContext,
        IWarehouseRepository warehouses,
        IBranchRepository branches)
    {
        _tenantContext = tenantContext;
        _warehouses = warehouses;
        _branches = branches;
    }

    public async Task<Result<WarehouseDto>> Handle(
        CreateWarehouseCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var normalizedCode = Warehouse.NormalizeCode(command.Code);

        if (await _branches.GetByIdAsync(tenantId, command.BranchId, cancellationToken) is null)
        {
            return Error.Validation("The branch does not exist in this tenant.");
        }

        if (await _warehouses.GetByCodeAsync(tenantId, normalizedCode, cancellationToken) is not null)
        {
            return Error.Conflict("A warehouse with this code already exists.");
        }

        var warehouse = Warehouse.Create(
            tenantId, command.BranchId, command.Name, normalizedCode, command.Description);

        await _warehouses.AddAsync(warehouse, cancellationToken);
        return Result.Success(WarehouseMappers.ToDto(warehouse));
    }
}
