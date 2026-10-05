using BusinessOS.Application.Features.Auth.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Services;
using BusinessOS.Shared;
using BusinessOS.Shared.Configuration;
using MediatR;
using Microsoft.Extensions.Options;

namespace BusinessOS.Application.Features.Auth.Queries;

/// <summary>
/// The signed-in user's own device sessions, newest first. This endpoint is permission-free:
/// requiring a permission to see your own devices would let a role misconfiguration strand
/// an owner who cannot sign in anywhere. Ownership, not privilege, is the check.
/// </summary>
public sealed record ListMySessionsQuery : IRequest<Result<IReadOnlyList<AuthSessionDto>>>;

public sealed class ListMySessionsQueryHandler
    : IRequestHandler<ListMySessionsQuery, Result<IReadOnlyList<AuthSessionDto>>>
{
    private readonly IRefreshTokenRepository _refreshTokens;
    private readonly ITokenService _tokenService;
    private readonly ITenantContext _tenant;

    public ListMySessionsQueryHandler(
        IRefreshTokenRepository refreshTokens,
        ITokenService tokenService,
        ITenantContext tenant)
    {
        _refreshTokens = refreshTokens;
        _tokenService = tokenService;
        _tenant = tenant;
    }

    public async Task<Result<IReadOnlyList<AuthSessionDto>>> Handle(
        ListMySessionsQuery query,
        CancellationToken cancellationToken)
    {
        var userId = _tenant.UserId;
        if (userId is null)
        {
            return Error.Unauthorized("Sign in to continue.");
        }

        var currentFamilyId = await ResolveCurrentFamilyAsync(
            _tenant.TenantId, userId.Value, cancellationToken);

        var tokens = await _refreshTokens.ListActiveByUserAsync(
            _tenant.TenantId, userId.Value, cancellationToken);

        // Rotation leaves one active token per family, but grouping keeps the projection
        // correct even if a rotation is interrupted and two rows are momentarily active.
        var sessions = tokens
            .GroupBy(t => t.FamilyId)
            .Select(group => group
                .OrderByDescending(t => t.CreatedAt)
                .First())
            .OrderByDescending(t => t.CreatedAt)
            .Select(t => new AuthSessionDto(
                t.FamilyId,
                SessionPresentation.DescribeDevice(t.DeviceLabel, t.IpAddress),
                t.IpAddress,
                t.CreatedAt,
                SessionPresentation.IsCurrentSession(t.FamilyId, currentFamilyId ?? Guid.Empty)))
            .ToList();

        return Result.Success<IReadOnlyList<AuthSessionDto>>(sessions);
    }

    /// <summary>
    /// Identifies the calling device so the list can mark "this one". The presented access
    /// token does not carry the family, so the refresh token is matched by hash.
    /// </summary>
    private async Task<Guid?> ResolveCurrentFamilyAsync(
        Guid tenantId,
        Guid userId,
        CancellationToken cancellationToken)
    {
        var presented = _tenant.CurrentRefreshToken;
        if (string.IsNullOrWhiteSpace(presented))
        {
            return null;
        }

        var stored = await _refreshTokens.GetByHashAsync(
            _tokenService.HashRefreshToken(presented), cancellationToken);

        // Scoped to the caller and the caller's tenant: a refresh token that is valid but
        // belongs to someone else must not reveal anything, not even which family it maps to.
        if (stored is null || stored.UserId != userId || stored.TenantId != tenantId)
        {
            return null;
        }

        return stored.FamilyId;
    }
}

/// <summary>
/// Revokes one device. Scoped to the caller: a session belonging to another user is
/// reported as not found rather than forbidden, so the endpoint cannot be used to probe
/// which session ids exist.
/// </summary>
/// <param name="SessionFamilyId">
/// The token family, not a single token row: revoking a session must kill the whole rotation
/// chain, and that is what a family identifies. This is also the id the client is shown, so it
/// is the only handle a caller ever holds.
/// </param>
public sealed record RevokeSessionByIdCommand(Guid SessionFamilyId) : IRequest<Result>;

public sealed class RevokeSessionByIdCommandHandler : IRequestHandler<RevokeSessionByIdCommand, Result>
{
    private readonly IRefreshTokenRepository _refreshTokens;
    private readonly IAuditLogRepository _auditLogs;
    private readonly ITenantContext _tenant;

    public RevokeSessionByIdCommandHandler(
        IRefreshTokenRepository refreshTokens,
        IAuditLogRepository auditLogs,
        ITenantContext tenant)
    {
        _refreshTokens = refreshTokens;
        _auditLogs = auditLogs;
        _tenant = tenant;
    }

