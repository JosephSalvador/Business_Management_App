using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Billing;

/// <summary>
/// Pure derivation of a <see cref="Subscription"/>'s effective state, kept separate from the
/// aggregate so enforcement middleware and handlers can reuse it without loading domain
/// history or mutating anything.
/// </summary>
public static class SubscriptionAccessEvaluator
{
    /// <summary>MVp default: every new tenant starts on the Pro plan with a 14-day trial.</summary>
    public const string DefaultPlanCode = "Pro";
    public static readonly TimeSpan DefaultTrialLength = TimeSpan.FromDays(14);

    public static SubscriptionEvaluation Evaluate(
        SubscriptionStatus storedStatus,
        DateTime trialEndedAtUtc,
        DateTime? paidUntilUtc,
        DateTime nowUtc)
    {
        if (paidUntilUtc is not null && paidUntilUtc > nowUtc)
        {
            return new SubscriptionEvaluation(
                SubscriptionStatus.Active, AccessLevel.Full, paidUntilUtc);
        }

        if (nowUtc < trialEndedAtUtc)
        {
            return new SubscriptionEvaluation(
                SubscriptionStatus.Trial, AccessLevel.Full, trialEndedAtUtc);
        }

        // The stored status is only advisory history; debt is always derived from the dates.
        _ = storedStatus;
        return new SubscriptionEvaluation(
            SubscriptionStatus.Debt, AccessLevel.PosAndInventory, null);
    }

    /// <summary>From which moment a new payment period should be counted.</summary>
    public static DateTime EffectivePeriodStart(DateTime? paidUntilUtc, DateTime nowUtc)
        => paidUntilUtc is not null && paidUntilUtc > nowUtc ? paidUntilUtc.Value : nowUtc;
}