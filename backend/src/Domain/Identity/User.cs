using BusinessOS.Domain.Events;
using BusinessOS.Shared.Entities;
namespace BusinessOS.Domain.Identity;

public sealed class User : AggregateRoot
{
    private readonly List<Role> _roles = new();
    private readonly List<UserBranch> _branches = new();

    private User(Guid id, Guid tenantId, string email, string passwordHash, string fullName, string? phone)
        : base(id)
    {
        TenantId = tenantId;
        Email = email;
        PasswordHash = passwordHash;
        FullName = fullName;
        Phone = phone;
    }

    public Guid TenantId { get; private set; }
    public string Email { get; private set; }
    public string PasswordHash { get; private set; }
    public string FullName { get; private set; }
    public string? Phone { get; private set; }
    public bool IsActive { get; private set; } = true;
    public bool EmailVerified { get; private set; }
    public int FailedLoginCount { get; private set; }
    public DateTime? LockoutEnd { get; private set; }
    public bool TwoFactorEnabled { get; private set; }
    public string? TwoFactorSecret { get; private set; }
    public string? TwoFactorPendingSecret { get; private set; }
    public DateTime? TwoFactorEnabledAt { get; private set; }
    public IReadOnlyCollection<Role> Roles => _roles.AsReadOnly();
    public IReadOnlyCollection<UserBranch> Branches => _branches.AsReadOnly();
    public Guid? DefaultBranchId => _branches.FirstOrDefault(b => b.IsDefault)?.BranchId;

    public static User Create(Guid id, Guid tenantId, string email, string passwordHash, string fullName, string? phone)
    {
        var user = new User(id, tenantId, email, passwordHash, fullName, phone);
        user.AddDomainEvent(new UserRegisteredEvent(
            Guid.NewGuid(), DateTime.UtcNow, user.Id, tenantId, email, fullName));
        return user;
    }

    public static User CreateManaged(Guid id, Guid tenantId, string email, string passwordHash, string fullName, string? phone)
    {
        var user = new User(id, tenantId, email, passwordHash, fullName, phone);
        user.AddDomainEvent(new UserCreatedEvent(
            Guid.NewGuid(), DateTime.UtcNow, user.Id, tenantId, email, fullName));
        return user;
    }

    public void AssignRole(Role role)
    {
        if (!_roles.Any(r => r.Id == role.Id))
        {
            _roles.Add(role);
        }
    }

    public void SetRoles(IEnumerable<Role> roles)
    {
        var assigned = roles.ToList();
        if (assigned.Count == _roles.Count && _roles.All(r => assigned.Any(a => a.Id == r.Id)))
        {
            return;
        }

        _roles.Clear();
        _roles.AddRange(assigned);

        AddDomainEvent(new UserRolesChangedEvent(
            Guid.NewGuid(), DateTime.UtcNow, Id, TenantId, assigned.Select(r => r.Id).ToArray()));
    }

    public void AssignBranches(IEnumerable<UserBranchAssignment> assignments, Guid assignedBy, DateTime assignedAt)
    {
        var list = assignments.ToList();

        if (list.Count != list.Select(a => a.BranchId).Distinct().Count())
        {
            throw new ArgumentException("A branch cannot be assigned more than once.", nameof(assignments));
        }

        if (list.Count(a => a.IsDefault) > 1)
        {
            throw new ArgumentException("At most one branch can be the default.", nameof(assignments));
        }

        var unchanged = list.Count == _branches.Count
            && _branches.All(b => list.Any(a => a.BranchId == b.BranchId && a.IsDefault == b.IsDefault));
        if (unchanged)
        {
            return;
        }

        _branches.Clear();
        foreach (var assignment in list)
        {
            _branches.Add(UserBranch.Assign(TenantId, Id, assignment.BranchId, assignment.IsDefault, assignedBy, assignedAt));
        }

        AddDomainEvent(new UserBranchesChangedEvent(
            Guid.NewGuid(), DateTime.UtcNow, Id, TenantId,
            list.Select(a => a.BranchId).ToArray(),
            list.FirstOrDefault(a => a.IsDefault)?.BranchId));
    }

