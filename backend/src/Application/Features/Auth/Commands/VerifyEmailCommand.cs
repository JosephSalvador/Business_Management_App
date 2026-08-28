using BusinessOS.Application.Features.Auth.Services;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Shared;
using BusinessOS.Shared.Configuration;
using MediatR;
using Microsoft.Extensions.Options;

namespace BusinessOS.Application.Features.Auth.Commands;

public sealed record VerifyEmailCommand(string Email, string Code) : IRequest<Result>;

public sealed class VerifyEmailCommandHandler : IRequestHandler<VerifyEmailCommand, Result>
{
    private readonly IUserRepository _users;
    private readonly IEmailVerificationCodeRepository _codes;
    private readonly IAuditLogRepository _auditLogs;
    private readonly SecurityOptions _security;

    public VerifyEmailCommandHandler(
        IUserRepository users,
        IEmailVerificationCodeRepository codes,
        IAuditLogRepository auditLogs,
        IOptions<SecurityOptions> security)
    {
        _users = users;
        _codes = codes;
        _auditLogs = auditLogs;
        _security = security.Value;
    }

    public async Task<Result> Handle(VerifyEmailCommand command, CancellationToken cancellationToken)
    {
        var normalizedEmail = command.Email.Trim().ToLowerInvariant();
        var user = await _users.GetByEmailAsync(normalizedEmail, cancellationToken);
        if (user is null)
        {
            return Result.Failure(Error.Validation("The verification code is invalid or has expired."));
        }

        if (user.EmailVerified)
        {
            return Result.Failure(Error.Conflict("This email address is already verified."));
        }

        var code = await _codes.GetLatestForUserAsync(user.TenantId, user.Id, cancellationToken);
        if (code is null || code.ConsumedAt is not null)
        {
            return Result.Failure(Error.Conflict("This verification code has already been used. Request a new one."));
        }

        if (code.ExpiresAt <= DateTime.UtcNow)
        {
            return Result.Failure(Error.Validation("This verification code has expired. Request a new one."));
        }

        if (EmailVerificationService.Hash(command.Code) != code.CodeHash)
        {
            code.RegisterFailedAttempt(_security.VerificationMaxAttempts);
            await _auditLogs.AddAsync(AuditLog.Create(
                user.TenantId,
                user.Id,
                "Auth.EmailVerificationFailed",
                "User",
                user.Id.ToString(),
                System.Text.Json.JsonSerializer.Serialize(new { attempt = code.AttemptCount })),
                cancellationToken);

            return Result.Failure(Error.Validation(code.AttemptCount >= _security.VerificationMaxAttempts
                ? "Too many wrong attempts. Request a new verification code."
                : "The verification code is invalid or has expired."));
        }

        if (!code.TryConsume())
        {
            return Result.Failure(Error.Conflict("This verification code has already been used. Request a new one."));
        }

        user.MarkEmailVerified();

        await _auditLogs.AddAsync(AuditLog.Create(
            user.TenantId,
            user.Id,
            "Auth.EmailVerified",
            "User",
            user.Id.ToString()),
            cancellationToken);

        return Result.Success();
    }
}
