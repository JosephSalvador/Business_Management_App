using BusinessOS.Domain.Events;
using BusinessOS.Domain.Identity;

namespace BusinessOS.Tests.Unit.Identity;

public sealed class RoleTests
{
    private static readonly Guid TenantId = Guid.NewGuid();

    private static Permission Perm(string name) => Permission.Seed(name);

    [Fact]
    public void Grant_IsIdempotent_DoesNotDuplicatePermissions()
    {
        var role = Role.Create(TenantId, "Manager");
        var view = Perm("Users.View");

        role.Grant(new[] { view });
        role.Grant(new[] { view });

        Assert.Single(role.Permissions);
        Assert.Equal("Users.View", Assert.Single(role.Permissions).Name);
    }

    [Fact]
    public void Grant_AddsEachPermissionOnce()
    {
        var role = Role.Create(TenantId, "Manager");

        role.Grant(new[]
        {
            Perm("Users.View"),
            Perm("Users.Create"),
            Perm("Users.View"),
        });

        Assert.Equal(2, role.Permissions.Count);
        Assert.Contains(role.Permissions, p => p.Name == "Users.View");
        Assert.Contains(role.Permissions, p => p.Name == "Users.Create");
    }

    [Fact]
    public void Grant_EmptyCollection_IsANoOp()
    {
        var role = Role.Create(TenantId, "Manager");

        role.Grant(Array.Empty<Permission>());

        Assert.Empty(role.Permissions);
    }

    [Fact]
    public void SetPermissions_ReplacesExistingPermissionsAndRaisesEvent()
    {
        var role = Role.Create(TenantId, "Manager");
        role.Grant(new[] { Perm("Users.View") });

        role.SetPermissions(new[] { Perm("Inventory.View") });

        Assert.Equal("Inventory.View", Assert.Single(role.Permissions).Name);
        var changed = Assert.Single(role.DomainEvents.OfType<RolePermissionsChangedEvent>());
        Assert.Equal(new[] { "Inventory.View" }, changed.PermissionNames);
    }

    [Fact]
    public void SetPermissions_ClearsToEmpty()
    {
        var role = Role.Create(TenantId, "Manager");
        role.Grant(new[] { Perm("Users.View") });

        role.SetPermissions(Array.Empty<Permission>());

        Assert.Empty(role.Permissions);
        var changed = Assert.Single(role.DomainEvents.OfType<RolePermissionsChangedEvent>());
        Assert.Empty(changed.PermissionNames);
    }

    [Fact]
    public void Rename_UpdatesNameAndDescriptionAndRaisesEvent()
    {
        var role = Role.Create(TenantId, "Cashier", description: "Old");

        role.Rename("Senior Cashier", "New description");

        Assert.Equal("Senior Cashier", role.Name);
        Assert.Equal("New description", role.Description);
        var updated = Assert.Single(role.DomainEvents.OfType<RoleUpdatedEvent>());
        Assert.Equal("Senior Cashier", updated.Name);
    }

    [Fact]
    public void Delete_RaisesDeletedEvent()
    {
        var role = Role.Create(TenantId, "Manager");

        role.Delete();

        var deleted = Assert.Single(role.DomainEvents.OfType<RoleDeletedEvent>());
        Assert.Equal(role.Id, deleted.RoleId);
        Assert.Equal("Manager", deleted.Name);
    }
}
