using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record ProductVariantsChangedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid ProductId,
    Guid TenantId,
    Guid[] VariantIds,
    bool HasVariants) : IDomainEvent;
