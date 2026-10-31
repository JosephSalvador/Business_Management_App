using BusinessOS.Domain.Invoicing;

namespace BusinessOS.Application.Features.Invoicing;

public sealed record CustomerInvoiceLineDto(
    Guid Id,
    string Description,
    decimal Quantity,
    decimal UnitPrice,
    decimal TaxRatePercent,
    decimal LineTotal,
    decimal TaxAmount,
    string UnitOfMeasure = "Pcs",
    decimal DiscountAmount = 0m);

public sealed record CustomerInvoiceDto(
    Guid Id,
    string Number,
    Guid? CustomerId,
    string? CustomerName,
    string Currency,
    DateTime IssueDate,
    DateTime? DueDate,
    string? Notes,
    CustomerInvoiceStatus Status,
    decimal Subtotal,
    decimal TaxAmount,
    decimal TotalAmount,
    decimal AmountPaid,
    decimal BalanceDue,
    string? PaymentMethod,
    string? PaymentReference,
    DateTime? PaidAtUtc,
    DateTime? VoidedAtUtc,
    IReadOnlyList<CustomerInvoiceLineDto> Lines,
    DateTime CreatedAt,
    string DocumentTitle = "INVOICE",
    string? ReferenceNumber = null,
    string? PaymentTerms = null,
    string? CustomerAttention = null,
    string? CustomerPhone = null,
    string? CustomerEmail = null,
    string? CustomerAddress = null,
    string? CustomerTin = null,
    decimal DiscountAmount = 0m,
    string? PaymentInstructions = null,
    string? AuthorizedSignatoryName = null,
    string? AuthorizedSignatoryTitle = null);

public sealed record CustomerInvoiceSummaryDto(
    Guid Id,
    string Number,
    Guid? CustomerId,
    string? CustomerName,
    CustomerInvoiceStatus Status,
    DateTime IssueDate,
    DateTime? DueDate,
    decimal TotalAmount,
    decimal AmountPaid,
    decimal BalanceDue,
    DateTime CreatedAt,
    string DocumentTitle = "INVOICE",
    string? ReferenceNumber = null,
    string Currency = "TZS");

