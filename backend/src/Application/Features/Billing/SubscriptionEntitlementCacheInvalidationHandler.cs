using BusinessOS.Application.Ports;
using BusinessOS.Domain.Events;

namespace BusinessOS.Application.Features.Billing;

public sealed class SubscriptionEntitlementCacheInvalidationHandler :
    IDomainEventHandler<SubscriptionTrialStartedEvent>,
    IDomainEventHandler<SubscriptionActivatedEvent>,
    IDomainEventHandler<SubscriptionDebtTransitionEvent>,
    IDomainEventHandler<VoucherRedeemedEvent>,
    IDomainEventHandler<InvoicePaidEvent>,
    IDomainEventHandler<SubscriptionPackageActivatedEvent>,
    IDomainEventHandler<SubscriptionPackageRemovedEvent>,
    IDomainEventHandler<FeatureFlagChangedEvent>
{
    private readonly ICacheService _cache;

    public SubscriptionEntitlementCacheInvalidationHandler(ICacheService cache) => _cache = cache;

    public Task HandleAsync(SubscriptionTrialStartedEvent domainEvent, CancellationToken cancellationToken = default)
        => InvalidateAsync(domainEvent.TenantId, cancellationToken);

    public Task HandleAsync(SubscriptionActivatedEvent domainEvent, CancellationToken cancellationToken = default)
        => InvalidateAsync(domainEvent.TenantId, cancellationToken);

    public Task HandleAsync(SubscriptionDebtTransitionEvent domainEvent, CancellationToken cancellationToken = default)
        => InvalidateAsync(domainEvent.TenantId, cancellationToken);

    public Task HandleAsync(VoucherRedeemedEvent domainEvent, CancellationToken cancellationToken = default)
        => InvalidateAsync(domainEvent.TenantId, cancellationToken);

    public Task HandleAsync(InvoicePaidEvent domainEvent, CancellationToken cancellationToken = default)
        => InvalidateAsync(domainEvent.TenantId, cancellationToken);

    public Task HandleAsync(SubscriptionPackageActivatedEvent domainEvent, CancellationToken cancellationToken = default)
        => InvalidateAsync(domainEvent.TenantId, cancellationToken);

    public Task HandleAsync(SubscriptionPackageRemovedEvent domainEvent, CancellationToken cancellationToken = default)
        => InvalidateAsync(domainEvent.TenantId, cancellationToken);

    public Task HandleAsync(FeatureFlagChangedEvent domainEvent, CancellationToken cancellationToken = default)
        => InvalidateAsync(domainEvent.TenantId, cancellationToken);

    private Task InvalidateAsync(Guid tenantId, CancellationToken cancellationToken)
        => _cache.RemoveAsync(SubscriptionEntitlementCache.Key(tenantId), cancellationToken);
}
