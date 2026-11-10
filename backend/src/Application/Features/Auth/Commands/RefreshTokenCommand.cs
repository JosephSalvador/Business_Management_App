using BusinessOS.Application.Features.Auth.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Domain.Identity;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Auth.Commands;

public sealed record RefreshTokenCommand(string RefreshToken) : IRequest<Result<AuthResponse>>;

public sealed class RefreshTokenCommandHandler : IRequestHandler<RefreshTokenCommand, Result<AuthResponse>>
{
    private readonly IRefreshTokenRepository _refreshTokens;
    private readonly IUserRepository _users;
    private readonly IRoleRepository _roles;
    private readonly IAuditLogRepository _auditLogs;
    private readonly ITokenService _tokenService;
    private readonly IPlatformOperatorRepository _platformOperators;

    public RefreshTokenCommandHandler(
        IRefreshTokenRepository refreshTokens,
        IUserRepository users,
        IRoleRepository roles,
        IAuditLogRepository auditLogs,
        ITokenService tokenService,
        IPlatformOperatorRepository platformOperators)
    {
        _refreshTokens = refreshTokens;
        _users = users;
        _roles = roles;
        _auditLogs = auditLogs;
        _tokenService = tokenService;
        _platformOperators = platformOperators;
    }

    public async Task<Result<AuthResponse>> Handle(RefreshTokenCommand command, CancellationToken cancellationToken)
    {
        var tokenHash = _tokenService.HashRefreshToken(command.RefreshToken);
        var stored = await _refreshTokens.GetByHashAsync(tokenHash, cancellationToken);

        if (stored is null)
        {
            return Error.Unauthorized("Invalid refresh token.");
        }

        if (stored.RevokedAt is not null)
        {
            await _refreshTokens.RevokeFamilyAsync(stored.FamilyId, stored.Id, cancellationToken);
            return Error.Unauthorized("Refresh token was already used. Session revoked.");
        }

        if (stored.ExpiresAt <= DateTime.UtcNow)
        {
            stored.Revoke();
            return Error.Unauthorized("Refresh token has expired.");
        }

        var user = await _users.GetByIdWithRolesAsync(stored.TenantId, stored.UserId, cancellationToken);
        if (user is null || !user.IsActive)
        {
            return Error.Unauthorized("User no longer exists or is deactivated.");
        }

        var permissions = await GetPermissionsAsync(user, cancellationToken);

        var platformOp = await _platformOperators.GetByUserIdAsync(user.Id, cancellationToken);
        var platformRole = platformOp is { IsActive: true } ? platformOp.Role.ToString() : null;

        IDictionary<string, string>? additionalClaims = null;
        if (platformRole is not null)
        {
            additionalClaims = new Dictionary<string, string>
            {
                ["platform_role"] = platformRole
            };
        }

        var accessToken = _tokenService.GenerateAccessToken(user.Id, user.TenantId, user.Email, permissions, additionalClaims);
        var rawRefreshToken = _tokenService.GenerateRefreshToken();

        var replacement = RefreshToken.Create(
            user.Id,
            user.TenantId,
            _tokenService.HashRefreshToken(rawRefreshToken),
            DateTime.UtcNow.AddDays(AuthConstants.RefreshTokenDays));

        stored.Revoke(replacement.Id);
        await _refreshTokens.AddAsync(replacement, cancellationToken);

        await _auditLogs.AddAsync(AuditLog.Create(
            user.TenantId,
            user.Id,
            "Auth.Refresh",
            "User",
            user.Id.ToString()),
            cancellationToken);

        var response = new AuthResponse(
            accessToken,
            rawRefreshToken,
            DateTime.UtcNow.AddMinutes(AuthConstants.AccessTokenMinutes),
            new UserDto(user.Id, user.TenantId, user.Email, user.FullName, user.Phone, user.IsActive, user.EmailVerified, permissions)
            {
                TwoFactorEnabled = user.TwoFactorEnabled,
                PlatformRole = platformRole,
            });

        return Result.Success(response);
    }

    private async Task<IReadOnlyList<string>> GetPermissionsAsync(User user, CancellationToken cancellationToken)
    {
        var roleIds = user.Roles.Select(r => r.Id).ToArray();
        if (roleIds.Length == 0)
        {
            return Array.Empty<string>();
        }

        var permissions = new List<string>();
        foreach (var roleId in roleIds)
        {
            permissions.AddRange(await _roles.GetPermissionsAsync(user.TenantId, roleId, cancellationToken));
        }

        return permissions.Distinct().ToArray();
    }
}
