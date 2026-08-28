using BusinessOS.Application.Features.Auth.Services;
using BusinessOS.Application.Features.Common;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Shared;
using BusinessOS.Shared.Configuration;
using MediatR;
using Microsoft.Extensions.Options;

namespace BusinessOS.Application.Features.Auth.Commands;

/// <summary>
/// Consumes a reset code and sets the new password. Successful resets also verify
/// the email address (the code could only be read from that inbox), clear any login
/// lockout, and revoke every refresh token so stolen sessions die with the old password.
/// </summary>
public sealed record ResetPasswordCommand(string Email, string Code, string NewPassword) : IRequest<Result>;

public sealed class ResetPasswordCommandHandler : IRequestHandler<ResetPasswordCommand, Result>
{
    private readonly IUserRepository _users;
    private readonly IPasswordResetCodeRepository _codes;
    private readonly IRefreshTokenRepository _refreshTokens;
    private readonly IPasswordHasher _passwordHasher;
    private readonly IAuditLogRepository _auditLogs;
    private readonly SecurityOptions _security;

    public ResetPasswordCommandHandler(
        IUserRepository users,
        IPasswordResetCodeRepository codes,
        IRefreshTokenRepository refreshTokens,
        IPasswordHasher passwordHasher,
        IAuditLogRepository auditLogs,
        IOptions<SecurityOptions> security)
    {
        _users = users;
        _codes = codes;
        _refreshTokens = refreshTokens;
        _passwordHasher = passwordHasher;
        _auditLogs = auditLogs;
        _security = security.Value;
    }

    public async Task<Result> Handle(ResetPasswordCommand command, CancellationToken cancellationToken)
    {
        var normalizedEmail = command.Email.Trim().ToLowerInvariant();
        var user = await _users.GetByEmailAsync(normalizedEmail, cancellationToken);
        if (user is null)
        {
            return Result.Failure(Error.Validation("The reset code is invalid or has expired."));
        }

        if (!user.IsActive)
        {
            return Result.Failure(Error.Unauthorized("This account has been deactivated."));
        }

        var code = await _codes.GetLatestForUserAsync(user.TenantId, user.Id, cancellationToken);
        if (code is null || code.ConsumedAt is not null)
        {
            return Result.Failure(Error.Conflict("This reset code has already been used. Request a new one."));
        }

        if (code.ExpiresAt <= DateTime.UtcNow)
        {
            return Result.Failure(Error.Validation("This reset code has expired. Request a new one."));
        }

        if (CodeHasher.Hash(command.Code) != code.CodeHash)
        {
            code.RegisterFailedAttempt(_security.PasswordResetMaxAttempts);
            await _auditLogs.AddAsync(AuditLog.Create(
                user.TenantId,
                user.Id,
                "Auth.PasswordResetFailed",
                "User",
                user.Id.ToString(),
                System.Text.Json.JsonSerializer.Serialize(new { attempt = code.AttemptCount })),
                cancellationToken);

            return Result.Failure(Error.Validation(code.AttemptCount >= _security.PasswordResetMaxAttempts
                ? "Too many wrong attempts. Request a new reset code."
                : "The reset code is invalid or has expired."));
        }

        if (!code.TryConsume())
        {
            return Result.Failure(Error.Conflict("This reset code has already been used. Request a new one."));
        }

        user.ChangePassword(_passwordHasher.Hash(command.NewPassword));
        user.MarkEmailVerified();
        user.ResetFailedLogins();
        await _refreshTokens.RevokeAllForUserAsync(user.TenantId, user.Id, cancellationToken);

        await _auditLogs.AddAsync(AuditLog.Create(
            user.TenantId,
            user.Id,
            "Auth.PasswordReset",
            "User",
            user.Id.ToString()),
            cancellationToken);

        return Result.Success();
    }
}
