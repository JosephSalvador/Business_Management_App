using BusinessOS.Domain.Events;
using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Billing;

/// <summary>
/// Tenant-scoped subscription to a <see cref="Plan"/>. The aggregate holds the effective dates
/// (<see cref="TrialEndedAtUtc"/>, <see cref="PaidUntilUtc"/>) that enforcement derives
/// everything from; the stored <see cref="Status"/> is advisory history kept for reporting and
/// audit. One active subscription exists per tenant.
/// </summary>
public sealed class Subscription : AggregateRoot
{
    private Subscription(
        Guid id,
        Guid tenantId,
        string planCode,
        SubscriptionStatus status,
        DateTime trialEndedAtUtc,
        DateTime? paidUntilUtc)
        : base(id)
    {
        TenantId = tenantId;
        PlanCode = planCode;
        Status = status;
        TrialEndedAtUtc = trialEndedAtUtc;
        PaidUntilUtc = paidUntilUtc;
    }

    public Guid TenantId { get; private set; }
    public string PlanCode { get; private set; }
    public SubscriptionStatus Status { get; private set; }
    public DateTime TrialEndedAtUtc { get; private set; }
    public DateTime? PaidUntilUtc { get; private set; }

    public static Subscription StartTrial(
        Guid tenantId,
        string planCode = SubscriptionAccessEvaluator.DefaultPlanCode,
        TimeSpan? trialLength = null,
        DateTime? nowUtc = null)
    {
        var now = nowUtc ?? DateTime.UtcNow;
        var subscription = new Subscription(
            Guid.NewGuid(),
            tenantId,
            planCode,
            SubscriptionStatus.Trial,
            now.Add(trialLength ?? SubscriptionAccessEvaluator.DefaultTrialLength),
            paidUntilUtc: null);

        subscription.AddDomainEvent(new SubscriptionTrialStartedEvent(
            Guid.NewGuid(),
            now,
            subscription.Id,
            tenantId,
            subscription.TrialEndedAtUtc));
        return subscription;
    }

    /// <summary>
    /// Records a payment covering access from <paramref name="effectiveStartUtc"/> (already
    /// nudged to the later of now / current paid-until) for <paramref name="duration"/>.
    /// </summary>
    public void Paid(DateTime effectiveStartUtc, TimeSpan duration, DateTime? nowUtc = null)
    {
        var now = nowUtc ?? DateTime.UtcNow;
        var paidUntil = effectiveStartUtc.Add(duration);

        if (paidUntil > (PaidUntilUtc ?? effectiveStartUtc))
        {
            PaidUntilUtc = paidUntil;
        }

        if (Status == SubscriptionStatus.Debt || now >= TrialEndedAtUtc)
        {
            MarkActive(now);
        }
    }

    /// <summary>Reverts to the full entitlement state after payment is confirmed.</summary>
    public void MarkActive(DateTime? nowUtc = null)
    {
        if (Status == SubscriptionStatus.Active)
        {
            return;
        }

        var now = nowUtc ?? DateTime.UtcNow;
        Status = SubscriptionStatus.Active;
        AddDomainEvent(new SubscriptionActivatedEvent(
            Guid.NewGuid(), now, Id, TenantId, PaidUntilUtc));
    }

    /// <summary>Persists the trial-end → debt transition and raises the transition event.</summary>
    public void MarkDebt(DateTime? nowUtc = null)
    {
        if (Status == SubscriptionStatus.Debt)
        {
            return;
        }

        var now = nowUtc ?? DateTime.UtcNow;
        Status = SubscriptionStatus.Debt;
        AddDomainEvent(new SubscriptionDebtTransitionEvent(
            Guid.NewGuid(), now, Id, TenantId, SinceUtc: now));
    }

    /// <summary>Switches or upgrades the base plan of the subscription.</summary>
    public void ChangePlan(string newPlanCode)
    {
        if (string.IsNullOrWhiteSpace(newPlanCode)) return;
        PlanCode = newPlanCode.Trim();
    }

    /// <summary>Grants extra free trial days (negotiated or promotional extension).</summary>
    public void ExtendTrial(TimeSpan extraDuration, DateTime? nowUtc = null)
    {
        var now = nowUtc ?? DateTime.UtcNow;
        var baseDate = TrialEndedAtUtc > now ? TrialEndedAtUtc : now;
        TrialEndedAtUtc = baseDate.Add(extraDuration);
        if (Status == SubscriptionStatus.Debt)
        {
            Status = SubscriptionStatus.Trial;
        }
    }
}