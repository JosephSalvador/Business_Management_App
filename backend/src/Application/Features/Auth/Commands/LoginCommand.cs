using BusinessOS.Application.Features.Auth.Dtos;
using BusinessOS.Application.Features.Auth.Services;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Domain.Identity;
using BusinessOS.Shared;
using BusinessOS.Shared.Configuration;
using MediatR;
using Microsoft.Extensions.Options;

namespace BusinessOS.Application.Features.Auth.Commands;

public sealed record LoginCommand(string Identifier, string Password) : IRequest<Result<LoginResponse>>;

public sealed class LoginCommandHandler : IRequestHandler<LoginCommand, Result<LoginResponse>>
{
    private readonly IUserRepository _users;
    private readonly IAuditLogRepository _auditLogs;
    private readonly IPasswordHasher _passwordHasher;
    private readonly TwoFactorChallengeService _twoFactor;
    private readonly AuthSessionIssuer _sessions;
    private readonly SecurityOptions _security;

    public LoginCommandHandler(
        IUserRepository users,
        IAuditLogRepository auditLogs,
        IPasswordHasher passwordHasher,
        TwoFactorChallengeService twoFactor,
        AuthSessionIssuer sessions,
        IOptions<SecurityOptions> security)
    {
        _users = users;
        _auditLogs = auditLogs;
        _passwordHasher = passwordHasher;
        _twoFactor = twoFactor;
        _sessions = sessions;
        _security = security.Value;
    }

    public async Task<Result<LoginResponse>> Handle(LoginCommand command, CancellationToken cancellationToken)
    {
        var identifier = command.Identifier.Trim();
        User? user;
        if (identifier.Contains('@'))
        {
            user = await _users.GetByEmailAsync(identifier.ToLowerInvariant(), cancellationToken);
        }
        else
        {
            var phone = PhoneNumber.Normalize(identifier);
            user = phone is null
                ? null
                : await _users.GetByPhoneAsync(phone, cancellationToken);
        }

        if (user is null)
        {
            return Error.Unauthorized("Invalid email or password.");
        }

        if (user.IsLockedOut)
        {
            return Error.Unauthorized("This account is temporarily locked. Try again later.");
        }

        if (!_passwordHasher.Verify(command.Password, user.PasswordHash))
        {
            user.RegisterFailedLogin(_security.MaxFailedLoginAttempts, TimeSpan.FromMinutes(_security.LockoutDurationMinutes));
            await _auditLogs.AddAsync(AuditLog.Create(
                user.TenantId,
                user.Id,
                "Auth.LoginFailed",
                "User",
                user.Id.ToString(),
                System.Text.Json.JsonSerializer.Serialize(new { attempt = user.FailedLoginCount })),
                cancellationToken);
            return Error.Unauthorized("Invalid email or password.");
        }

        if (!user.IsActive)
        {
            return Error.Unauthorized("This account has been deactivated.");
        }

        if (!user.EmailVerified)
        {
            // Include the account email so clients can resume verification even
            // when the user signed in with a phone number instead of the email.
            var details = new Dictionary<string, string[]>
            {
                ["email"] = new[] { user.Email },
            };
            return Error.AccountNotVerified("Verify your email address before signing in.")
                with { Details = details };
        }

        user.ResetFailedLogins();

        // A password check is not yet a session when a second factor is pending: hand back a
        // challenge and mint nothing. The client must come back with a TOTP or recovery code,
        // which is then exchanged for tokens by VerifyTwoFactorCommand.
        if (user.TwoFactorEnabled)
        {
            var challenge = await _twoFactor.IssueAsync(user, cancellationToken);

            await _auditLogs.AddAsync(AuditLog.Create(
                user.TenantId,
                user.Id,
                "Auth.TwoFactorChallengeIssued",
                "User",
                user.Id.ToString()),
                cancellationToken);

            return Result.Success(LoginResponse.TwoFactorRequired(challenge, user.Email));
        }

        return Result.Success(LoginResponse.Authenticated(await _sessions.IssueAsync(user, cancellationToken)));
    }
}
