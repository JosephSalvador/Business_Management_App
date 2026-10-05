using BusinessOS.Application.Ports;
using BusinessOS.Domain.Billing;
using BusinessOS.Shared;

namespace BusinessOS.Application.Features.Billing;

/// <summary>
/// Handler-level enforcement for rules the route map cannot express: sub-features of an
/// always-available route (a second branch needs multi-branch) and plan quotas. The
/// middleware covers whole modules; this covers the fine-grained gates inside them.
/// </summary>
public sealed class SubscriptionEntitlementGuard
{
    private const string DebtDetail =
        "This workspace subscription is in debt. Renew to restore full access; " +
        "POS and inventory keep working.";

    private readonly ITenantContext _tenantContext;
    private readonly ISubscriptionEntitlementService _entitlement;
    private readonly ICacheService _cache;

    public SubscriptionEntitlementGuard(
        ITenantContext tenantContext,
        ISubscriptionEntitlementService entitlement,
        ICacheService cache)
    {
        _tenantContext = tenantContext;
        _entitlement = entitlement;
        _cache = cache;
    }

    public async Task<SubscriptionEntitlement> GetEntitlementAsync(
        CancellationToken cancellationToken = default)
    {
        var key = SubscriptionEntitlementCache.Key(_tenantContext.TenantId);
        var entitlement =
            await _cache.GetAsync<SubscriptionEntitlement>(key, cancellationToken);
        if (entitlement is not null)
        {
            return entitlement;
        }

        entitlement = await _entitlement.GetEntitlementAsync(
            _tenantContext.TenantId, cancellationToken);
        await _cache.SetAsync(
            key, entitlement, SubscriptionEntitlementCache.Lifetime, cancellationToken);
        return entitlement;
    }

    public async Task<Error?> EnsureFeatureAsync(
        string featureKey, CancellationToken cancellationToken = default)
    {
        var entitlement = await GetEntitlementAsync(cancellationToken);
        return EnsureFeature(entitlement, featureKey);
    }

    public static Error? EnsureFeature(SubscriptionEntitlement entitlement, string featureKey)
    {
        if (entitlement.EffectiveFeatureKeys.Contains(featureKey, StringComparer.Ordinal))
        {
            return null;
        }

        return entitlement.AccessLevel == AccessLevel.Full
            ? Error.ModuleDisabled(ModuleDisabledMessage(featureKey))
            : Error.BillingRequired(DebtDetail);
    }

    public static Error? EnsureWithinLimit(int? limit, int currentCount, string resource)
    {
        if (limit is not { } max || currentCount <= max)
        {
            return null;
        }

        return Error.QuotaExceeded(
            $"This plan allows {max} {resource}. Upgrade or remove one to continue.");
    }

    private static string ModuleDisabledMessage(string featureKey)
        => ModuleRouteMap.ByFeatureKey(featureKey) is { } module
            ? $"The {module.Name} module is not enabled for this workspace."
            : "This feature is not enabled for this workspace.";
}
