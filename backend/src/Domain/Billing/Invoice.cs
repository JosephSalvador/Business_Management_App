using BusinessOS.Domain.Events;
using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Billing;

/// <summary>
/// A per-tenant invoice (payable / paid). One Open invoice covers one subscription period
/// (a renewable billing period); it is issued automatically when the trial lapses into debt.
/// The PDF is rendered client-side from the invoice DTO, keeping the offline-first client in
/// control of its own document delivery.
/// </summary>
public sealed class Invoice : AggregateRoot
{
    private Invoice(
        Guid id,
        Guid tenantId,
        string number,
        string description,
        decimal amount,
        string currency,
        Guid subscriptionId,
        DateTime periodStartUtc,
        DateTime periodEndUtc,
        DateTime issuedAtUtc)
        : base(id)
    {
        TenantId = tenantId;
        Number = number;
        Description = description;
        Amount = amount;
        Currency = currency;
        SubscriptionId = subscriptionId;
        PeriodStartUtc = periodStartUtc;
        PeriodEndUtc = periodEndUtc;
        IssuedAtUtc = issuedAtUtc;
    }

    public Guid TenantId { get; private set; }
    public string Number { get; private set; }
    public string Description { get; private set; }
    public decimal Amount { get; private set; }
    public string Currency { get; private set; }
    public Guid SubscriptionId { get; private set; }
    public DateTime PeriodStartUtc { get; private set; }
    public DateTime PeriodEndUtc { get; private set; }
    public DateTime IssuedAtUtc { get; private set; }

    public InvoiceStatus Status { get; private set; } = InvoiceStatus.Open;
    public string? Reference { get; private set; }
    public Guid? ConfirmedByUserId { get; private set; }
    public DateTime? PaidAtUtc { get; private set; }

    /// <summary>Creates the payable invoice for one subscription period.</summary>
    public static Invoice CreateRenewal(
        Guid tenantId,
        string number,
        Plan plan,
        Guid subscriptionId,
        DateTime periodStartUtc,
        DateTime periodEndUtc,
        DateTime? issuedAtUtc = null)
    {
        var issuedAt = issuedAtUtc ?? DateTime.UtcNow;

        if (periodStartUtc >= periodEndUtc)
        {
            throw new ArgumentException("Invoice period end must be after period start.", nameof(periodEndUtc));
        }

        var invoice = new Invoice(
            Guid.NewGuid(),
            tenantId,
            number,
            $"Subscription renewal — {plan.Name} ({periodStartUtc:d} – {periodEndUtc:d})",
            plan.MonthlyPrice,
            plan.Currency,
            subscriptionId,
            periodStartUtc,
            periodEndUtc,
            issuedAt);

        invoice.AddDomainEvent(new InvoiceIssuedEvent(
            Guid.NewGuid(),
            issuedAt,
            invoice.Id,
            tenantId,
            invoice.Number,
            invoice.Amount,
            invoice.Currency,
            invoice.PeriodEndUtc));
        return invoice;
    }

    /// <summary>
    /// Confirms payment (usual for a voucher redemption — <paramref name="reference"/> is the
    /// voucher code; for owner-verified mobile-money payments it is the payment reference).
    /// </summary>
    public void MarkPaid(string reference, Guid? confirmedByUserId = null, DateTime? nowUtc = null)
    {
        if (Status != InvoiceStatus.Open)
        {
            throw new InvalidOperationException("Only an open invoice can be marked paid.");
        }

        if (string.IsNullOrWhiteSpace(reference))
        {
            throw new ArgumentException("A payment reference is required.", nameof(reference));
        }

        var now = nowUtc ?? DateTime.UtcNow;
        Reference = reference.Trim();
        ConfirmedByUserId = confirmedByUserId;
        PaidAtUtc = now;
        Status = InvoiceStatus.Paid;

        AddDomainEvent(new InvoicePaidEvent(
            Guid.NewGuid(),
            now,
            Id,
            TenantId,
            Number,
            Reference));
    }

    public void Cancel(DateTime? nowUtc = null)
    {
        if (Status != InvoiceStatus.Open)
        {
            throw new InvalidOperationException("Only an open invoice can be cancelled.");
        }

        Status = InvoiceStatus.Cancelled;
        _ = nowUtc ?? DateTime.UtcNow;
    }
}