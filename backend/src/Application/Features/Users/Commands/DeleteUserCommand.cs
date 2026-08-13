using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Users.Commands;

public sealed record DeleteUserCommand(Guid Id)
    : IRequest<Result>, IRequiresTenantAdvisoryLock;

public sealed class DeleteUserCommandHandler : IRequestHandler<DeleteUserCommand, Result>
{
    private readonly ITenantContext _tenantContext;
    private readonly IUserRepository _users;
    private readonly IRefreshTokenRepository _refreshTokens;
    private readonly IPermissionService _permissions;

    public DeleteUserCommandHandler(
        ITenantContext tenantContext,
        IUserRepository users,
        IRefreshTokenRepository refreshTokens,
        IPermissionService permissions)
    {
        _tenantContext = tenantContext;
        _users = users;
        _refreshTokens = refreshTokens;
        _permissions = permissions;
    }

    public async Task<Result> Handle(DeleteUserCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var user = await _users.GetByIdAsync(tenantId, command.Id, cancellationToken);
        if (user is null)
        {
            return Result.Failure(Error.NotFound("User not found."));
        }

        if (_tenantContext.UserId == command.Id)
        {
            return Result.Failure(Error.Conflict("You cannot delete your own account."));
        }

        if (await UserAdminGuard.EnsureAdministratorRemainsAsync(
                _users, tenantId, command.Id, "delete", cancellationToken) is { } error)
        {
            return Result.Failure(error);
        }

        user.Deactivate();
        await _refreshTokens.RevokeAllForUserAsync(tenantId, command.Id, cancellationToken);
        await _permissions.InvalidateAsync(command.Id, tenantId, cancellationToken);

        return Result.Success();
    }
}
