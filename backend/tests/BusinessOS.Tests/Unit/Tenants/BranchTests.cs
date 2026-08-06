using BusinessOS.Domain.Events;
using BusinessOS.Domain.Tenants;

namespace BusinessOS.Tests.Unit.Tenants;

public sealed class BranchTests
{
    [Fact]
    public void Create_NormalizesCodeAndDefaultsToActive()
    {
        var tenantId = Guid.NewGuid();

        var branch = Branch.Create(tenantId, "  Dar es Salaam  ", "  ds m  ", "TZS");

        Assert.Equal("Dar es Salaam", branch.Name);
        Assert.Equal("DS M", branch.Code);
        Assert.True(branch.IsActive);
        Assert.Equal("TZS", branch.Currency);
        Assert.Equal(tenantId, branch.TenantId);
    }

    [Theory]
    [InlineData(" hq ", "HQ")]
    [InlineData("HQ", "HQ")]
    [InlineData("  dar es salaam  ", "DAR ES SALAAM")]
    public void NormalizeCode_TrimsAndUppercases(string input, string expected)
        => Assert.Equal(expected, Branch.NormalizeCode(input));

    [Fact]
    public void Create_RaisesBranchCreatedEvent()
    {
        var branch = Branch.Create(Guid.NewGuid(), "Head Office", "HQ", "TZS");

        var created = Assert.Single(branch.DomainEvents.OfType<BranchCreatedEvent>());
        Assert.Equal(branch.Id, created.BranchId);
        Assert.Equal(branch.Code, created.Code);
    }

    [Fact]
    public void UpdateProfile_ChangesFieldsAndRaisesUpdatedEvent()
    {
        var branch = Branch.Create(Guid.NewGuid(), "Head Office", "HQ", "TZS");

        branch.UpdateProfile(" Main Branch ", "Plot 1", "255700000000", "main@acme.local");

        Assert.Equal("Main Branch", branch.Name);
        Assert.Equal("Plot 1", branch.Address);
        Assert.Equal("255700000000", branch.Phone);
        Assert.Equal("main@acme.local", branch.Email);
        Assert.Single(branch.DomainEvents.OfType<BranchUpdatedEvent>());
    }

    [Fact]
    public void Deactivate_ThenActivate_RaisesStatusChangedEvents()
    {
        var branch = Branch.Create(Guid.NewGuid(), "Head Office", "HQ", "TZS");

        branch.Deactivate();
        Assert.False(branch.IsActive);

        branch.Activate();
        Assert.True(branch.IsActive);

        var statusEvents = branch.DomainEvents.OfType<BranchStatusChangedEvent>().ToList();
        Assert.Equal(2, statusEvents.Count);
        Assert.False(statusEvents[0].IsActive);
        Assert.True(statusEvents[1].IsActive);
    }
}
