using BusinessOS.Application.Features.Roles.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Roles.Commands;

public sealed record SetRolePermissionsCommand(
    Guid RoleId,
    IReadOnlyList<string> PermissionNames) : IRequest<Result<RoleDto>>;

public sealed class SetRolePermissionsCommandHandler : IRequestHandler<SetRolePermissionsCommand, Result<RoleDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IRoleRepository _roles;
    private readonly IPermissionRepository _permissions;

    public SetRolePermissionsCommandHandler(
        ITenantContext tenantContext,
        IRoleRepository roles,
        IPermissionRepository permissions)
    {
        _tenantContext = tenantContext;
        _roles = roles;
        _permissions = permissions;
    }

    public async Task<Result<RoleDto>> Handle(
        SetRolePermissionsCommand command, CancellationToken cancellationToken)
    {
        var role = await _roles.GetByIdAsync(_tenantContext.TenantId, command.RoleId, cancellationToken);
        if (role is null)
        {
            return Error.NotFound("Role not found.");
        }

        var names = command.PermissionNames.Distinct().ToArray();
        var resolved = await _permissions.ResolveByNamesAsync(names, cancellationToken);
        if (resolved.Count != names.Length)
        {
            return Error.Validation(new Dictionary<string, string[]>
            {
                ["PermissionNames"] = new[] { "One or more permissions do not exist in the catalog." },
            });
        }

        role.SetPermissions(resolved);
        return Result.Success(RoleMappers.ToDto(role));
    }
}
