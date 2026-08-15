namespace BusinessOS.Application.Features.Dashboard.Dtos;

public sealed record DashboardSummaryDto(
    DashboardCatalogDto Catalog,
    DashboardInventoryDto Inventory,
    DashboardPricingDto Pricing,
    DashboardOrganizationDto Organization,
    DateTime GeneratedAt);

public sealed record DashboardCatalogDto(
    int TotalProducts,
    int ActiveProducts,
    int DraftProducts,
    int InactiveProducts,
    int ServiceProducts,
    int TotalVariants,
    int TotalCategories);

public sealed record DashboardInventoryDto(
    int TotalWarehouses,
    int TotalStockLines,
    decimal TotalOnHandUnits,
    int StockedProducts,
    int ZeroStockLines,
    int TotalMovements);

public sealed record DashboardPricingDto(
    int TotalPriceLists,
    string? DefaultPriceListName,
    int ActivePriceProducts,
    int BranchOverrideProducts);

public sealed record DashboardOrganizationDto(
    int TotalBranches,
    int TotalUsers,
    int ActiveUsers,
    int TotalRoles);

public sealed record DashboardLowStockItemDto(
    Guid ProductId,
    string ProductName,
    string? Sku,
    decimal OnHand);

public sealed record DashboardLowStockDto(IReadOnlyList<DashboardLowStockItemDto> Items);

public sealed record DashboardActivityItemDto(
    string Action,
    string EntityType,
    string? EntityId,
    Guid? ActorUserId,
    string? ActorEmail,
    DateTime OccurredAt);

public sealed record DashboardActivityDto(IReadOnlyList<DashboardActivityItemDto> Items);
