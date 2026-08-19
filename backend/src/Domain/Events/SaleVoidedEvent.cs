using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

/// <summary>
/// Raised when a completed sale is voided. Consumed by the activity feed — never by the
/// synchronous void path itself (stock add-back happens in the command). The voided sale keeps
/// its immutable receipt number; voiding is a compensating status transition, never a delete.
/// </summary>
public sealed record SaleVoidedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid SaleId,
    Guid TenantId,
    Guid BranchId,
    Guid VoidedBy,
    string Number,
    string Currency,
    decimal TotalAmount,
    string Reason) : IDomainEvent;
