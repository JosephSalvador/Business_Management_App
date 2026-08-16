using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

/// <summary>
/// Raised when a sale is completed. Consumed by the activity feed and, for opted-in tenants, by
/// a fiscal outbox consumer — never by the synchronous sale path itself.
/// </summary>
public sealed record SaleCompletedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid SaleId,
    Guid TenantId,
    Guid BranchId,
    Guid CashierId,
    Guid ClientSaleId,
    string Number,
    string Currency,
    decimal TotalAmount,
    decimal TaxAmount) : IDomainEvent;
