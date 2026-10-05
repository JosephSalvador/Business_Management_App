using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record CustomerInvoiceIssuedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid CustomerInvoiceId,
    Guid TenantId,
    string InvoiceNumber,
    decimal TotalAmount,
    string Currency,
    Guid? CustomerId) : IDomainEvent, ITenantScopedEvent;

public sealed record CustomerInvoicePaidEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid CustomerInvoiceId,
    Guid TenantId,
    string InvoiceNumber,
    decimal AmountPaid,
    string Currency,
    string? PaymentReference) : IDomainEvent, ITenantScopedEvent;

public sealed record CustomerInvoiceVoidedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid CustomerInvoiceId,
    Guid TenantId,
    string InvoiceNumber,
    decimal TotalAmount,
    string Currency) : IDomainEvent, ITenantScopedEvent;
