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

/// <summary>
/// Exchanges a login challenge for tokens once a second factor is proven. Accepts either a
/// TOTP code or a recovery code, because on a cheap Android with a damaged screen a user
/// may be able to read a printed code but not tap an authenticator.
/// </summary>
public sealed record VerifyTwoFactorCommand(
    string ChallengeToken,
    string Code,
    bool UseRecoveryCode = false) : IRequest<Result<AuthResponse>>;

public sealed class VerifyTwoFactorCommandHandler
    : IRequestHandler<VerifyTwoFactorCommand, Result<AuthResponse>>
{
    private readonly IUserRepository _users;
    private readonly ITwoFactorChallengeRepository _challenges;
    private readonly ITwoFactorRecoveryCodeRepository _recoveryCodes;
    private readonly IAuditLogRepository _auditLogs;
    private readonly TwoFactorChallengeService _twoFactor;
    private readonly AuthSessionIssuer _sessions;
    private readonly SecurityOptions _security;

    public VerifyTwoFactorCommandHandler(
        IUserRepository users,
        ITwoFactorChallengeRepository challenges,
        ITwoFactorRecoveryCodeRepository recoveryCodes,
        IAuditLogRepository auditLogs,
        TwoFactorChallengeService twoFactor,
        AuthSessionIssuer sessions,
        IOptions<SecurityOptions> security)
    {
        _users = users;
        _challenges = challenges;
        _recoveryCodes = recoveryCodes;
        _auditLogs = auditLogs;
        _twoFactor = twoFactor;
        _sessions = sessions;
        _security = security.Value;
    }

    public async Task<Result<AuthResponse>> Handle(
        VerifyTwoFactorCommand command,
        CancellationToken cancellationToken)
    {
        var challenge = await _twoFactor.FindAsync(command.ChallengeToken, cancellationToken);
        if (challenge is null || !challenge.IsUsable)
        {
            return Error.Unauthorized("This sign-in attempt has expired. Sign in again.");
        }

        var user = await _users.GetByIdAsync(challenge.TenantId, challenge.UserId, cancellationToken);
        if (user is null || !user.TwoFactorEnabled || !user.IsActive)
        {
            // A deactivated or un-enrolled account invalidates any challenge issued
            // before that change; the generic message keeps it indistinguishable from
            // an expired challenge.
            return Error.Unauthorized("This sign-in attempt has expired. Sign in again.");
        }

        var code = command.Code.Trim();
        if (code.Length == 0)
        {
            return Error.Validation("Enter the code from your authenticator app.");
        }

        var codeAccepted = command.UseRecoveryCode
            ? await ConsumeRecoveryCodeAsync(user, code, cancellationToken)
            : _twoFactor.VerifyCode(user, code);

        if (!codeAccepted)
        {
            // A wrong second factor feeds the ordinary lockout counter, so MFA cannot be used
            // to grind the password without inheriting the password lockout policy. The
            // challenge is also capped independently, so a stolen challenge cannot be used to
            // iterate every code inside its lifetime.
            challenge.RegisterFailedAttempt(_security.TwoFactorMaxAttempts);
            user.RegisterFailedLogin(
                _security.MaxFailedLoginAttempts,
                TimeSpan.FromMinutes(_security.LockoutDurationMinutes));

            await _auditLogs.AddAsync(AuditLog.Create(
                user.TenantId,
                user.Id,
                command.UseRecoveryCode ? "Auth.RecoveryCodeFailed" : "Auth.TwoFactorFailed",
                "User",
                user.Id.ToString(),
                System.Text.Json.JsonSerializer.Serialize(new { attempt = user.FailedLoginCount })),
                cancellationToken);

            // A wrong code is a validation failure, not an authentication failure: the
            // challenge is still alive, so the client must stay on the code screen and let
            // the user retry. Returning 401 here would sign them out on the first typo.
            // A spent challenge still fails with 401 above, which is the case that really
            // does require a fresh sign-in.
            if (user.IsLockedOut)
            {
                return Error.Unauthorized("This account is temporarily locked. Try again later.");
            }

            return Error.Validation("That code is not valid.");
        }

        // The lockout check has to happen after the code is proven, not before: a valid
        // attempt on an already-locked user is what ends the lockout, and rejecting it
        // up front would leave the account locked with no way back in.
        if (user.IsLockedOut)
        {
            return Error.Unauthorized("This account is temporarily locked. Try again later.");
        }

        // Spending the challenge is the single-use guarantee, and it is the *last* step: if
        // the conditional update reports no rows, another request already completed this
        // sign-in and returning a failure rolls back the recovery code just consumed.
        if (await _challenges.TryConsumeAsync(challenge.Id, cancellationToken) == 0)
        {
            return Error.Unauthorized("This sign-in attempt has expired. Sign in again.");
        }

        // A proven second factor is the successful sign-in, so the failure counter and any
        // lockout left over from wrong codes are cleared here.
        user.ResetFailedLogins();

        await _auditLogs.AddAsync(AuditLog.Create(
            user.TenantId,
            user.Id,
            command.UseRecoveryCode ? "Auth.RecoveryCodeUsed" : "Auth.TwoFactorVerified",
            "User",
            user.Id.ToString()),
            cancellationToken);

        return Result.Success(await _sessions.IssueAsync(user, cancellationToken));
    }

    private async Task<bool> ConsumeRecoveryCodeAsync(
        User user,
        string code,
        CancellationToken cancellationToken)
    {
        if (!TwoFactorSecretService.IsWellFormedRecoveryCode(code))
        {
            return false;
        }

        return await _recoveryCodes.TryConsumeAsync(
            user.TenantId,
            user.Id,
            TwoFactorSecretService.HashRecoveryCode(code),
            cancellationToken) == 1;
    }
}

