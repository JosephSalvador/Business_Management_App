using BusinessOS.Application.Ports;
using BusinessOS.Domain.Billing;

namespace BusinessOS.Application.Features.Billing;

public static class SubscriptionEntitlementCache
{
    public static readonly TimeSpan Lifetime = TimeSpan.FromSeconds(30);

    public static string Key(Guid tenantId) => $"billing:entitlement:{tenantId}";
}

/// <summary>
/// Effective subscription state handed to the API and the enforcement middleware.
/// Status and access level are <em>derived</em> by <see cref="SubscriptionAccessEvaluator"/>
/// from the subscription's dates; the stored <see cref="Domain.Billing.Subscription.Status"/>
/// is only advisory history. Rendered client-side as the billing page model.
/// </summary>
public sealed record SubscriptionEntitlement(
    SubscriptionStatus Status,
    AccessLevel AccessLevel,
    string? PlanCode,
    IReadOnlyList<string> EffectiveFeatureKeys,
    DateTime? NextDueUtc,
    bool HasOpenInvoice,
    int? MaxBranches,
    int? MaxUsers,
    int? MaxProducts,
    DateTime EvaluatedAtUtc,
    IReadOnlyList<string>? PlanFeatureKeys = null,
    IReadOnlyList<string>? Packages = null);

public interface ISubscriptionEntitlementService
{
    Task<SubscriptionEntitlement> GetEntitlementAsync(
        Guid tenantId, CancellationToken cancellationToken = default);
}

public sealed class SubscriptionEntitlementService : ISubscriptionEntitlementService
{
    private readonly ISubscriptionRepository _subscriptions;
    private readonly ISubscriptionItemRepository _subscriptionItems;
    private readonly IPlanRepository _plans;
    private readonly IInvoiceRepository _invoices;
    private readonly IFeatureFlagRepository _flags;

    public SubscriptionEntitlementService(
        ISubscriptionRepository subscriptions,
        ISubscriptionItemRepository subscriptionItems,
        IPlanRepository plans,
        IInvoiceRepository invoices,
        IFeatureFlagRepository flags)
    {
        _subscriptions = subscriptions;
        _subscriptionItems = subscriptionItems;
        _plans = plans;
        _invoices = invoices;
        _flags = flags;
    }

    /// <summary>
    /// Evaluates the tenant's subscription at <see cref="DateTime.UtcNow"/>. Effective features =
    /// (base plan ∪ add-on package features) ∩ tenant feature flags; in debt the plan side
    /// collapses to the free backstop. A missing subscription degrades to the backstop.
    /// </summary>
    public async Task<SubscriptionEntitlement> GetEntitlementAsync(
        Guid tenantId, CancellationToken cancellationToken = default)
    {
        var now = DateTime.UtcNow;
        var flags = await _flags.ListAsync(tenantId, cancellationToken);
        var enabledKeys = flags
            .Where(flag => flag.IsEnabled)
            .Select(flag => flag.Key)
            .ToHashSet(StringComparer.Ordinal);

        IReadOnlyList<string> Intersect(IReadOnlyList<string> planKeys)
            => planKeys
                .Where(enabledKeys.Contains)
                .Distinct(StringComparer.Ordinal)
                .ToArray();

        var subscription = await _subscriptions.GetForTenantAsync(tenantId, cancellationToken);
        if (subscription is null)
        {
            return new SubscriptionEntitlement(
                SubscriptionStatus.Debt,
                AccessLevel.PosAndInventory,
                PlanCode: null,
                Intersect(FeatureKeys.Backstop),
                NextDueUtc: null,
                HasOpenInvoice: false,
                MaxBranches: null,
                MaxUsers: null,
                MaxProducts: null,
                now,
                PlanFeatureKeys: FeatureKeys.Backstop,
                Packages: Array.Empty<string>());
        }

        var evaluation = SubscriptionAccessEvaluator.Evaluate(
            subscription.Status, subscription.TrialEndedAtUtc, subscription.PaidUntilUtc, now);
        var plan = await _plans.GetByCodeAsync(subscription.PlanCode, cancellationToken);
        var hasOpenInvoice = await _invoices.GetOpenAsync(tenantId, cancellationToken) is not null;
        var items = await _subscriptionItems.ListForTenantAsync(tenantId, cancellationToken);

        var packages = items
            .Select(item => item.PlanCode)
            .Distinct(StringComparer.Ordinal)
            .OrderBy(code => code, StringComparer.Ordinal)
            .ToArray();

        var full = evaluation.AccessLevel == AccessLevel.Full;
        IReadOnlyList<string> planKeys;
        if (full)
        {
            var keys = new List<string>(plan?.FeatureKeys ?? FeatureKeys.Backstop);
            foreach (var item in items)
            {
                var itemPlan = await _plans.GetByCodeAsync(item.PlanCode, cancellationToken);
                if (itemPlan is not null)
                {
                    keys.AddRange(itemPlan.FeatureKeys);
                }
            }

            planKeys = keys.Distinct(StringComparer.Ordinal).ToArray();
        }
        else
        {
            planKeys = FeatureKeys.Backstop;
        }

        return new SubscriptionEntitlement(
            evaluation.Status,
            evaluation.AccessLevel,
            subscription.PlanCode,
            Intersect(planKeys),
            evaluation.NextDueUtc,
            hasOpenInvoice,
            full ? plan?.MaxBranches : null,
            full ? plan?.MaxUsers : null,
            full ? plan?.MaxProducts : null,
            now,
            PlanFeatureKeys: planKeys,
            Packages: packages);
    }
}
