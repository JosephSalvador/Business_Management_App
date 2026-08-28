using BusinessOS.Application.Features.Auth.Services;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Auth.Commands;

/// <summary>
/// Requests a password reset email. The response is deliberately uniform whether or
/// not the account exists, so the endpoint cannot be used to enumerate registered
/// accounts.
/// </summary>
public sealed record RequestPasswordResetCommand(string Email) : IRequest<Result>;

public sealed class RequestPasswordResetCommandHandler
    : IRequestHandler<RequestPasswordResetCommand, Result>
{
    private readonly IUserRepository _users;
    private readonly PasswordResetService _reset;
    private readonly IAuditLogRepository _auditLogs;

    public RequestPasswordResetCommandHandler(
        IUserRepository users,
        PasswordResetService reset,
        IAuditLogRepository auditLogs)
    {
        _users = users;
        _reset = reset;
        _auditLogs = auditLogs;
    }

    public async Task<Result> Handle(RequestPasswordResetCommand command, CancellationToken cancellationToken)
    {
        var normalizedEmail = command.Email.Trim().ToLowerInvariant();
        var user = await _users.GetByEmailAsync(normalizedEmail, cancellationToken);

        if (user is null || !user.IsActive)
        {
            return Result.Success();
        }

        var cooldown = await _reset.GetRemainingCooldownAsync(user, cancellationToken);
        if (cooldown is not null)
        {
            return Result.Failure(Error.TooManyRequests(
                $"Please wait {Math.Ceiling(cooldown.Value.TotalSeconds)} seconds before requesting another code."));
        }

        await _reset.IssueAsync(user, cancellationToken);

        await _auditLogs.AddAsync(AuditLog.Create(
            user.TenantId,
            user.Id,
            "Auth.PasswordResetRequested",
            "User",
            user.Id.ToString()),
            cancellationToken);

        return Result.Success();
    }
}
