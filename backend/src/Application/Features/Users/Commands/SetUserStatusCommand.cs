using BusinessOS.Application.Features.Users.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Users.Commands;

public sealed record SetUserStatusCommand(Guid Id, bool IsActive)
    : IRequest<Result<IdentityUserDto>>, IRequiresTenantAdvisoryLock;

public sealed class SetUserStatusCommandHandler : IRequestHandler<SetUserStatusCommand, Result<IdentityUserDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IUserRepository _users;
    private readonly IPermissionService _permissions;

    public SetUserStatusCommandHandler(
        ITenantContext tenantContext,
        IUserRepository users,
        IPermissionService permissions)
    {
        _tenantContext = tenantContext;
        _users = users;
        _permissions = permissions;
    }

    public async Task<Result<IdentityUserDto>> Handle(
        SetUserStatusCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var user = await _users.GetByIdAsync(tenantId, command.Id, cancellationToken);
        if (user is null)
        {
            return Error.NotFound("User not found.");
        }

        if (command.IsActive)
        {
            user.Activate();
        }
        else
        {
            if (_tenantContext.UserId == command.Id)
            {
                return Error.Conflict("You cannot deactivate your own account.");
            }

            if (await UserAdminGuard.EnsureAdministratorRemainsAsync(
                    _users, tenantId, command.Id, "deactivate", cancellationToken) is { } error)
            {
                return error;
            }

            user.Deactivate();
        }

        await _permissions.InvalidateAsync(command.Id, tenantId, cancellationToken);
        return Result.Success(UserMappers.ToDto(user));
    }
}
