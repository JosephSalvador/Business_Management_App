using BusinessOS.Application.Features.Auth.Services;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Auth.Commands;

/// <summary>
/// Re-sends the verification email. The response is deliberately uniform when the
/// account does not exist or is already verified, so the endpoint cannot be used to
/// enumerate registered accounts.
/// </summary>
public sealed record ResendVerificationCodeCommand(string Email) : IRequest<Result>;

public sealed class ResendVerificationCodeCommandHandler : IRequestHandler<ResendVerificationCodeCommand, Result>
{
    private readonly IUserRepository _users;
    private readonly EmailVerificationService _verification;

    public ResendVerificationCodeCommandHandler(IUserRepository users, EmailVerificationService verification)
    {
        _users = users;
        _verification = verification;
    }

    public async Task<Result> Handle(ResendVerificationCodeCommand command, CancellationToken cancellationToken)
    {
        var normalizedEmail = command.Email.Trim().ToLowerInvariant();
        var user = await _users.GetByEmailAsync(normalizedEmail, cancellationToken);

        if (user is null || !user.IsActive || user.EmailVerified)
        {
            return Result.Success();
        }

        var cooldown = await _verification.GetRemainingCooldownAsync(user, cancellationToken);
        if (cooldown is not null)
        {
            return Result.Failure(Error.TooManyRequests(
                $"Please wait {Math.Ceiling(cooldown.Value.TotalSeconds)} seconds before requesting another code."));
        }

        await _verification.IssueAsync(user, cancellationToken);
        return Result.Success();
    }
}
