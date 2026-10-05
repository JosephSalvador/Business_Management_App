using BusinessOS.Application.Ports;

namespace BusinessOS.Application.Features.Reports;

public sealed record TaxSummaryLineDto(
    string TaxCode, decimal AppliedRate,
    decimal TotalBaseAmount, decimal TotalTaxAmount, decimal TotalLineTotal, int SaleCount);

public sealed record TaxSummaryDto(
    DateTime From, DateTime To,
    IReadOnlyList<TaxSummaryLineDto> Lines,
    decimal TotalBaseAmount, decimal TotalTaxAmount, decimal TotalLineTotal);

public sealed record SalesByBranchSummaryDto(
    Guid BranchId, string BranchName, int TotalSales, decimal TotalRevenue);

public sealed record SalesSummaryDto(
    DateTime From, DateTime To,
    int TotalSales, decimal TotalRevenue, decimal TotalTax,
    decimal TotalDiscount, decimal AverageSale,
    IReadOnlyList<SalesByBranchSummaryDto> ByBranch);

public sealed record TopProductDto(
    Guid ProductId, string ProductName, string? Sku,
    decimal TotalQuantity, decimal TotalRevenue, decimal TotalTax, int Rank);

public sealed record TopProductsDto(
    DateTime From, DateTime To,
    IReadOnlyList<TopProductDto> Products);

public sealed record DashboardTaxKpisDto(
    decimal TotalRevenue, decimal TotalTaxCollected,
    IReadOnlyList<TaxSummaryLineDto> TaxByCode,
    IReadOnlyList<TopProductDto> TopProducts);

public sealed record SalesTrendDto(
    DateTime From, DateTime To, int Days,
    IReadOnlyList<SalesTrendPointDto> DataPoints);

public sealed record SalesTrendPointDto(
    string Label, int SaleCount, decimal Revenue, decimal Tax);

public sealed record ExportResultDto(
    byte[] FileBytes, string ContentType, string FileName);

// ── Business Overview ───────────────────────────────────────────
public sealed record BusinessOverviewKpiDto(
    decimal CurrentValue, decimal PreviousValue, decimal ChangePercent, bool IsUp);

public sealed record BusinessOverviewDto(
    BusinessOverviewKpiDto Sales,
    BusinessOverviewKpiDto GrossProfit,
    BusinessOverviewKpiDto Expenses,
    BusinessOverviewKpiDto MoneyBalance,
    IReadOnlyList<SalesTrendPointDto> SalesTrend,
    IReadOnlyList<TopProductDto> TopProducts);

// ── Money Movement ──────────────────────────────────────────────
public sealed record MoneyMovementLineDto(string Label, decimal Amount);

public sealed record MoneyMovementDto(
    decimal StartingBalance,
    IReadOnlyList<MoneyMovementLineDto> MoneyIn,
    IReadOnlyList<MoneyMovementLineDto> MoneyOut,
    decimal CurrentBalance);

// ── Purchases Summary ──────────────────────────────────────────
public sealed record PurchasesSummaryDto(
    decimal TotalPurchased,
    int SupplierCount,
    int ItemsReceived,
    string? TopSupplierName,
    int PendingCount,
    int ReceivedCount);

// ── Sales by dimension ─────────────────────────────────────────
public sealed record SalesByPaymentMethodDto(string PaymentMethod, decimal Amount, int Count);
public sealed record SalesByPaymentMethodReportDto(
    DateTime From, DateTime To,
    IReadOnlyList<SalesByPaymentMethodDto> Items);

public sealed record SalesByCategoryDto(string CategoryName, decimal Amount, decimal Quantity);
public sealed record SalesByCategoryReportDto(
    DateTime From, DateTime To,
    IReadOnlyList<SalesByCategoryDto> Items);

public sealed record SalesByStaffDto(Guid StaffId, string StaffName, int SaleCount, decimal Revenue);
public sealed record SalesByStaffReportDto(
    DateTime From, DateTime To,
    IReadOnlyList<SalesByStaffDto> Items);

public sealed record SalesByCustomerDto(Guid? CustomerId, string CustomerName, int SaleCount, decimal Revenue);
public sealed record SalesByCustomerReportDto(
    DateTime From, DateTime To,
    IReadOnlyList<SalesByCustomerDto> Items);

// ── Stock Reports ──────────────────────────────────────────────
public sealed record StockSummaryRowDto(
    Guid ProductId, string ProductName, string? Sku,
    decimal Opening, decimal Purchased, decimal Sold, decimal Adjusted, decimal Closing);

public sealed record StockSummaryReportDto(
    DateTime From, DateTime To,
    IReadOnlyList<StockSummaryRowDto> Rows);

public sealed record StockMovementSummaryDto(string MovementType, int Count, decimal TotalQuantity);
public sealed record StockMovementSummaryReportDto(
    DateTime From, DateTime To,
    IReadOnlyList<StockMovementSummaryDto> Items);

public sealed record LowStockReportItemDto(
    Guid ProductId, string ProductName, string? Sku,
    decimal OnHand, string WarehouseName);
public sealed record LowStockReportDto(IReadOnlyList<LowStockReportItemDto> Items);

public sealed record StockVelocityDto(
    Guid ProductId, string ProductName, string? Sku,
    decimal Sold, decimal OnHand, decimal VelocityPerDay);
public sealed record StockVelocityReportDto(
    DateTime From, DateTime To,
    IReadOnlyList<StockVelocityDto> Items);

// ── Expense Reports ────────────────────────────────────────────
public sealed record ExpenseTrendPointDto(string Label, decimal Amount);
public sealed record ExpenseTrendReportDto(
    DateTime From, DateTime To,
    IReadOnlyList<ExpenseTrendPointDto> DataPoints);

public sealed record ExpenseByPaymentMethodDto(string PaymentMethod, decimal Amount);
public sealed record ExpenseByPaymentMethodReportDto(
    DateTime From, DateTime To,
    IReadOnlyList<ExpenseByPaymentMethodDto> Items);

// ── Purchases by supplier ──────────────────────────────────────
public sealed record PurchasesBySupplierDto(
    Guid SupplierId, string SupplierName, decimal TotalAmount, int OrderCount);
public sealed record PurchasesBySupplierReportDto(
    DateTime From, DateTime To,
    IReadOnlyList<PurchasesBySupplierDto> Items);