/// <summary>
/// Enrolment step one: generate a secret and stage it. Deliberately does **not** enable
/// anything — the factor only becomes real once <see cref="ConfirmTwoFactorCommand"/>
/// proves the user can produce a code from it.
/// </summary>
public sealed record SetupTwoFactorCommand : IRequest<Result<TwoFactorSetupDto>>;

public sealed class SetupTwoFactorCommandHandler : IRequestHandler<SetupTwoFactorCommand, Result<TwoFactorSetupDto>>
{
    private readonly IUserRepository _users;
    private readonly ITotpService _totp;
    private readonly ISecretProtector _protector;
    private readonly ITenantContext _tenant;

    public SetupTwoFactorCommandHandler(
        IUserRepository users,
        ITotpService totp,
        ISecretProtector protector,
        ITenantContext tenant)
    {
        _users = users;
        _totp = totp;
        _protector = protector;
        _tenant = tenant;
    }

    public async Task<Result<TwoFactorSetupDto>> Handle(
        SetupTwoFactorCommand command,
        CancellationToken cancellationToken)
    {
        var userId = _tenant.UserId;
        if (userId is null)
        {
            return Error.Unauthorized("Sign in to continue.");
        }

        var user = await _users.GetByIdAsync(_tenant.TenantId, userId.Value, cancellationToken);
        if (user is null)
        {
            return Error.NotFound("User not found.");
        }

        var secret = _totp.GenerateSecret();
        user.StageTwoFactor(_protector.Protect(secret));

        var label = string.IsNullOrWhiteSpace(user.Email) ? user.FullName : user.Email;
        return Result.Success(new TwoFactorSetupDto(
            secret,
            _totp.GetProvisioningUri(secret, label, "Business OS")));
    }
}

/// <summary>
/// Enrolment step two: promotes the staged secret once a valid code is supplied. Also
/// issues the first recovery-code batch, because a factor the user cannot recover from is
/// a lockout waiting to happen.
/// </summary>
public sealed record ConfirmTwoFactorCommand(string Code) : IRequest<Result<TwoFactorEnabledDto>>;

