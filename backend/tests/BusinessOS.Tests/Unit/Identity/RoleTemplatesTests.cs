using BusinessOS.Domain.Identity;

namespace BusinessOS.Tests.Unit.Identity;

public sealed class RoleTemplatesTests
{
    [Fact]
    public void StarterRoles_AreEditableUniqueAndUseOnlyCatalogPermissions()
    {
        Assert.Equal(
            new[] { "Accountant", "Cashier", "Inventory Officer", "Manager" },
            RoleTemplates.Starter.Select(template => template.Name).OrderBy(name => name));

        foreach (var template in RoleTemplates.Starter)
        {
            Assert.NotEmpty(template.Description);
            Assert.NotEmpty(template.PermissionNames);
            Assert.Equal(template.PermissionNames.Count, template.PermissionNames.Distinct().Count());
            Assert.All(template.PermissionNames, permission => Assert.Contains(permission, PermissionNames.All));
            Assert.DoesNotContain(template.Name, new[] { SystemRoles.Administrator, SystemRoles.Staff });
        }
    }
}
