using BusinessOS.Application.Features.Users.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Identity;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Users.Commands;

public sealed record SetUserRolesCommand(Guid Id, IReadOnlyList<Guid> RoleIds)
    : IRequest<Result<IdentityUserDto>>, IRequiresTenantAdvisoryLock;

public sealed class SetUserRolesCommandHandler : IRequestHandler<SetUserRolesCommand, Result<IdentityUserDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IUserRepository _users;
    private readonly IRoleRepository _roles;
    private readonly IPermissionService _permissions;

    public SetUserRolesCommandHandler(
        ITenantContext tenantContext,
        IUserRepository users,
        IRoleRepository roles,
        IPermissionService permissions)
    {
        _tenantContext = tenantContext;
        _users = users;
        _roles = roles;
        _permissions = permissions;
    }

    public async Task<Result<IdentityUserDto>> Handle(
        SetUserRolesCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var user = await _users.GetByIdAsync(tenantId, command.Id, cancellationToken);
        if (user is null)
        {
            return Error.NotFound("User not found.");
        }

        var roleIds = command.RoleIds.Distinct().ToArray();
        var roles = await _roles.GetManyByIdsAsync(tenantId, roleIds, cancellationToken);
        if (roles.Count != roleIds.Length)
        {
            return Error.Validation(new Dictionary<string, string[]>
            {
                ["RoleIds"] = new[] { "One or more roles do not exist in this tenant." },
            });
        }

        var holdsAdministrator = user.Roles.Any(r => r.IsSystem && r.Name == SystemRoles.Administrator);
        var retainsAdministrator = roles.Any(r => r.IsSystem && r.Name == SystemRoles.Administrator);
        if (holdsAdministrator && !retainsAdministrator)
        {
            if (await UserAdminGuard.EnsureAdministratorRemainsAsync(
                    _users, tenantId, command.Id, "remove", cancellationToken) is { } error)
            {
                return error;
            }
        }

        user.SetRoles(roles);
        await _permissions.InvalidateAsync(command.Id, tenantId, cancellationToken);

        return Result.Success(UserMappers.ToDto(user));
    }
}
