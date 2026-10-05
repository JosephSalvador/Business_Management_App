using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

/// <summary>
/// Raised when a tenant feature flag is created enabled or toggled. The entitlement cache
/// intersects plan features with these flags, so the cached evaluation must be dropped.
/// </summary>
public sealed record FeatureFlagChangedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid FeatureFlagId,
    Guid TenantId,
    string Key,
    bool IsEnabled) : IDomainEvent, ITenantScopedEvent;
