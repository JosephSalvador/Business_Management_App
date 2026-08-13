using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record ProductCreatedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid ProductId,
    Guid TenantId,
    string Name,
    string? Sku) : IDomainEvent;
