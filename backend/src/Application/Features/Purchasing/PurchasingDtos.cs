using BusinessOS.Application.Features.Common;
using BusinessOS.Application.Features.Inventory.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Inventory;
using BusinessOS.Domain.Purchasing;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Purchasing;

public sealed record SupplierDto(
    Guid Id,
    Guid TenantId,
    string Name,
    string? ContactName,
    string? Email,
    string? Phone,
    string? Address,
    string? Tin,
    string? Notes,
    bool IsActive,
    DateTime CreatedAt);

public sealed record PurchaseOrderDto(
    Guid Id,
    Guid SupplierId,
    string SupplierName,
    Guid WarehouseId,
    string WarehouseName,
    PurchaseOrderStatus Status,
    string? Reference,
    DateTime? ExpectedDate,
    string? Notes,
    decimal TotalAmount,
    IReadOnlyList<PurchaseOrderLineDto> Lines,
    DateTime? SubmittedAt,
    DateTime? ReceivedAt,
    DateTime? CancelledAt,
    DateTime CreatedAt);

public sealed record PurchaseOrderLineDto(
    Guid Id,
    Guid ProductId,
    string ProductName,
    decimal Quantity,
    decimal UnitPrice,
    decimal LineTotal);

public sealed record PurchaseOrderSummaryDto(
    Guid Id,
    string SupplierName,
    string WarehouseName,
    PurchaseOrderStatus Status,
    decimal TotalAmount,
    int LineCount,
    DateTime CreatedAt);

public sealed record SupplierBillDto(
    Guid Id,
    Guid SupplierId,
    string SupplierName,
    Guid PurchaseOrderId,
    string? BillNumber,
    DateTime BillDate,
    SupplierBillStatus Status,
    decimal Subtotal,
    decimal TaxAmount,
    decimal TotalAmount,
    decimal AmountPaid,
    decimal BalanceDue,
    string? Notes,
    DateTime? ApprovedAt,
    DateTime? VoidedAt,
    DateTime CreatedAt);

public sealed record SupplierPaymentDto(
    Guid Id,
    SupplierPaymentMethod Method,
    decimal Amount,
    string? Provider,
    string? Reference,
    string? PhoneNumber,
    DateTime CreatedAt);