    public async Task<Result> Handle(RevokeSessionByIdCommand command, CancellationToken cancellationToken)
    {
        var userId = _tenant.UserId;
        if (userId is null)
        {
            return Result.Failure(Error.Unauthorized("Sign in to continue."));
        }

        var active = await _refreshTokens.ListActiveByUserAsync(
            _tenant.TenantId, userId.Value, cancellationToken);

        var target = active.FirstOrDefault(t => t.FamilyId == command.SessionFamilyId);
        if (target is null)
        {
            return Result.Failure(Error.NotFound("Session not found."));
        }

        await _refreshTokens.RevokeFamilyAsync(target.FamilyId, target.Id, cancellationToken);

        await _auditLogs.AddAsync(AuditLog.Create(
            _tenant.TenantId,
            userId.Value,
            "Auth.SessionRevoked",
            "User",
            userId.Value.ToString(),
            System.Text.Json.JsonSerializer.Serialize(new { familyId = target.FamilyId })),
            cancellationToken);

        return Result.Success();
    }
}

/// <summary>
/// Signs the user out of every device, **including the current one**. A user reaching for
/// "sign out everywhere" after suspecting a compromise should not have to remember to log
/// out of the device they are holding.
/// </summary>
public sealed record RevokeAllSessionsCommand : IRequest<Result>;

public sealed class RevokeAllSessionsCommandHandler : IRequestHandler<RevokeAllSessionsCommand, Result>
{
    private readonly IRefreshTokenRepository _refreshTokens;
    private readonly IAuditLogRepository _auditLogs;
    private readonly ITenantContext _tenant;

    public RevokeAllSessionsCommandHandler(
        IRefreshTokenRepository refreshTokens,
        IAuditLogRepository auditLogs,
        ITenantContext tenant)
    {
        _refreshTokens = refreshTokens;
        _auditLogs = auditLogs;
        _tenant = tenant;
    }

    public async Task<Result> Handle(RevokeAllSessionsCommand command, CancellationToken cancellationToken)
    {
        var userId = _tenant.UserId;
        if (userId is null)
        {
            return Result.Failure(Error.Unauthorized("Sign in to continue."));
        }

        await _refreshTokens.RevokeAllForUserAsync(_tenant.TenantId, userId.Value, cancellationToken);

        await _auditLogs.AddAsync(AuditLog.Create(
            _tenant.TenantId,
            userId.Value,
            "Auth.AllSessionsRevoked",
            "User",
            userId.Value.ToString()),
            cancellationToken);

        return Result.Success();
    }
}

/// <summary>Second-factor status for the signed-in user. Never returns the secret.</summary>
public sealed record GetMfaStatusQuery : IRequest<Result<MfaStatusDto>>;

public sealed class GetMfaStatusQueryHandler : IRequestHandler<GetMfaStatusQuery, Result<MfaStatusDto>>
{
    private readonly IUserRepository _users;
    private readonly ITwoFactorRecoveryCodeRepository _recoveryCodes;
    private readonly ITenantContext _tenant;
    private readonly SecurityOptions _security;

    public GetMfaStatusQueryHandler(
        IUserRepository users,
        ITwoFactorRecoveryCodeRepository recoveryCodes,
        ITenantContext tenant,
        IOptions<SecurityOptions> security)
    {
        _users = users;
        _recoveryCodes = recoveryCodes;
        _tenant = tenant;
        _security = security.Value;
    }

    public async Task<Result<MfaStatusDto>> Handle(GetMfaStatusQuery query, CancellationToken cancellationToken)
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

        var remaining = 0;
        if (user.TwoFactorEnabled)
        {
            var codes = await _recoveryCodes.ListForUserAsync(user.TenantId, user.Id, cancellationToken);
            remaining = codes.Count(c => !c.IsUsed);
        }

        return Result.Success(new MfaStatusDto(
            user.TwoFactorEnabled,
            user.HasPendingTwoFactor,
            user.TwoFactorEnabledAt,
            remaining)
        {
            RequiredForThisUser = _security.TwoFactorRequiredForOwners && IsPrivileged(user),
        });
    }

    /// <summary>
    /// "Owner" is modelled as the tenant's administrator role — the account that registers
    /// the business. There is no separate owner role in the platform, so this keys off the
    /// administrator role rather than inventing one.
    /// </summary>
    private static bool IsPrivileged(User user)
        => user.Roles.Any(r => string.Equals(r.Name, SystemRoles.Administrator, StringComparison.Ordinal));
}
