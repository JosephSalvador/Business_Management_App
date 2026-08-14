using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record PriceListCreatedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid PriceListId,
    Guid TenantId,
    string Name,
    string Currency,
    bool IsDefault) : IDomainEvent;
