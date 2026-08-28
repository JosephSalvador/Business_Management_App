using BusinessOS.Application.Features.Users.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Identity;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Users.Commands;

public sealed record CreateUserCommand(
    string Email,
    string Password,
    string FullName,
    string? Phone,
    IReadOnlyList<Guid>? RoleIds,
    IReadOnlyList<Guid>? BranchIds,
    Guid? DefaultBranchId) : IRequest<Result<IdentityUserDto>>;

public sealed class CreateUserCommandHandler : IRequestHandler<CreateUserCommand, Result<IdentityUserDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IUserRepository _users;
    private readonly IRoleRepository _roles;
    private readonly IBranchRepository _branches;
    private readonly IPasswordHasher _passwordHasher;

    public CreateUserCommandHandler(
        ITenantContext tenantContext,
        IUserRepository users,
        IRoleRepository roles,
        IBranchRepository branches,
        IPasswordHasher passwordHasher)
    {
        _tenantContext = tenantContext;
        _users = users;
        _roles = roles;
        _branches = branches;
        _passwordHasher = passwordHasher;
    }

    public async Task<Result<IdentityUserDto>> Handle(
        CreateUserCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var email = command.Email.Trim().ToLowerInvariant();
        var phone = PhoneNumber.Normalize(command.Phone);
        if (command.Phone is not null && phone is null)
        {
            return Error.Validation("Phone number is not valid.");
        }

        if (await _users.GetByEmailAsync(email, cancellationToken) is not null)
        {
            return Error.Conflict("Email is already registered.");
        }

        if (phone is not null && await _users.GetByPhoneAsync(phone, cancellationToken) is not null)
        {
            return Error.Conflict("Phone number is already registered.");
        }

        var roleIds = command.RoleIds?.Distinct().ToArray() ?? Array.Empty<Guid>();
        var roles = await _roles.GetManyByIdsAsync(tenantId, roleIds, cancellationToken);
        if (roles.Count != roleIds.Length)
        {
            return Error.Validation(new Dictionary<string, string[]>
            {
                ["RoleIds"] = new[] { "One or more roles do not exist in this tenant." },
            });
        }

        var branchIds = command.BranchIds?.Distinct().ToArray() ?? Array.Empty<Guid>();
        var branches = await _branches.ListByIdsAsync(tenantId, branchIds, cancellationToken);
        if (branches.Count != branchIds.Length)
        {
            return Error.Validation(new Dictionary<string, string[]>
            {
                ["BranchIds"] = new[] { "One or more branches do not exist in this tenant." },
            });
        }

        var user = User.CreateManaged(
            Guid.NewGuid(),
            tenantId,
            email,
            _passwordHasher.Hash(command.Password),
            command.FullName.Trim(),
            phone);

        foreach (var role in roles)
        {
            user.AssignRole(role);
        }

        if (branchIds.Length > 0)
        {
            user.AssignBranches(
                branchIds.Select(branchId => new UserBranchAssignment(branchId, branchId == command.DefaultBranchId)),
                assignedBy: _tenantContext.UserId ?? Guid.Empty,
                assignedAt: DateTime.UtcNow);
        }

        await _users.AddAsync(user, cancellationToken);
        return Result.Success(UserMappers.ToDto(user));
    }
}
