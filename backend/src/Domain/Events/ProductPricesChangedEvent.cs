using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record ProductPricesChangedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid PriceListId,
    Guid TenantId,
    int PriceCount) : IDomainEvent;
