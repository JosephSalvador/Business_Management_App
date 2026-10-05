using BusinessOS.Application.Features.Auth.Dtos;
using BusinessOS.Application.Features.Auth.Services;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Audit;
using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Tenants;
using BusinessOS.Shared;
using BusinessOS.Shared.Configuration;
using MediatR;
using Microsoft.Extensions.Options;

namespace BusinessOS.Application.Features.Auth.Commands;

public sealed record RegisterStaffCommand(
    string Email,
    string Password,
    string FullName,
    string Phone,
    string InvitationCode) : IRequest<Result<UserDto>>;

/// <summary>
/// Registers a staff member who redeems an owner-issued invitation code. Unlike
/// RegisterUserCommand this does NOT create a new tenant or an Administrator —
/// the user is attached to the code's tenant with the system Staff role and made
/// active immediately (the code itself is the owner's approval). An email
/// verification code is issued as usual; no session is granted until verified.
/// </summary>
public sealed class RegisterStaffCommandHandler : IRequestHandler<RegisterStaffCommand, Result<UserDto>>
{
    private readonly ITenantRepository _tenants;
    private readonly IBranchRepository _branches;
    private readonly IRoleRepository _roles;
    private readonly IPermissionRepository _permissions;
    private readonly IInvitationCodeRepository _invitations;
    private readonly IUserRepository _users;
    private readonly IAuditLogRepository _auditLogs;
    private readonly IPasswordHasher _passwordHasher;
    private readonly EmailVerificationService _verification;
    private readonly SecurityOptions _security;

    public RegisterStaffCommandHandler(
        ITenantRepository tenants,
        IBranchRepository branches,
        IRoleRepository roles,
        IPermissionRepository permissions,
        IInvitationCodeRepository invitations,
        IUserRepository users,
        IAuditLogRepository auditLogs,
        IPasswordHasher passwordHasher,
        EmailVerificationService verification,
        IOptions<SecurityOptions> security)
    {
        _tenants = tenants;
        _branches = branches;
        _roles = roles;
        _permissions = permissions;
        _invitations = invitations;
        _users = users;
        _auditLogs = auditLogs;
        _passwordHasher = passwordHasher;
        _verification = verification;
        _security = security.Value;
    }

    public async Task<Result<UserDto>> Handle(
        RegisterStaffCommand command, CancellationToken cancellationToken)
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

        var invitation = await _invitations.GetActiveByCodeHashAsync(
            CodeHasher.Hash(command.InvitationCode), cancellationToken);
        if (invitation is null)
        {
            return Error.Validation(new Dictionary<string, string[]>
            {
                ["InvitationCode"] = new[] { "This invitation code is not valid." },
            });
        }

        var tenant = await _tenants.GetByIdAsync(invitation.TenantId, cancellationToken);
        if (tenant is null)
        {
            return Error.Validation(new Dictionary<string, string[]>
            {
                ["InvitationCode"] = new[] { "This invitation code is not valid." },
            });
        }

        if (tenant.OnboardingCompletedAt is null)
        {
            return Error.Validation(new Dictionary<string, string[]>
            {
                ["InvitationCode"] = new[] { "This business has not completed setup yet." },
            });
        }

        // New tenants receive Staff during registration. The fallback keeps the
        // invitation flow compatible with tenants created before starter roles.
        var staffRole = await _roles.GetByNameAsync(tenant.Id, SystemRoles.Staff, cancellationToken);
        if (staffRole is null)
        {
            var permissions = await _permissions.ResolveByNamesAsync(
                PermissionNames.Staff, cancellationToken);
            staffRole = Role.Create(tenant.Id, SystemRoles.Staff, isSystem: true, description: "Fanyakazi — catalogue, stock na POS");
            staffRole.Grant(permissions);
            await _roles.AddAsync(staffRole, cancellationToken);
        }

        var hq = await _branches.GetByCodeAsync(tenant.Id, Branch.DefaultCode, cancellationToken);

        var user = User.CreateManaged(
            Guid.NewGuid(),
            tenant.Id,
            normalizedEmail,
            _passwordHasher.Hash(command.Password),
            command.FullName.Trim(),
            phone);
        user.AssignRole(staffRole);
        if (hq is not null)
        {
            user.AssignBranches(
                new[] { new UserBranchAssignment(hq.Id, IsDefault: true) },
                assignedBy: tenant.Id,
                assignedAt: DateTime.UtcNow);
        }

        if (!invitation.TryConsume())
        {
            return Error.Validation(new Dictionary<string, string[]>
            {
                ["InvitationCode"] = new[] { "This invitation code has already been used or expired." },
            });
        }

        await _users.AddAsync(user, cancellationToken);

        await _verification.IssueAsync(user, cancellationToken);

        await _auditLogs.AddAsync(AuditLog.Create(
            tenant.Id,
            user.Id,
            "Auth.RegisterStaff",
            "User",
            user.Id.ToString(),
            System.Text.Json.JsonSerializer.Serialize(new { tenant = tenant.Name, email = user.Email })));

        return Result.Success(new UserDto(
            user.Id,
            tenant.Id,
            user.Email,
            user.FullName,
            user.Phone,
            user.IsActive,
            user.EmailVerified,
            PermissionNames.Staff));
    }
}
