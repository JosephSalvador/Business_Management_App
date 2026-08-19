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

public sealed record ExportResultDto(
    byte[] FileBytes, string ContentType, string FileName);