public sealed class ConfirmTwoFactorCommandHandler
    : IRequestHandler<ConfirmTwoFactorCommand, Result<TwoFactorEnabledDto>>
{
    private readonly IUserRepository _users;
    private readonly ITwoFactorRecoveryCodeRepository _recoveryCodes;
    private readonly IAuditLogRepository _auditLogs;
    private readonly TwoFactorChallengeService _twoFactor;
    private readonly ITenantContext _tenant;
    private readonly SecurityOptions _security;

    public ConfirmTwoFactorCommandHandler(
        IUserRepository users,
        ITwoFactorRecoveryCodeRepository recoveryCodes,
        IAuditLogRepository auditLogs,
        TwoFactorChallengeService twoFactor,
        ITenantContext tenant,
        IOptions<SecurityOptions> security)
    {
        _users = users;
        _recoveryCodes = recoveryCodes;
        _auditLogs = auditLogs;
        _twoFactor = twoFactor;
        _tenant = tenant;
        _security = security.Value;
    }

    public async Task<Result<TwoFactorEnabledDto>> Handle(
        ConfirmTwoFactorCommand command,
        CancellationToken cancellationToken)
    {
        var userId = _tenant.UserId;
        if (userId is null)
        {
            return Error.Unauthorized("Sign in to continue.");
        }

        var user = await _users.GetByIdAsync(_tenant.TenantId, userId.Value, cancellationToken);
        if (user is null)
        {
            return Error.NotFound("User not found.");
        }

        if (!user.HasPendingTwoFactor)
        {
            return Error.Conflict("Start setup before confirming a code.");
        }

        // Prove possession before the factor starts gating anything, and validate against
        // the staged secret specifically so a re-enrol cannot be confirmed by a code from an
        // older factor.
        if (!_twoFactor.VerifyPendingCode(user, command.Code))
        {
            await _auditLogs.AddAsync(AuditLog.Create(
                user.TenantId,
                user.Id,
                "Auth.TwoFactorConfirmRejected",
                "User",
                user.Id.ToString()),
                cancellationToken);

            // Validation, not 401: enrolment happens while signed in, so a wrong code must
            // not look like an expired session.
            return Error.Validation("That code is not valid.");
        }

        user.ConfirmTwoFactor();

        var codes = _twoFactor.GenerateRecoveryCodes(_security.TwoFactorRecoveryCodeCount);
        await _recoveryCodes.AddRangeAsync(
            codes.Select(code => TwoFactorRecoveryCode.Create(
                user.TenantId,
                user.Id,
                TwoFactorSecretService.HashRecoveryCode(code))),
            cancellationToken);

        await _auditLogs.AddAsync(AuditLog.Create(
            user.TenantId,
            user.Id,
            "Auth.TwoFactorEnabled",
            "User",
            user.Id.ToString()),
            cancellationToken);

        // The codes ride along with the status because this is the only moment they
        // exist in plaintext; a separate follow-up call could not return them.
        return Result.Success(new TwoFactorEnabledDto(
            new MfaStatusDto(true, false, user.TwoFactorEnabledAt, codes.Count),
            new RecoveryCodesDto(codes)));
    }
}

/// <summary>Removes the second factor. Requires the current code so a hijacked session
/// cannot quietly downgrade the account's security.</summary>
public sealed record DisableTwoFactorCommand(string Code) : IRequest<Result>;

public sealed class DisableTwoFactorCommandHandler : IRequestHandler<DisableTwoFactorCommand, Result>
{
    private readonly IUserRepository _users;
    private readonly ITwoFactorRecoveryCodeRepository _recoveryCodes;
    private readonly IAuditLogRepository _auditLogs;
    private readonly TwoFactorChallengeService _twoFactor;
    private readonly ITenantContext _tenant;

    public DisableTwoFactorCommandHandler(
        IUserRepository users,
        ITwoFactorRecoveryCodeRepository recoveryCodes,
        IAuditLogRepository auditLogs,
        TwoFactorChallengeService twoFactor,
        ITenantContext tenant)
    {
        _users = users;
        _recoveryCodes = recoveryCodes;
        _auditLogs = auditLogs;
        _twoFactor = twoFactor;
        _tenant = tenant;
    }

