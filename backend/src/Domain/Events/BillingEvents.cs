using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record SubscriptionTrialStartedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid SubscriptionId,
    Guid TenantId,
    DateTime TrialEndedAtUtc) : IDomainEvent, ITenantScopedEvent;

public sealed record SubscriptionActivatedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid SubscriptionId,
    Guid TenantId,
    DateTime? PaidUntilUtc) : IDomainEvent, ITenantScopedEvent;

public sealed record SubscriptionDebtTransitionEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid SubscriptionId,
    Guid TenantId,
    DateTime SinceUtc) : IDomainEvent, ITenantScopedEvent;

/// <summary>Raised on the redeeming tenant; the outbox row is tenant-stamped via TenantId.</summary>
public sealed record VoucherRedeemedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid VoucherId,
    Guid TenantId,
    string VoucherCode,
    int ValueDays) : IDomainEvent, ITenantScopedEvent;

/// <summary>
/// Platform-level record that a batch of voucher codes was issued (owner sold prepaid access).
/// Not tenant-scoped: the issuing platform admin's access is not the redeemer's.
/// </summary>
public sealed record VouchersIssuedEvent(
    Guid EventId,
    DateTime OccurredAt,
    IReadOnlyList<string> Codes,
    int ValueDays,
    Guid? IssuedByUserId) : IDomainEvent;

public sealed record InvoiceIssuedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid InvoiceId,
    Guid TenantId,
    string Number,
    decimal Amount,
    string Currency,
    DateTime DueUtc) : IDomainEvent, ITenantScopedEvent;

public sealed record InvoicePaidEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid InvoiceId,
    Guid TenantId,
    string Number,
    string Reference) : IDomainEvent, ITenantScopedEvent;

public sealed record SubscriptionPackageActivatedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid SubscriptionItemId,
    Guid TenantId,
    string PlanCode) : IDomainEvent, ITenantScopedEvent;

public sealed record SubscriptionPackageRemovedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid SubscriptionItemId,
    Guid TenantId,
    string PlanCode) : IDomainEvent, ITenantScopedEvent;