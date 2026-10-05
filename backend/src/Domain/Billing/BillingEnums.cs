namespace BusinessOS.Domain.Billing;

/// <summary>
/// Lifecycle of a tenant's subscription. The value is derived from effective dates — the
/// transitions are persisted purely as audit/event history, while <em>enforcement</em> always
/// recomputes the status from <see cref="Subscription.TrialEndedAtUtc"/> and
/// <see cref="Subscription.PaidUntilUtc"/>.
/// </summary>
public enum SubscriptionStatus
{
    /// <summary>New tenant inside the trial window: full entitlement, no payment yet.</summary>
    Trial = 0,

    /// <summary>Paid and current: full entitlement of the subscribed plan.</summary>
    Active = 1,

    /// <summary>Trial ended without payment: the workspace drops to the free backstop.</summary>
    Debt = 2,
}

/// <summary>Effective capability level enforced by <see cref="SubscriptionAccessEvaluator"/>.</summary>
public enum AccessLevel
{
    /// <summary>All features of the subscribed plan are available.</summary>
    Full = 0,

    /// <summary>POS + inventory only (a tenant whose subscription is in debt).</summary>
    PosAndInventory = 1,
}

/// <summary>Persistence lifecycle of a prepaid voucher code.</summary>
public enum VoucherStatus
{
    Issued = 0,
    Redeemed = 1,
    Revoked = 2,
}

/// <summary>Persistence lifecycle of a tenant invoice.</summary>
public enum InvoiceStatus
{
    Open = 0,
    Paid = 1,
    Cancelled = 2,
}

/// <summary>
/// Pure, side-effect-free evaluation of a subscription's effective state at a point in time.
/// </summary>
/// <param name="Status">Derived lifecycle status.</param>
/// <param name="AccessLevel">Capability level to enforce.</param>
/// <param name="NextDueUtc">When access must be re-verified (trial end or paid-until); null when already in debt.</param>
public sealed record SubscriptionEvaluation(
    SubscriptionStatus Status,
    AccessLevel AccessLevel,
    DateTime? NextDueUtc);