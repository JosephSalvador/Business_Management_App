using BusinessOS.Application.Features.Common;
using BusinessOS.Domain.Identity;

namespace BusinessOS.Application.Ports;

public sealed record FleetSummaryDto(
    int TotalTenants,
    int ActiveSubscriptions,
    int Trials,
    int ExpiringIn7Days,
    int AtRiskTenants,
    decimal TotalGmv30Days,
    int TotalSalesCount30Days,
    int TotalProductsCount);

public sealed record TenantAdminSummaryDto(
    Guid TenantId,
    string Name,
    string? Phone,
    string? Category,
    string PlanCode,
    string Status,
    int TrialDaysLeft,
    string? PaidUntil,
    int TotalProducts,
    int SalesCount30Days,
    int InvoicesCount,
    decimal TotalGmv30Days,
    string HealthStatus,
    string TodaySales,
    DateTime CreatedAtUtc);

public sealed record TenantAdminDetailDto(
    Guid TenantId,
    string Name,
    string? Phone,
    string? Category,
    string PlanCode,
    string Status,
    int TrialDaysLeft,
    string? PaidUntil,
    int TotalProducts,
    int LowStockProducts,
    int SalesCount30Days,
    int InvoicesCount,
    decimal TotalGmv30Days,
    string HealthStatus,
    string TodaySales,
    IReadOnlyDictionary<string, bool> Features,
    string? OwnerEmail,
    string? OwnerFullName,
    DateTime CreatedAtUtc);

public sealed record OmniProductDto(
    Guid Id,
    string Name,
    string? Barcode,
    string? Sku,
    string? Category,
    string? Unit,
    decimal BuyingPrice,
    decimal SellingPrice,
    decimal CurrentStock,
    decimal LowStockThreshold,
    string StockStatus,
    bool IsActive);

public sealed record OmniSaleSummaryDto(
    Guid Id,
    string ReceiptNumber,
    DateTime CreatedAt,
    decimal TotalAmount,
    string CustomerName,
    string CashierName,
    string Status,
    string PaymentMethod);

public sealed record OmniSaleLineDto(
    string ProductName,
    decimal Quantity,
    decimal UnitPrice,
    decimal TotalPrice);

public sealed record OmniSaleDetailDto(
    Guid Id,
    string ReceiptNumber,
    DateTime CreatedAt,
    decimal TotalAmount,
    string CustomerName,
    string CashierName,
    string Status,
    string PaymentMethod,
    IReadOnlyList<OmniSaleLineDto> Lines,
    string? BusinessName = null,
    string? Tin = null,
    string? Address = null,
    string? Phone = null,
    string? Email = null,
    string? BranchName = null,
    string? Currency = "TZS",
    string? LogoBase64 = null,
    string? ThemePrimaryHex = "#0F172A",
    string? FooterNotes = null,
    string? MobileMoneyDetails = null,
    string? BankName = null,
    string? BankAccountName = null,
    string? BankAccountNumber = null,
    decimal? Subtotal = null,
    decimal? DiscountAmount = null,
    decimal? TaxAmount = null,
    decimal? AmountPaid = null,
    decimal? Change = null,
    string? FiscalHash = null);

public sealed record OmniCashSessionDto(
    Guid Id,
    string TillName,
    string CashierName,
    DateTime OpenedAt,
    DateTime? ClosedAt,
    decimal OpeningBalance,
    decimal CashSales,
    decimal? ClosingBalance,
    decimal Discrepancy,
    bool IsOpen);

public sealed record OmniInvoiceSummaryDto(
    Guid Id,
    string InvoiceNumber,
    string CustomerName,
    DateTime? IssueDate,
    DateTime? DueDate,
    decimal TotalAmount,
    decimal AmountPaid,
    string Status);

public sealed record OmniInvoicePreviewDto(
    BusinessOS.Application.Features.Invoicing.CustomerInvoiceDto Invoice,
    BusinessOS.Application.Features.Organizations.Dtos.TenantOrganizationDto Organization,
    string ThemePrimaryHex,
    string ThemeSecondaryHex,
    string TemplateName,
    bool IsThermal80mm,
    string RenderedHtml);

public sealed record PlatformOperatorDto(
    Guid Id,
    Guid UserId,
    string Email,
    string Role,
    bool IsActive,
    DateTime CreatedAt);
