using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record StockBatchCreatedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid BatchId,
    Guid TenantId,
    Guid ProductId,
    Guid? VariantId,
    string BatchNumber,
    DateTime? ExpiryDate,
    Guid? CreatedBy) : IDomainEvent;
