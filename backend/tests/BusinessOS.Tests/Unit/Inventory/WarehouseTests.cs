using BusinessOS.Domain.Events;
using BusinessOS.Domain.Inventory;

namespace BusinessOS.Tests.Unit.Inventory;

public sealed class WarehouseTests
{
    [Fact]
    public void Create_TrimsNameNormalizesCodeAndAutoCreatesDefaultLocation()
    {
        var tenantId = Guid.NewGuid();
        var branchId = Guid.NewGuid();

        var warehouse = Warehouse.Create(tenantId, branchId, "  Main Store  ", "  ms-1  ");

        Assert.Equal("Main Store", warehouse.Name);
        Assert.Equal("MS-1", warehouse.Code);
        Assert.Equal(tenantId, warehouse.TenantId);
        Assert.Equal(branchId, warehouse.BranchId);
        Assert.True(warehouse.IsActive);

        var location = Assert.Single(warehouse.Locations);
        Assert.Equal(Warehouse.DefaultLocationCode, location.Code);
        Assert.Equal(Warehouse.DefaultLocationName, location.Name);
        Assert.Equal(warehouse.Id, location.WarehouseId);
    }

    [Theory]
    [InlineData(" hq ", "HQ")]
    [InlineData("ms-1", "MS-1")]
    [InlineData("  dar es salaam  ", "DAR ES SALAAM")]
    public void NormalizeCode_TrimsAndUppercases(string input, string expected)
        => Assert.Equal(expected, Warehouse.NormalizeCode(input));

    [Fact]
    public void Create_RaisesWarehouseCreatedEvent()
    {
        var warehouse = Warehouse.Create(Guid.NewGuid(), Guid.NewGuid(), "Head Office", "HQ");

        var created = Assert.Single(warehouse.DomainEvents.OfType<WarehouseCreatedEvent>());
        Assert.Equal(warehouse.Id, created.WarehouseId);
        Assert.Equal(warehouse.TenantId, created.TenantId);
        Assert.Equal(warehouse.BranchId, created.BranchId);
        Assert.Equal("HQ", created.Code);
    }

    [Fact]
    public void UpdateProfile_ChangesFieldsAndRaisesUpdatedEvent()
    {
        var warehouse = Warehouse.Create(Guid.NewGuid(), Guid.NewGuid(), "Head Office", "HQ");

        warehouse.UpdateProfile("  Main Store  ", "Downtown");

        Assert.Equal("Main Store", warehouse.Name);
        Assert.Equal("Downtown", warehouse.Description);
        Assert.Single(warehouse.DomainEvents.OfType<WarehouseUpdatedEvent>());
    }

    [Fact]
    public void Deactivate_ThenActivate_RaisesStatusChangedEvents()
    {
        var warehouse = Warehouse.Create(Guid.NewGuid(), Guid.NewGuid(), "Head Office", "HQ");

        warehouse.Deactivate();
        Assert.False(warehouse.IsActive);

        warehouse.Deactivate();
        Assert.Single(warehouse.DomainEvents.OfType<WarehouseStatusChangedEvent>());

        warehouse.Activate();
        Assert.True(warehouse.IsActive);

        var statusEvents = warehouse.DomainEvents.OfType<WarehouseStatusChangedEvent>().ToList();
        Assert.Equal(2, statusEvents.Count);
        Assert.False(statusEvents[0].IsActive);
        Assert.True(statusEvents[1].IsActive);
    }

    [Fact]
    public void SetLocations_ReplacesLocationsAndRaisesUpdatedEvent()
    {
        var warehouse = Warehouse.Create(Guid.NewGuid(), Guid.NewGuid(), "Main Store", "MS");

        warehouse.SetLocations(new[]
        {
            new StockLocationSpec(Guid.Empty, "A", "Zone A"),
            new StockLocationSpec(Guid.Empty, "b", "Zone B"),
        });

        Assert.Equal(2, warehouse.Locations.Count);
        Assert.Contains(warehouse.Locations, l => l.Code == "A" && l.Name == "Zone A");
        Assert.Contains(warehouse.Locations, l => l.Code == "B" && l.Name == "Zone B");
        Assert.Single(warehouse.DomainEvents.OfType<WarehouseUpdatedEvent>());
    }

    [Fact]
    public void SetLocations_UnchangedPayload_RaisesNoEvent()
    {
        var warehouse = Warehouse.Create(Guid.NewGuid(), Guid.NewGuid(), "Main Store", "MS");
        warehouse.SetLocations(new[]
        {
            new StockLocationSpec(Guid.Empty, "A", "Zone A"),
            new StockLocationSpec(Guid.Empty, "B", "Zone B"),
        });
        var eventsBefore = warehouse.DomainEvents.Count;

        warehouse.SetLocations(new[]
        {
            new StockLocationSpec(Guid.Empty, "A", "Zone A"),
            new StockLocationSpec(Guid.Empty, "B", "Zone B"),
        });

        Assert.Equal(eventsBefore, warehouse.DomainEvents.Count);
    }

    [Fact]
    public void SetLocations_DuplicateCodes_Throws()
    {
        var warehouse = Warehouse.Create(Guid.NewGuid(), Guid.NewGuid(), "Main Store", "MS");

        Assert.Throws<ArgumentException>(() => warehouse.SetLocations(new[]
        {
            new StockLocationSpec(Guid.Empty, "A", "Zone A"),
            new StockLocationSpec(Guid.Empty, " a ", "Zone A 2"),
        }));
    }
}
