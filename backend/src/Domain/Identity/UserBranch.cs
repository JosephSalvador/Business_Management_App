using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Identity;

public sealed class UserBranch : Entity
{
    private UserBranch(Guid id, Guid tenantId, Guid userId, Guid branchId, bool isDefault, Guid assignedBy, DateTime assignedAt)
        : base(id)
    {
        TenantId = tenantId;
        UserId = userId;
        BranchId = branchId;
        IsDefault = isDefault;
        AssignedBy = assignedBy;
        AssignedAt = assignedAt;
    }

    public Guid TenantId { get; private set; }
    public Guid UserId { get; private set; }
    public Guid BranchId { get; private set; }
    public bool IsDefault { get; private set; }
    public Guid AssignedBy { get; private set; }
    public DateTime AssignedAt { get; private set; }

    internal static UserBranch Assign(Guid tenantId, Guid userId, Guid branchId, bool isDefault, Guid assignedBy, DateTime assignedAt)
        => new(Guid.Empty, tenantId, userId, branchId, isDefault, assignedBy, assignedAt);
}