    public void UpdateProfile(string fullName, string? phone)
    {
        FullName = fullName.Trim();
        Phone = phone;

        AddDomainEvent(new UserProfileUpdatedEvent(
            Guid.NewGuid(), DateTime.UtcNow, Id, TenantId, FullName, Phone));
    }

    public void MarkEmailVerified()
    {
        if (EmailVerified)
        {
            return;
        }

        EmailVerified = true;
        AddDomainEvent(new UserEmailVerifiedEvent(
            Guid.NewGuid(), DateTime.UtcNow, Id, TenantId, Email));
    }

    public void Activate()
    {
        IsActive = true;
        AddDomainEvent(new UserStatusChangedEvent(
            Guid.NewGuid(), DateTime.UtcNow, Id, TenantId, IsActive));
    }

    public void Deactivate()
    {
        IsActive = false;
        AddDomainEvent(new UserStatusChangedEvent(
            Guid.NewGuid(), DateTime.UtcNow, Id, TenantId, IsActive));
    }

    public void ChangePassword(string passwordHash) => PasswordHash = passwordHash;

    public bool IsLockedOut => LockoutEnd is not null && LockoutEnd > DateTime.UtcNow;

    public void RegisterFailedLogin(int maxAttempts, TimeSpan lockoutDuration)
    {
        FailedLoginCount++;
        if (FailedLoginCount >= maxAttempts)
        {
            LockoutEnd = DateTime.UtcNow.Add(lockoutDuration);
            FailedLoginCount = 0;
        }
    }

    public void ResetFailedLogins()
    {
        FailedLoginCount = 0;
        LockoutEnd = null;
    }

    /// <summary>
    /// Holds an unconfirmed shared secret. Only a matching code from
    /// <see cref="ConfirmTwoFactor"/> can promote it to the active factor, so an
    /// unverified secret can never gate a login. Restaging replaces any earlier
    /// pending secret, which makes a re-run of setup safe.
    /// </summary>
    public void StageTwoFactor(string encryptedSecret)
    {
        TwoFactorPendingSecret = encryptedSecret;
    }

    public bool HasPendingTwoFactor => TwoFactorPendingSecret is not null;

    /// <summary>
    /// Promotes the staged secret to the active factor. Returns false when nothing is
    /// staged, so a confirm can never activate a secret the user never proved possession of.
    /// </summary>
    public bool ConfirmTwoFactor()
    {
        var secret = TwoFactorPendingSecret;
        if (string.IsNullOrEmpty(secret))
        {
            return false;
        }

        TwoFactorEnabled = true;
        TwoFactorSecret = secret;
        TwoFactorPendingSecret = null;
        TwoFactorEnabledAt = DateTime.UtcNow;

        AddDomainEvent(new UserTwoFactorEnabledEvent(
            Guid.NewGuid(), DateTime.UtcNow, Id, TenantId, TwoFactorEnabledAt.Value));
        return true;
    }

    /// <summary>
    /// Removes the second factor entirely: flag, secret, pending secret and activation
    /// timestamp. Recovery codes are cleared by the caller in the same mutation, since
    /// they are separate rows rather than user state.
    /// </summary>
    public void DisableTwoFactor()
    {
        if (!TwoFactorEnabled && TwoFactorSecret is null && TwoFactorPendingSecret is null)
        {
            return;
        }

        TwoFactorEnabled = false;
        TwoFactorSecret = null;
        TwoFactorPendingSecret = null;
        TwoFactorEnabledAt = null;

        AddDomainEvent(new UserTwoFactorDisabledEvent(
            Guid.NewGuid(), DateTime.UtcNow, Id, TenantId));
    }
}
