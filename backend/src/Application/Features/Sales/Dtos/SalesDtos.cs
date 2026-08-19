using BusinessOS.Domain.Sales;

namespace BusinessOS.Application.Features.Sales.Dtos;

/// <summary>One item the client wants to sell. Prices are re-resolved server-side.</summary>
public sealed record CreateSaleLineInput(
    Guid ProductId,
    Guid? VariantId,
    decimal Quantity,
    decimal DiscountAmount = 0m);

/// <summary>One tender row. Payments are data only in this slice — no gateway calls.</summary>
public sealed record CreateSalePaymentInput(
    PaymentMethod Method,
    decimal Amount,
    string? Provider = null,
    string? PhoneNumber = null,
    string? Reference = null);

public sealed record SaleCustomerDto(
    string? Name,
    string? Phone,
    string? Tin,
    bool? IsVatRegistered);

public sealed record SaleLineDto(
    Guid Id,
    Guid ProductId,
    Guid? VariantId,
    string ProductName,
    string? Sku,
    string? Barcode,
    Guid UnitOfMeasureId,
    string? UnitOfMeasureName,
    decimal Quantity,
    decimal UnitPrice,
    decimal DiscountAmount,
    string TaxCode,
    decimal AppliedRate,
    Guid? AppliedRuleId,
    decimal BaseAmount,
    decimal TaxAmount,
    decimal LineTotal,
    int OrderIndex);

public sealed record SalePaymentDto(
    Guid Id,
    PaymentMethod Method,
    decimal Amount,
    string? Provider,
    string? PhoneNumber,
    string? Reference,
    int OrderIndex);

/// <summary>Body of <c>POST /api/v1/sales/{id}/void</c>. Reason is required.</summary>
public sealed record VoidSaleRequest(string Reason);

public sealed record SaleDto(
    Guid Id,
    Guid TenantId,
    Guid BranchId,
    Guid? WarehouseId,
    Guid CashierId,
    string Number,
    Guid ClientSaleId,
    SaleSource Source,
    SaleStatus Status,
    DateTime SaleDate,
    DateTime EffectiveAt,
    string Currency,
    Guid? PriceListId,
    bool IsPriceTaxInclusive,
    bool IsElectronicPayment,
    SaleCustomerDto? Customer,
    decimal Subtotal,
    decimal DiscountAmount,
    decimal TaxAmount,
    decimal TotalAmount,
    decimal AmountPaid,
    decimal Change,
    IReadOnlyList<SaleLineDto> Lines,
    IReadOnlyList<SalePaymentDto> Payments,
    DateTime CreatedAt,
    DateTime? UpdatedAt,
    DateTime? VoidedAt = null,
    Guid? VoidedBy = null,
    string? VoidReason = null);
