using BusinessOS.Application.Features.Auth.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Domain.Identity;
using BusinessOS.Shared;
using MediatR;
using Microsoft.Extensions.Options;
using BusinessOS.Shared.Configuration;

namespace BusinessOS.Application.Features.Auth.Commands;

public sealed record LoginCommand(string Email, string Password) : IRequest<Result<AuthResponse>>;

public sealed class LoginCommandHandler : IRequestHandler<LoginCommand, Result<AuthResponse>>
{
    private readonly IUserRepository _users;
    private readonly IRoleRepository _roles;
    private readonly IRefreshTokenRepository _refreshTokens;
    private readonly IAuditLogRepository _auditLogs;
    private readonly IPasswordHasher _passwordHasher;
    private readonly ITokenService _tokenService;
    private readonly SecurityOptions _security;

    public LoginCommandHandler(
        IUserRepository users,
        IRoleRepository roles,
        IRefreshTokenRepository refreshTokens,
        IAuditLogRepository auditLogs,
        IPasswordHasher passwordHasher,
        ITokenService tokenService,
        IOptions<SecurityOptions> security)
    {
        _users = users;
        _roles = roles;
        _refreshTokens = refreshTokens;
        _auditLogs = auditLogs;
        _passwordHasher = passwordHasher;
        _tokenService = tokenService;
        _security = security.Value;
    }

    public async Task<Result<AuthResponse>> Handle(LoginCommand command, CancellationToken cancellationToken)
    {
        var normalizedEmail = command.Email.Trim().ToLowerInvariant();
        var user = await _users.GetByEmailAsync(normalizedEmail, cancellationToken);

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

        user.ResetFailedLogins();

        var permissions = await GetPermissionsAsync(user, cancellationToken);
        var accessToken = _tokenService.GenerateAccessToken(user.Id, user.TenantId, user.Email, permissions);
        var rawRefreshToken = _tokenService.GenerateRefreshToken();

        await _refreshTokens.AddAsync(RefreshToken.Create(
            user.Id,
            user.TenantId,
            _tokenService.HashRefreshToken(rawRefreshToken),
            DateTime.UtcNow.AddDays(AuthConstants.RefreshTokenDays)),
            cancellationToken);

        await _auditLogs.AddAsync(AuditLog.Create(
            user.TenantId,
            user.Id,
            "Auth.Login",
            "User",
            user.Id.ToString()),
            cancellationToken);

        var response = new AuthResponse(
            accessToken,
            rawRefreshToken,
            DateTime.UtcNow.AddMinutes(AuthConstants.AccessTokenMinutes),
            new UserDto(user.Id, user.TenantId, user.Email, user.FullName, user.Phone, user.IsActive, user.EmailVerified, permissions));

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
            permissions.AddRange(await _roles.GetPermissionsAsync(roleId, cancellationToken));
        }

        return permissions.Distinct().ToArray();
    }
}
