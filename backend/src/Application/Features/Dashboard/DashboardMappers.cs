using BusinessOS.Application.Features.Dashboard.Dtos;
using BusinessOS.Application.Ports;

namespace BusinessOS.Application.Features.Dashboard;

public static class DashboardMappers
{
    public static DashboardSummaryDto ToSummaryDto(DashboardSnapshot snapshot)
        => new(
            new DashboardCatalogDto(
                snapshot.Catalog.TotalProducts,
                snapshot.Catalog.ActiveProducts,
                snapshot.Catalog.DraftProducts,
                snapshot.Catalog.InactiveProducts,
                snapshot.Catalog.ServiceProducts,
                snapshot.Catalog.TotalVariants,
                snapshot.Catalog.TotalCategories),
            new DashboardInventoryDto(
                snapshot.Inventory.TotalWarehouses,
                snapshot.Inventory.TotalStockLines,
                snapshot.Inventory.TotalOnHandUnits,
                snapshot.Inventory.StockedProducts,
                snapshot.Inventory.ZeroStockLines,
                snapshot.Inventory.TotalMovements),
            new DashboardPricingDto(
                snapshot.Pricing.TotalPriceLists,
                snapshot.Pricing.DefaultPriceListName,
                snapshot.Pricing.ActivePriceProducts,
                snapshot.Pricing.BranchOverrideProducts),
            new DashboardOrganizationDto(
                snapshot.Organization.TotalBranches,
                snapshot.Organization.TotalUsers,
                snapshot.Organization.ActiveUsers,
                snapshot.Organization.TotalRoles),
            DateTime.UtcNow);

    public static DashboardLowStockDto ToLowStockDto(IReadOnlyList<LowStockItem> items)
        => new(items.Select(item => new DashboardLowStockItemDto(
                item.ProductId, item.ProductName, item.Sku, item.OnHand))
            .ToList());

    public static DashboardActivityDto ToActivityDto(IReadOnlyList<RecentActivityItem> items)
        => new(items.Select(item => new DashboardActivityItemDto(
                item.Action, item.EntityType, item.EntityId, item.ActorUserId, item.ActorEmail, item.OccurredAt))
            .ToList());
}
