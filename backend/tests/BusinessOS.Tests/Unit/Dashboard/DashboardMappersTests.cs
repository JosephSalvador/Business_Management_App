using BusinessOS.Application.Features.Dashboard;
using BusinessOS.Application.Features.Dashboard.Queries;
using BusinessOS.Application.Ports;

namespace BusinessOS.Tests.Unit.Dashboard;

public sealed class DashboardMappersTests
{
    [Fact]
    public void ToSummaryDto_MapsAllSnapshotGroups()
    {
        var snapshot = new DashboardSnapshot(
            new DashboardCatalogSnapshot(
                TotalProducts: 10, ActiveProducts: 5, DraftProducts: 2, InactiveProducts: 3,
                ServiceProducts: 4, TotalVariants: 6, TotalCategories: 1),
            new DashboardInventorySnapshot(
                TotalWarehouses: 2, TotalStockLines: 8, TotalOnHandUnits: 120m,
                StockedProducts: 7, ZeroStockLines: 1, TotalMovements: 9),
            new DashboardPricingSnapshot(
                TotalPriceLists: 1, DefaultPriceListName: "Default",
                ActivePriceProducts: 7, BranchOverrideProducts: 3),
            new DashboardOrganizationSnapshot(
                TotalBranches: 1, TotalUsers: 3, ActiveUsers: 2, TotalRoles: 2));

        var dto = DashboardMappers.ToSummaryDto(snapshot);

        Assert.Equal(10, dto.Catalog.TotalProducts);
        Assert.Equal(5, dto.Catalog.ActiveProducts);
        Assert.Equal(2, dto.Catalog.DraftProducts);
        Assert.Equal(3, dto.Catalog.InactiveProducts);
        Assert.Equal(4, dto.Catalog.ServiceProducts);
        Assert.Equal(6, dto.Catalog.TotalVariants);
        Assert.Equal(1, dto.Catalog.TotalCategories);

        Assert.Equal(2, dto.Inventory.TotalWarehouses);
        Assert.Equal(8, dto.Inventory.TotalStockLines);
        Assert.Equal(120m, dto.Inventory.TotalOnHandUnits);
        Assert.Equal(7, dto.Inventory.StockedProducts);
        Assert.Equal(1, dto.Inventory.ZeroStockLines);
        Assert.Equal(9, dto.Inventory.TotalMovements);

        Assert.Equal(1, dto.Pricing.TotalPriceLists);
        Assert.Equal("Default", dto.Pricing.DefaultPriceListName);
        Assert.Equal(7, dto.Pricing.ActivePriceProducts);
        Assert.Equal(3, dto.Pricing.BranchOverrideProducts);

        Assert.Equal(1, dto.Organization.TotalBranches);
        Assert.Equal(3, dto.Organization.TotalUsers);
        Assert.Equal(2, dto.Organization.ActiveUsers);
        Assert.Equal(2, dto.Organization.TotalRoles);
        Assert.True(DateTime.UtcNow - dto.GeneratedAt < TimeSpan.FromMinutes(1));
    }

    [Fact]
    public void ToLowStockDto_MapsItems()
    {
        var items = new List<LowStockItem>
        {
            new(Guid.NewGuid(), "Zero Stock", null, 0m),
            new(Guid.NewGuid(), "Low Stock", "SKU-1", 10m),
        };

        var dto = DashboardMappers.ToLowStockDto(items);

        Assert.Equal(2, dto.Items.Count);
        Assert.Equal("Zero Stock", dto.Items[0].ProductName);
        Assert.Null(dto.Items[0].Sku);
        Assert.Equal("SKU-1", dto.Items[1].Sku);
        Assert.Equal(10m, dto.Items[1].OnHand);
    }

    [Fact]
    public void ToActivityDto_MapsItems()
    {
        var items = new List<RecentActivityItem>
        {
            new("CreateProductCommand", "Command", "abc", Guid.NewGuid(), "owner@test.local", DateTime.UtcNow),
        };

        var dto = DashboardMappers.ToActivityDto(items);

        Assert.Single(dto.Items);
        Assert.Equal("CreateProductCommand", dto.Items[0].Action);
        Assert.Equal("Command", dto.Items[0].EntityType);
        Assert.Equal("abc", dto.Items[0].EntityId);
        Assert.Equal("owner@test.local", dto.Items[0].ActorEmail);
    }
}

public sealed class DashboardValidatorsTests
{
    [Fact]
    public void GetLowStockQueryValidator_AcceptsDefaults()
    {
        var validator = new GetLowStockQueryValidator();
        Assert.True(validator.Validate(new GetLowStockQuery()).IsValid);
        Assert.True(validator.Validate(new GetLowStockQuery(50m, 100)).IsValid);
    }

    [Fact]
    public void GetLowStockQueryValidator_RejectsNegativeThresholdAndBadLimit()
    {
        var validator = new GetLowStockQueryValidator();
        Assert.False(validator.Validate(new GetLowStockQuery(-1m, 20)).IsValid);
        Assert.False(validator.Validate(new GetLowStockQuery(0m, 0)).IsValid);
        Assert.False(validator.Validate(new GetLowStockQuery(0m, 101)).IsValid);
    }

    [Fact]
    public void GetRecentActivityQueryValidator_ValidatesLimit()
    {
        var validator = new GetRecentActivityQueryValidator();
        Assert.True(validator.Validate(new GetRecentActivityQuery(1)).IsValid);
        Assert.True(validator.Validate(new GetRecentActivityQuery(100)).IsValid);
        Assert.False(validator.Validate(new GetRecentActivityQuery(0)).IsValid);
        Assert.False(validator.Validate(new GetRecentActivityQuery(101)).IsValid);
    }
}
