namespace BusinessOS.Application.Features.Receipts.Dtos;

/// <summary>
/// Receipt preview data returned by the API. Contains everything the client needs to render
/// the receipt, including the reprint flag and print count for watermark injection.
/// </summary>
public sealed record ReceiptPreviewDto(
    Guid SaleId,
    string SaleNumber,
    DateTime SaleDate,
    bool IsVoided,
    bool HasMetadata,
    bool IsReprint,
    int PrintCount,
    string BusinessName,
    string? TIN,
    string? Address,
    string? Phone,
    string? Email,
    string? BranchName,
    string? CashierName,
    string? CustomerName,
    string Currency,
    string? LayoutId,
    string? FiscalHash,
    string QrPayload,
    IReadOnlyList<ReceiptLineDto> Lines,
    IReadOnlyList<ReceiptPaymentDto> Payments,
    decimal Subtotal,
    decimal TaxAmount,
    decimal DiscountAmount,
    decimal TotalAmount,
    decimal AmountPaid,
    decimal Change);

public sealed record ReceiptLineDto(
    string ProductName,
    decimal Quantity,
    decimal UnitPrice,
    decimal DiscountAmount,
    decimal LineTotal,
    string TaxCode,
    decimal TaxAmount);

public sealed record ReceiptPaymentDto(
    string Method,
    decimal Amount,
    string? Reference = null);

/// <summary>
/// Request body for recording a print event.
/// </summary>
public sealed record RecordPrintEventRequest(
    int Type,
    string? DeviceId = null,
    string? Notes = null);

/// <summary>
/// Response after recording a print event.
/// </summary>
public sealed record PrintEventRecordedDto(
    Guid EventId,
    Guid SaleId,
    string Type,
    DateTime PrintedAt);
