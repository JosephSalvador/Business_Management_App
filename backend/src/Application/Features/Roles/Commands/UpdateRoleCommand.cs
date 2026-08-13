using BusinessOS.Application.Features.Roles.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Roles.Commands;

public sealed record UpdateRoleCommand(
    Guid Id,
    string Name,
    string? Description) : IRequest<Result<RoleDto>>;

public sealed class UpdateRoleCommandHandler : IRequestHandler<UpdateRoleCommand, Result<RoleDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IRoleRepository _roles;

    public UpdateRoleCommandHandler(ITenantContext tenantContext, IRoleRepository roles)
    {
        _tenantContext = tenantContext;
        _roles = roles;
    }

    public async Task<Result<RoleDto>> Handle(UpdateRoleCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var role = await _roles.GetByIdAsync(tenantId, command.Id, cancellationToken);
        if (role is null)
        {
            return Error.NotFound("Role not found.");
        }

        if (role.IsSystem)
        {
            return Error.Conflict("System roles cannot be renamed.");
        }

        var name = command.Name.Trim();
        var existing = await _roles.GetByNameAsync(tenantId, name, cancellationToken);
        if (existing is not null && existing.Id != role.Id)
        {
            return Error.Conflict("A role with this name already exists.");
        }

        role.Rename(name, command.Description);
        return Result.Success(RoleMappers.ToDto(role));
    }
}
