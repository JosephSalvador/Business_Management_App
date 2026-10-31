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

public sealed record DeliveryNoteCreatedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid DeliveryNoteId,
    Guid TenantId,
    string DeliveryNoteNumber,
    Guid? InvoiceId,
    Guid? CustomerId,
    int ItemCount) : IDomainEvent, ITenantScopedEvent;

public sealed record DeliveryNoteDispatchedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid DeliveryNoteId,
    Guid TenantId,
    string DeliveryNoteNumber) : IDomainEvent, ITenantScopedEvent;

public sealed record DeliveryNoteDeliveredEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid DeliveryNoteId,
    Guid TenantId,
    string DeliveryNoteNumber,
    string ReceivedByName) : IDomainEvent, ITenantScopedEvent;

public sealed record DeliveryNoteCancelledEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid DeliveryNoteId,
    Guid TenantId,
    string DeliveryNoteNumber) : IDomainEvent, ITenantScopedEvent;
