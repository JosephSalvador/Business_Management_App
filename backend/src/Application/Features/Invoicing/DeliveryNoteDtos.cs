using BusinessOS.Domain.Invoicing;

namespace BusinessOS.Application.Features.Invoicing;

public sealed record DeliveryNoteItemDto(
    Guid Id,
    Guid? ProductId,
    string Description,
    string UnitOfMeasure,
    decimal QuantityOrdered,
    decimal QuantityDelivered,
    int LineIndex);

public sealed record DeliveryNoteDto(
    Guid Id,
    string Number,
    Guid? InvoiceId,
    string? InvoiceNumber,
    Guid? CustomerId,
    string? CustomerName,
    string? CustomerAttention,
    string? CustomerPhone,
    string? DeliveryAddress,
    DateTime IssueDate,
    DeliveryNoteStatus Status,
    string? VehicleNumber,
    string? DriverName,
    string? DriverPhone,
    string? ReceivedByName,
    string? Notes,
    DateTime? DispatchedAtUtc,
    DateTime? DeliveredAtUtc,
    DateTime? CancelledAtUtc,
    IReadOnlyList<DeliveryNoteItemDto> Items,
    DateTime CreatedAt);

public sealed record DeliveryNoteSummaryDto(
    Guid Id,
    string Number,
    Guid? InvoiceId,
    string? InvoiceNumber,
    Guid? CustomerId,
    string? CustomerName,
    DeliveryNoteStatus Status,
    DateTime IssueDate,
    int ItemCount,
    string? VehicleNumber,
    string? DriverName,
    DateTime CreatedAt);
