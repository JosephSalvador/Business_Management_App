using BusinessOS.Domain.Events;
using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Identity;

public sealed class User : AggregateRoot
{
    private readonly List<Role> _roles = new();

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
    public IReadOnlyCollection<Role> Roles => _roles.AsReadOnly();

    public static User Create(Guid id, Guid tenantId, string email, string passwordHash, string fullName, string? phone)
    {
        var user = new User(id, tenantId, email, passwordHash, fullName, phone);
        user.AddDomainEvent(new UserRegisteredEvent(
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

    public void MarkEmailVerified() => EmailVerified = true;

    public void Activate() => IsActive = true;

    public void Deactivate() => IsActive = false;

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
}