    public async Task<Result> Handle(DisableTwoFactorCommand command, CancellationToken cancellationToken)
    {
        var userId = _tenant.UserId;
        if (userId is null)
        {
            return Result.Failure(Error.Unauthorized("Sign in to continue."));
        }

        var user = await _users.GetByIdAsync(_tenant.TenantId, userId.Value, cancellationToken);
        if (user is null)
        {
            return Result.Failure(Error.NotFound("User not found."));
        }

        if (!user.TwoFactorEnabled)
        {
            return Result.Success();
        }

        if (!_twoFactor.VerifyCode(user, command.Code))
        {
            await _auditLogs.AddAsync(AuditLog.Create(
                user.TenantId,
                user.Id,
                "Auth.TwoFactorDisableRejected",
                "User",
                user.Id.ToString()),
                cancellationToken);

            // Validation, not 401: a wrong code here must not look like a lost session.
            return Result.Failure(Error.Validation("That code is not valid."));
        }

        user.DisableTwoFactor();
        await _recoveryCodes.RemoveAllForUserAsync(user.TenantId, user.Id, cancellationToken);

        await _auditLogs.AddAsync(AuditLog.Create(
            user.TenantId,
            user.Id,
            "Auth.TwoFactorDisabled",
            "User",
            user.Id.ToString()),
            cancellationToken);

        return Result.Success();
    }
}

/// <summary>
/// Issues a fresh recovery-code batch and drops every previous one. The raw codes are
/// returned exactly once — only hashes are persisted, so this is the sole chance to save them.
/// </summary>
public sealed record RegenerateRecoveryCodesCommand : IRequest<Result<RecoveryCodesDto>>;

public sealed class RegenerateRecoveryCodesCommandHandler
    : IRequestHandler<RegenerateRecoveryCodesCommand, Result<RecoveryCodesDto>>
{
    private readonly IUserRepository _users;
    private readonly ITwoFactorRecoveryCodeRepository _recoveryCodes;
    private readonly IAuditLogRepository _auditLogs;
    private readonly TwoFactorChallengeService _twoFactor;
    private readonly ITenantContext _tenant;
    private readonly SecurityOptions _security;

    public RegenerateRecoveryCodesCommandHandler(
        IUserRepository users,
        ITwoFactorRecoveryCodeRepository recoveryCodes,
        IAuditLogRepository auditLogs,
        TwoFactorChallengeService twoFactor,
        ITenantContext tenant,
        IOptions<SecurityOptions> security)
    {
        _users = users;
        _recoveryCodes = recoveryCodes;
        _auditLogs = auditLogs;
        _twoFactor = twoFactor;
        _tenant = tenant;
        _security = security.Value;
    }

    public async Task<Result<RecoveryCodesDto>> Handle(
        RegenerateRecoveryCodesCommand command,
        CancellationToken cancellationToken)
    {
        var userId = _tenant.UserId;
        if (userId is null)
        {
            return Error.Unauthorized("Sign in to continue.");
        }

        var user = await _users.GetByIdAsync(_tenant.TenantId, userId.Value, cancellationToken);
        if (user is null)
        {
            return Error.NotFound("User not found.");
        }

        if (!user.TwoFactorEnabled)
        {
            return Error.Conflict("Turn on two-step verification first.");
        }

        await _recoveryCodes.RemoveAllForUserAsync(user.TenantId, user.Id, cancellationToken);

        var codes = _twoFactor.GenerateRecoveryCodes(_security.TwoFactorRecoveryCodeCount);
        await _recoveryCodes.AddRangeAsync(
            codes.Select(code => TwoFactorRecoveryCode.Create(
                user.TenantId,
                user.Id,
                TwoFactorSecretService.HashRecoveryCode(code))),
            cancellationToken);

        await _auditLogs.AddAsync(AuditLog.Create(
            user.TenantId,
            user.Id,
            "Auth.RecoveryCodesRegenerated",
            "User",
            user.Id.ToString()),
            cancellationToken);

        return Result.Success(new RecoveryCodesDto(codes));
    }
}
