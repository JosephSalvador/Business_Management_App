using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Identity;

public enum PlatformRoleType
{
    None = 0,
    PlatformStaff = 1,
    PlatformSuperAdmin = 2
}

public sealed class PlatformOperator : AggregateRoot
{
    private PlatformOperator()
    {
    }

    private PlatformOperator(Guid id, Guid userId, PlatformRoleType role, Guid assignedBy)
        : base(id)
    {
        UserId = userId;
        Role = role;
        AssignedByUserId = assignedBy;
        AssignedAtUtc = DateTime.UtcNow;
        IsActive = true;
    }

    public Guid UserId { get; private set; }
    public PlatformRoleType Role { get; private set; }
    public bool IsActive { get; private set; } = true;
    public DateTime AssignedAtUtc { get; private set; }
    public Guid AssignedByUserId { get; private set; }

    public static PlatformOperator Create(Guid userId, PlatformRoleType role, Guid assignedBy)
    {
        if (role == PlatformRoleType.None)
        {
            throw new ArgumentException("A valid platform role must be assigned.", nameof(role));
        }

        return new PlatformOperator(Guid.NewGuid(), userId, role, assignedBy);
    }

    public void ChangeRole(PlatformRoleType newRole, Guid changedBy)
    {
        if (newRole == PlatformRoleType.None)
        {
            throw new ArgumentException("A valid platform role must be assigned.", nameof(newRole));
        }

        Role = newRole;
        AssignedByUserId = changedBy;
        AssignedAtUtc = DateTime.UtcNow;
    }

    public void Deactivate()
    {
        IsActive = false;
    }

    public void Reactivate()
    {
        IsActive = true;
    }
}
