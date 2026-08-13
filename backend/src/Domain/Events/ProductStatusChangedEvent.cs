using BusinessOS.Domain.Catalog;
using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record ProductStatusChangedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid ProductId,
    Guid TenantId,
    ProductStatus Status) : IDomainEvent;
