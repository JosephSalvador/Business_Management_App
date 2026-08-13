using BusinessOS.Application.Features.Roles.Dtos;
using BusinessOS.Domain.Identity;

namespace BusinessOS.Application.Features.Roles;

internal static class RoleMappers
{
    internal static RoleDto ToDto(Role role) => new(
        role.Id,
        role.TenantId,
        role.Name,
        role.Description,
        role.IsSystem,
        role.Permissions.Select(p => p.Name).OrderBy(n => n).ToArray(),
        role.CreatedAt);

    internal static PermissionDto ToPermissionDto(Permission permission) => new(
        permission.Name,
        permission.Description);
}
