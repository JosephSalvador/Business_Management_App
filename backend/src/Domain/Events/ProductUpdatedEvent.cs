using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record ProductUpdatedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid ProductId,
    Guid TenantId,
    string Name) : IDomainEvent;
