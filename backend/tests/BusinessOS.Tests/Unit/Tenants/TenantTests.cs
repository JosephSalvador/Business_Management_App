using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Tenants;

namespace BusinessOS.Tests.Unit.Tenants;

public sealed class TenantTests
{
    [Fact]
    public void Create_DefaultsCurrencyToTzs()
    {
        var tenant = Tenant.Create(Guid.NewGuid(), "Acme Ltd");

        Assert.Equal("TZS", tenant.Currency);
        Assert.True(tenant.IsActive);
    }

    [Fact]
    public void UpdateProfile_SetsAllFieldsAndTrimsName()
    {
        var tenant = Tenant.Create(Guid.NewGuid(), "Acme Ltd");

        tenant.UpdateProfile(" Acme Ltd. ", "info@acme.local", "255700000000", "Plot 2, Dar", "TIN-123");

        Assert.Equal("Acme Ltd.", tenant.Name);
        Assert.Equal("info@acme.local", tenant.ContactEmail);
        Assert.Equal("255700000000", tenant.ContactPhone);
        Assert.Equal("Plot 2, Dar", tenant.Address);
        Assert.Equal("TIN-123", tenant.TaxId);
    }

    [Fact]
    public void NewPermissions_ArePartOfAll()
    {
        Assert.Contains(PermissionNames.OrganizationsView, PermissionNames.All);
        Assert.Contains(PermissionNames.OrganizationsManage, PermissionNames.All);
        Assert.Contains(PermissionNames.BranchesView, PermissionNames.All);
        Assert.Contains(PermissionNames.BranchesCreate, PermissionNames.All);
        Assert.Contains(PermissionNames.BranchesUpdate, PermissionNames.All);
        Assert.Contains(PermissionNames.BranchesDelete, PermissionNames.All);
    }
}
