using BusinessOS.Domain.Events;
using BusinessOS.Domain.Identity;

namespace BusinessOS.Tests.Unit.Identity;

public sealed class UserBranchTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly Guid AssignedBy = Guid.NewGuid();
    private static readonly DateTime AssignedAt = new(2026, 8, 1, 0, 0, 0, DateTimeKind.Utc);

    private static User CreateUser() => User.CreateManaged(
        Guid.NewGuid(), TenantId, $"user-{Guid.NewGuid():N}@test.local", "hash", "Test User", phone: null);

    private static UserBranchAssignment Assignment(Guid branchId, bool isDefault = false)
        => new(branchId, isDefault);

    [Fact]
    public void AssignBranches_RejectsDuplicateBranchAssignment()
    {
        var user = CreateUser();
        var branchId = Guid.NewGuid();

        Assert.Throws<ArgumentException>(() =>
            user.AssignBranches(
                new[] { Assignment(branchId), Assignment(branchId) },
                AssignedBy,
                AssignedAt));
    }

    [Fact]
    public void AssignBranches_RejectsMoreThanOneDefault()
    {
        var user = CreateUser();

        Assert.Throws<ArgumentException>(() =>
            user.AssignBranches(
                new[] { Assignment(Guid.NewGuid(), isDefault: true), Assignment(Guid.NewGuid(), isDefault: true) },
                AssignedBy,
                AssignedAt));
    }

    [Fact]
    public void AssignBranches_SetsSingleDefaultAndExposesDefaultBranchId()
    {
        var user = CreateUser();
        var hq = Guid.NewGuid();
        var branch = Guid.NewGuid();

        user.AssignBranches(
            new[] { Assignment(hq, isDefault: true), Assignment(branch) },
            AssignedBy,
            AssignedAt);

        Assert.Equal(2, user.Branches.Count);
        Assert.Equal(hq, user.DefaultBranchId);
        Assert.Single(user.Branches, b => b.IsDefault);
        Assert.Equal(AssignedBy, user.Branches.Single(b => b.IsDefault).AssignedBy);
    }

    [Fact]
    public void AssignBranches_ReplacementRemovesStaleChildren()
    {
        var user = CreateUser();
        var hq = Guid.NewGuid();
        var branch = Guid.NewGuid();

        user.AssignBranches(new[] { Assignment(hq, isDefault: true) }, AssignedBy, AssignedAt);
        user.AssignBranches(new[] { Assignment(branch, isDefault: true) }, AssignedBy, AssignedAt);

        Assert.Single(user.Branches);
        Assert.Equal(branch, user.Branches.Single().BranchId);
        Assert.Equal(branch, user.DefaultBranchId);
    }

    [Fact]
    public void AssignBranches_DefaultCanMoveBetweenBranches()
    {
        var user = CreateUser();
        var hq = Guid.NewGuid();
        var branch = Guid.NewGuid();

        user.AssignBranches(new[] { Assignment(hq), Assignment(branch, isDefault: true) }, AssignedBy, AssignedAt);
        Assert.Equal(branch, user.DefaultBranchId);

        user.AssignBranches(new[] { Assignment(hq, isDefault: true), Assignment(branch) }, AssignedBy, AssignedAt);

        Assert.Equal(hq, user.DefaultBranchId);
        Assert.Single(user.Branches, b => b.IsDefault);
    }

    [Fact]
    public void AssignBranches_IdenticalAssignmentIsANoOpAndRaisesNoEvent()
    {
        var user = CreateUser();
        var hq = Guid.NewGuid();
        var branch = Guid.NewGuid();
        var assignments = new[] { Assignment(hq, isDefault: true), Assignment(branch) };

        user.AssignBranches(assignments, AssignedBy, AssignedAt);
        user.AssignBranches(assignments, AssignedBy, AssignedAt);

        Assert.Single(user.DomainEvents.OfType<UserBranchesChangedEvent>());
        Assert.Equal(2, user.Branches.Count);
    }

    [Fact]
    public void AssignBranches_EmptyToEmptyIsANoOp()
    {
        var user = CreateUser();

        user.AssignBranches(Array.Empty<UserBranchAssignment>(), AssignedBy, AssignedAt);

        Assert.Empty(user.DomainEvents.OfType<UserBranchesChangedEvent>());
    }

    [Fact]
    public void AssignBranches_ChangeRaisesBranchesChangedEvent()
    {
        var user = CreateUser();
        var branch = Guid.NewGuid();

        user.AssignBranches(new[] { Assignment(branch, isDefault: true) }, AssignedBy, AssignedAt);

        var created = Assert.Single(user.DomainEvents.OfType<UserBranchesChangedEvent>());
        Assert.Equal(branch, Assert.Single(created.BranchIds));
        Assert.Equal(branch, created.DefaultBranchId);
    }

    [Fact]
    public void SetRoles_IdenticalRolesIsANoOpAndRaisesNoEvent()
    {
        var user = CreateUser();
        var roles = new[] { Role.Create(TenantId, "Cashier"), Role.Create(TenantId, "Manager") };

        user.SetRoles(roles);
        user.SetRoles(roles);

        Assert.Single(user.DomainEvents.OfType<UserRolesChangedEvent>());
        Assert.Equal(2, user.Roles.Count);
    }

    [Fact]
    public void SetRoles_ReplacementChangesRolesAndRaisesEvent()
    {
        var user = CreateUser();
        var cashier = Role.Create(TenantId, "Cashier");
        var manager = Role.Create(TenantId, "Manager");

        user.SetRoles(new[] { cashier });
        user.SetRoles(new[] { manager });

        Assert.Equal(2, user.DomainEvents.OfType<UserRolesChangedEvent>().Count());
        Assert.Equal(manager.Id, Assert.Single(user.Roles).Id);
    }
}
