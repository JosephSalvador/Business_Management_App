using BusinessOS.Application.Features.Auth.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Services;

namespace BusinessOS.Application.Features.Auth.Services;

/// <summary>
/// Turns an authenticated user into a session: permission resolution, token minting, the
/// refresh-token row that backs the device list, and the audit entry. Both the plain login
/// path and the post-challenge path go through here, so a session looks identical however
/// the user proved who they are.
/// </summary>
public sealed class AuthSessionIssuer
{
    private readonly IRoleRepository _roles;
    private readonly IRefreshTokenRepository _refreshTokens;
    private readonly IAuditLogRepository _auditLogs;
    private readonly ITokenService _tokenService;
    private readonly ITenantContext _tenantContext;

    public AuthSessionIssuer(
        IRoleRepository roles,
        IRefreshTokenRepository refreshTokens,
        IAuditLogRepository auditLogs,
        ITokenService tokenService,
        ITenantContext tenantContext)
    {
        _roles = roles;
        _refreshTokens = refreshTokens;
        _auditLogs = auditLogs;
        _tokenService = tokenService;
        _tenantContext = tenantContext;
    }

    public async Task<AuthResponse> IssueAsync(User user, CancellationToken cancellationToken)
    {
        var permissions = await GetPermissionsAsync(user, cancellationToken);
        var accessToken = _tokenService.GenerateAccessToken(user.Id, user.TenantId, user.Email, permissions);
        var rawRefreshToken = _tokenService.GenerateRefreshToken();
        await _refreshTokens.AddAsync(RefreshToken.Create(
            user.Id,
            user.TenantId,
            _tokenService.HashRefreshToken(rawRefreshToken),
            DateTime.UtcNow.AddDays(AuthConstants.RefreshTokenDays),
            DeviceLabel.FromUserAgent(_tenantContext.UserAgent),
            _tenantContext.IpAddress,
            Truncate(_tenantContext.UserAgent)),
            cancellationToken);

        await _auditLogs.AddAsync(AuditLog.Create(
            user.TenantId,
            user.Id,
            "Auth.Login",
            "User",
            user.Id.ToString()),
            cancellationToken);

        return new AuthResponse(
            accessToken,
            rawRefreshToken,
            DateTime.UtcNow.AddMinutes(AuthConstants.AccessTokenMinutes),
            new UserDto(
                user.Id, user.TenantId, user.Email, user.FullName, user.Phone,
                user.IsActive, user.EmailVerified, permissions)
            {
                TwoFactorEnabled = user.TwoFactorEnabled,
            });
    }

    private async Task<IReadOnlyList<string>> GetPermissionsAsync(User user, CancellationToken cancellationToken)
    {
        var roleIds = user.Roles.Select(r => r.Id).ToArray();
        if (roleIds.Length == 0)
        {
            return [];
        }

        var permissions = new List<string>();
        foreach (var roleId in roleIds)
        {
            permissions.AddRange(await _roles.GetPermissionsAsync(user.TenantId, roleId, cancellationToken));
        }

        return permissions.Distinct().ToArray();
    }

    private static string? Truncate(string? value)
        => string.IsNullOrWhiteSpace(value) ? null : value.Length > 400 ? value[..400] : value;
}
