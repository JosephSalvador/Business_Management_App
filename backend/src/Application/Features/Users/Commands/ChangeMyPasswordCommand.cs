using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Users.Commands;

public sealed record ChangeMyPasswordCommand(
    string CurrentPassword,
    string NewPassword) : IRequest<Result>;

public sealed class ChangeMyPasswordCommandHandler : IRequestHandler<ChangeMyPasswordCommand, Result>
{
    private readonly ITenantContext _tenantContext;
    private readonly IUserRepository _users;
    private readonly IPasswordHasher _passwordHasher;
    private readonly IRefreshTokenRepository _refreshTokens;
    private readonly IAuditLogRepository _auditLogs;

    public ChangeMyPasswordCommandHandler(
        ITenantContext tenantContext,
        IUserRepository users,
        IPasswordHasher passwordHasher,
        IRefreshTokenRepository refreshTokens,
        IAuditLogRepository auditLogs)
    {
        _tenantContext = tenantContext;
        _users = users;
        _passwordHasher = passwordHasher;
        _refreshTokens = refreshTokens;
        _auditLogs = auditLogs;
    }

    public async Task<Result> Handle(ChangeMyPasswordCommand command, CancellationToken cancellationToken)
    {
        var userId = _tenantContext.UserId;
        if (userId is null)
        {
            return Result.Failure(Error.Unauthorized("Not authenticated."));
        }

        var user = await _users.GetByIdAsync(_tenantContext.TenantId, userId.Value, cancellationToken);
        if (user is null)
        {
            return Result.Failure(Error.NotFound("User not found."));
        }

        if (!user.IsActive)
        {
            return Result.Failure(Error.Unauthorized("This account has been deactivated."));
        }

        if (!_passwordHasher.Verify(command.CurrentPassword, user.PasswordHash))
        {
            return Result.Failure(Error.Validation("Current password is incorrect."));
        }

        user.ChangePassword(_passwordHasher.Hash(command.NewPassword));
        await _refreshTokens.RevokeAllForUserAsync(user.TenantId, user.Id, cancellationToken);

        await _auditLogs.AddAsync(AuditLog.Create(
            user.TenantId,
            user.Id,
            "Auth.PasswordChanged",
            "User",
            user.Id.ToString()),
            cancellationToken);

        return Result.Success();
    }
}
