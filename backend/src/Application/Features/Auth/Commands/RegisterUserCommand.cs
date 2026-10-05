using BusinessOS.Application.Features.Auth.Dtos;
using BusinessOS.Application.Features.Auth.Services;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Domain.Billing;
using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Tenants;
using BusinessOS.Shared;
using BusinessOS.Shared.Configuration;
using MediatR;
using Microsoft.Extensions.Options;

namespace BusinessOS.Application.Features.Auth.Commands;

public sealed record RegisterUserCommand(
    string Email,
    string Password,
    string FullName,
    string Phone,
    string? OrganizationName) : IRequest<Result<UserDto>>;

public sealed class RegisterUserCommandHandler : IRequestHandler<RegisterUserCommand, Result<UserDto>>
{
    private readonly ITenantRepository _tenants;
    private readonly IBranchRepository _branches;
    private readonly IRoleRepository _roles;
    private readonly IPermissionRepository _permissions;
    private readonly IUserRepository _users;
    private readonly IAuditLogRepository _auditLogs;
    private readonly ISubscriptionRepository _subscriptions;
    private readonly IPasswordHasher _passwordHasher;
    private readonly EmailVerificationService _verification;
    private readonly IOptions<PaymentsOptions> _paymentsOptions;

    public RegisterUserCommandHandler(
        ITenantRepository tenants,
        IBranchRepository branches,
        IRoleRepository roles,
        IPermissionRepository permissions,
        IUserRepository users,
        IAuditLogRepository auditLogs,
        ISubscriptionRepository subscriptions,
        IPasswordHasher passwordHasher,
        EmailVerificationService verification,
        IOptions<PaymentsOptions> paymentsOptions)
    {
        _tenants = tenants;
        _branches = branches;
        _roles = roles;
        _permissions = permissions;
        _users = users;
        _auditLogs = auditLogs;
        _subscriptions = subscriptions;
        _passwordHasher = passwordHasher;
        _verification = verification;
        _paymentsOptions = paymentsOptions;
    }

    public async Task<Result<UserDto>> Handle(RegisterUserCommand command, CancellationToken cancellationToken)
    {
        var normalizedEmail = command.Email.Trim().ToLowerInvariant();
        var phone = PhoneNumber.Normalize(command.Phone);
        if (phone is null)
        {
            return Error.Validation("Phone number is not valid.");
        }

        if (await _users.GetByEmailAsync(normalizedEmail, cancellationToken) is not null)
        {
            return Error.Conflict("Email is already registered.");
        }

        if (await _users.GetByPhoneAsync(phone, cancellationToken) is not null)
        {
            return Error.Conflict("Phone number is already registered.");
        }

        var tenantId = Guid.NewGuid();

        string tenantName;
        if (string.IsNullOrWhiteSpace(command.OrganizationName))
        {
            tenantName = BuildPlaceholderTenantName(command.FullName, tenantId);
        }
        else
        {
            tenantName = command.OrganizationName.Trim();
            if (await _tenants.GetByNameAsync(tenantName, cancellationToken) is not null)
            {
                return Error.Conflict("The business name is already in use.");
            }
        }

        var tenant = Tenant.Create(tenantId, tenantName, _paymentsOptions.Value.Currency);
        await _tenants.AddAsync(tenant, cancellationToken);

        await _branches.AddAsync(Branch.Create(
            tenant.Id,
            Branch.DefaultName,
            Branch.DefaultCode,
            tenant.Currency),
            cancellationToken);

        var adminRole = Role.Create(tenant.Id, SystemRoles.Administrator, isSystem: true);
        var allPermissions = await _permissions.ResolveByNamesAsync(PermissionNames.All, cancellationToken);
        adminRole.Grant(allPermissions);
        await _roles.AddAsync(adminRole, cancellationToken);

        var staffPermissions = await _permissions.ResolveByNamesAsync(PermissionNames.Staff, cancellationToken);
        var staffRole = Role.Create(
            tenant.Id,
            SystemRoles.Staff,
            isSystem: true,
            description: "Fanyakazi — catalogue, stock na POS");
        staffRole.Grant(staffPermissions);
        await _roles.AddAsync(staffRole, cancellationToken);

        foreach (var template in RoleTemplates.Starter)
        {
            var role = Role.Create(tenant.Id, template.Name, description: template.Description);
            var permissions = await _permissions.ResolveByNamesAsync(template.PermissionNames, cancellationToken);
            role.Grant(permissions);
            await _roles.AddAsync(role, cancellationToken);
        }

        var user = User.Create(
            Guid.NewGuid(),
            tenant.Id,
            normalizedEmail,
            _passwordHasher.Hash(command.Password),
            command.FullName.Trim(),
            phone);
        user.AssignRole(adminRole);
        await _users.AddAsync(user, cancellationToken);

        // Free 14-day Pro trial starts at registration (M13 monetization).
        await _subscriptions.AddAsync(
            Subscription.StartTrial(tenant.Id), cancellationToken);

        // No session is issued until the email address is verified.
        await _verification.IssueAsync(user, cancellationToken);

        await _auditLogs.AddAsync(AuditLog.Create(
            tenant.Id,
            user.Id,
            "Auth.Register",
            "Tenant",
            tenant.Id.ToString(),
            System.Text.Json.JsonSerializer.Serialize(new { organization = tenant.Name, email = user.Email })),
            cancellationToken);

        return Result.Success(new UserDto(
            user.Id,
            tenant.Id,
            user.Email,
            user.FullName,
            user.Phone,
            user.IsActive,
            user.EmailVerified,
            PermissionNames.All));
    }

    /// <summary>
    /// Merchants who have not chosen a business name still get a tenant so the
    /// platform model holds; they rename it later from Settings. The id suffix
    /// keeps names unique because Tenant.Name is globally unique.
    /// </summary>
    private static string BuildPlaceholderTenantName(string fullName, Guid tenantId)
    {
        var firstName = fullName.Trim().Split(' ', StringSplitOptions.RemoveEmptyEntries)
            .FirstOrDefault() ?? "Mfanyabiashara";
        var suffix = $" #{tenantId.ToString("N")[..4]}";
        const int maxLength = 200;
        var baseName = $"Biashara ya {firstName}";
        if (baseName.Length > maxLength - suffix.Length)
        {
            baseName = baseName[..(maxLength - suffix.Length)];
        }

        return baseName + suffix;
    }
}
