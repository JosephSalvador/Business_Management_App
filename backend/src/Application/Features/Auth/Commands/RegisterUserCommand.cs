using BusinessOS.Application.Features.Auth.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Tenants;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Auth.Commands;

public sealed record RegisterUserCommand(
    string Email,
    string Password,
    string FullName,
    string? Phone,
    string OrganizationName) : IRequest<Result<AuthResponse>>;

public sealed class RegisterUserCommandHandler : IRequestHandler<RegisterUserCommand, Result<AuthResponse>>
{
    private readonly ITenantRepository _tenants;
    private readonly IRoleRepository _roles;
    private readonly IUserRepository _users;
    private readonly IRefreshTokenRepository _refreshTokens;
    private readonly IAuditLogRepository _auditLogs;
    private readonly IPasswordHasher _passwordHasher;
    private readonly ITokenService _tokenService;

    public RegisterUserCommandHandler(
        ITenantRepository tenants,
        IRoleRepository roles,
        IUserRepository users,
        IRefreshTokenRepository refreshTokens,
        IAuditLogRepository auditLogs,
        IPasswordHasher passwordHasher,
        ITokenService tokenService)
    {
        _tenants = tenants;
        _roles = roles;
        _users = users;
        _refreshTokens = refreshTokens;
        _auditLogs = auditLogs;
        _passwordHasher = passwordHasher;
        _tokenService = tokenService;
    }

    public async Task<Result<AuthResponse>> Handle(RegisterUserCommand command, CancellationToken cancellationToken)
    {
        var normalizedEmail = command.Email.Trim().ToLowerInvariant();

        if (await _users.GetByEmailAsync(normalizedEmail, cancellationToken) is not null)
        {
            return Error.Conflict("Email is already registered.");
        }

        var tenant = Tenant.Create(Guid.NewGuid(), command.OrganizationName.Trim());
        await _tenants.AddAsync(tenant, cancellationToken);

        var adminRole = Role.Create(tenant.Id, "Administrator", isSystem: true);
        var allPermissions = await _roles.GetPermissionsByNamesAsync(PermissionNames.All, cancellationToken);
        adminRole.Grant(allPermissions);
        await _roles.AddAsync(adminRole, cancellationToken);

        var user = User.Create(
            Guid.NewGuid(),
            tenant.Id,
            normalizedEmail,
            _passwordHasher.Hash(command.Password),
            command.FullName.Trim(),
            command.Phone?.Trim());
        user.AssignRole(adminRole);
        await _users.AddAsync(user, cancellationToken);

        var rawRefreshToken = _tokenService.GenerateRefreshToken();
        await _refreshTokens.AddAsync(RefreshToken.Create(
            user.Id,
            tenant.Id,
            _tokenService.HashRefreshToken(rawRefreshToken),
            DateTime.UtcNow.AddDays(AuthConstants.RefreshTokenDays)),
            cancellationToken);

        await _auditLogs.AddAsync(AuditLog.Create(
            tenant.Id,
            user.Id,
            "Auth.Register",
            "Tenant",
            tenant.Id.ToString(),
            System.Text.Json.JsonSerializer.Serialize(new { organization = tenant.Name, email = user.Email })),
            cancellationToken);

        var permissions = PermissionNames.All;
        var accessToken = _tokenService.GenerateAccessToken(user.Id, tenant.Id, user.Email, permissions);

        var response = new AuthResponse(
            accessToken,
            rawRefreshToken,
            DateTime.UtcNow.AddMinutes(AuthConstants.AccessTokenMinutes),
            new UserDto(user.Id, tenant.Id, user.Email, user.FullName, user.Phone, user.IsActive, user.EmailVerified, permissions));

        return Result.Success(response);
    }
}
