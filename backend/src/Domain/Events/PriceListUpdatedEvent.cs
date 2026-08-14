using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record PriceListUpdatedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid PriceListId,
    Guid TenantId,
    string Name,
    string Currency,
    bool IsDefault,
    bool IsActive) : IDomainEvent;
