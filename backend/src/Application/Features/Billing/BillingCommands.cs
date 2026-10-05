using BusinessOS.Application.Ports;
using BusinessOS.Domain.Billing;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Billing.Commands;

// ── Redeem Voucher ──────────────────────────────────────────────
/// <summary>
/// Exchanges a prepaid code for <see cref="Voucher.ValueDays"/> of paid access. The tenant's
/// paid-window is extended from the later of now / current paid-until; the open invoice (if
/// any) is settled with the voucher code as payment reference. Otherwise a paid-on-issue
/// invoice is recorded for the covered period so the client always has a document trail.
/// </summary>
public sealed record RedeemVoucherCommand(string Code)
    : IRequest<Result<SubscriptionEntitlement>>, IRequiresTenantAdvisoryLock;

public sealed class RedeemVoucherCommandHandler
    : IRequestHandler<RedeemVoucherCommand, Result<SubscriptionEntitlement>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IVoucherRepository _vouchers;
    private readonly ISubscriptionRepository _subscriptions;
    private readonly IPlanRepository _plans;
    private readonly IInvoiceRepository _invoices;
    private readonly ISubscriptionEntitlementService _entitlement;
    private readonly ICacheService _cache;

    public RedeemVoucherCommandHandler(
        ITenantContext tenantContext,
        IVoucherRepository vouchers,
        ISubscriptionRepository subscriptions,
        IPlanRepository plans,
        IInvoiceRepository invoices,
        ISubscriptionEntitlementService entitlement,
        ICacheService cache)
    {
        _tenantContext = tenantContext;
        _vouchers = vouchers;
        _subscriptions = subscriptions;
        _plans = plans;
        _invoices = invoices;
        _entitlement = entitlement;
        _cache = cache;
    }

    public async Task<Result<SubscriptionEntitlement>> Handle(
        RedeemVoucherCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var userId = _tenantContext.UserId;
        var now = DateTime.UtcNow;

        string normalized;
        try
        {
            normalized = VoucherCodes.Normalize(command.Code);
        }
        catch (ArgumentException)
        {
            return Error.Validation("Voucher code is not valid.");
        }

        var voucher = await _vouchers.GetByCodeAsync(normalized, cancellationToken);
        if (voucher is null)
        {
            return Error.NotFound("Voucher not found.");
        }

        if (voucher.Status != VoucherStatus.Issued)
        {
            return Error.Conflict("This voucher has already been redeemed.");
        }

        if (voucher.ExpiresAtUtc is not null && voucher.ExpiresAtUtc <= now)
        {
            return Error.Conflict("This voucher has expired.");
        }

        voucher.Redeem(tenantId, now);

        var subscription = await _subscriptions.GetForTenantAsync(tenantId, cancellationToken);
        if (subscription is null)
        {
            subscription = Subscription.StartTrial(tenantId, nowUtc: now);
            await _subscriptions.AddAsync(subscription, cancellationToken);
        }

        var plan = await _plans.GetByCodeAsync(subscription.PlanCode, cancellationToken)
            ?? await _plans.GetByCodeAsync(SubscriptionAccessEvaluator.DefaultPlanCode, cancellationToken);

        var effectiveStart = SubscriptionAccessEvaluator.EffectivePeriodStart(
            subscription.PaidUntilUtc, now);
        subscription.Paid(effectiveStart, TimeSpan.FromDays(voucher.ValueDays), now);
        await _subscriptions.UpdateAsync(subscription, cancellationToken);

        var openInvoice = await _invoices.GetOpenAsync(tenantId, cancellationToken);
        if (openInvoice is not null)
        {
            openInvoice.MarkPaid(voucher.Code, userId, now);
            await _invoices.UpdateAsync(openInvoice, cancellationToken);
        }
        else if (plan is not null)
        {
            var number = await _invoices.AllocateNumberAsync(tenantId, now, cancellationToken);
            var invoice = Invoice.CreateRenewal(
                tenantId,
                number,
                plan,
                subscription.Id,
                effectiveStart,
                effectiveStart.AddDays(voucher.ValueDays),
                now);
            invoice.MarkPaid(voucher.Code, userId, now);
            await _invoices.AddAsync(invoice, cancellationToken);
        }

        await _cache.RemoveAsync(SubscriptionEntitlementCache.Key(tenantId), cancellationToken);
        var entitlement = await _entitlement.GetEntitlementAsync(tenantId, cancellationToken);
        return Result.Success(entitlement);
    }
}

// ── Evaluate Subscription (idempotent) ──────────────────────────
/// <summary>
/// Self-healing evaluation any client may call to sync its entitlement: creates the missing
/// trial subscription, persists the debt transition, and auto-issues the open invoice for the
/// renewal period so the tenant can settle it. Safe to call repeatedly.
/// </summary>
public sealed record EvaluateSubscriptionCommand()
    : IRequest<Result<SubscriptionEntitlement>>, IRequiresTenantAdvisoryLock;

public sealed class EvaluateSubscriptionCommandHandler
    : IRequestHandler<EvaluateSubscriptionCommand, Result<SubscriptionEntitlement>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ISubscriptionRepository _subscriptions;
    private readonly IPlanRepository _plans;
    private readonly IInvoiceRepository _invoices;
    private readonly ISubscriptionEntitlementService _entitlement;
    private readonly ICacheService _cache;

    public EvaluateSubscriptionCommandHandler(
        ITenantContext tenantContext,
        ISubscriptionRepository subscriptions,
        IPlanRepository plans,
        IInvoiceRepository invoices,
        ISubscriptionEntitlementService entitlement,
        ICacheService cache)
    {
        _tenantContext = tenantContext;
        _subscriptions = subscriptions;
        _plans = plans;
        _invoices = invoices;
        _entitlement = entitlement;
        _cache = cache;
    }

    public async Task<Result<SubscriptionEntitlement>> Handle(
        EvaluateSubscriptionCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var now = DateTime.UtcNow;

        var subscription = await _subscriptions.GetForTenantAsync(tenantId, cancellationToken);
        if (subscription is null)
        {
            await _subscriptions.AddAsync(
                Subscription.StartTrial(tenantId, nowUtc: now), cancellationToken);
            return await CompleteAsync(tenantId, cancellationToken);
        }

        var plan = await _plans.GetByCodeAsync(subscription.PlanCode, cancellationToken);

        var evaluation = SubscriptionAccessEvaluator.Evaluate(
            subscription.Status, subscription.TrialEndedAtUtc, subscription.PaidUntilUtc, now);

        // Trial lapsed into debt: persist the transition and issue the payable renewal
        // invoice once (an open invoice already existing means it was already issued).
        if (evaluation.Status == SubscriptionStatus.Debt && subscription.Status != SubscriptionStatus.Debt)
        {
            subscription.MarkDebt(now);
            await _subscriptions.UpdateAsync(subscription, cancellationToken);

            if (plan is not null && await _invoices.GetOpenAsync(tenantId, cancellationToken) is null)
            {
                var effectiveStart = SubscriptionAccessEvaluator.EffectivePeriodStart(
                    subscription.PaidUntilUtc, now);
                var number = await _invoices.AllocateNumberAsync(tenantId, now, cancellationToken);
                await _invoices.AddAsync(Invoice.CreateRenewal(
                    tenantId,
                    number,
                    plan,
                    subscription.Id,
                    effectiveStart,
                    effectiveStart.AddMonths(1),
                    now), cancellationToken);
            }
        }

        return await CompleteAsync(tenantId, cancellationToken);
    }

    private async Task<Result<SubscriptionEntitlement>> CompleteAsync(
        Guid tenantId, CancellationToken cancellationToken)
    {
        await _cache.RemoveAsync(SubscriptionEntitlementCache.Key(tenantId), cancellationToken);
        var entitlement = await _entitlement.GetEntitlementAsync(tenantId, cancellationToken);
        return Result.Success(entitlement);
    }
}

// ── Mark Invoice Paid (platform/owner desk) ─────────────────────
/// <summary>
/// Owner confirms a manual phone payment (e.g. M-Pesa received into the owner's wallet) for an
/// open invoice and extends the tenant's subscription by the invoice's payable window
/// (counted from now / current paid-until so late settlements still buy fresh access).
/// </summary>
public sealed record MarkInvoicePaidCommand(Guid InvoiceId, string Reference)
    : IRequest<Result<InvoiceDto>>;

public sealed class MarkInvoicePaidCommandHandler
    : IRequestHandler<MarkInvoicePaidCommand, Result<InvoiceDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IInvoiceRepository _invoices;
    private readonly ISubscriptionRepository _subscriptions;
    private readonly ICacheService _cache;

    public MarkInvoicePaidCommandHandler(
        ITenantContext tenantContext,
        IInvoiceRepository invoices,
        ISubscriptionRepository subscriptions,
        ICacheService cache)
    {
        _tenantContext = tenantContext;
        _invoices = invoices;
        _subscriptions = subscriptions;
        _cache = cache;
    }

    public async Task<Result<InvoiceDto>> Handle(
        MarkInvoicePaidCommand command, CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;

        var invoice = await _invoices.GetByIdAnyTenantAsync(command.InvoiceId, cancellationToken);
        if (invoice is null)
        {
            return Error.NotFound("Invoice not found.");
        }

        if (invoice.Status != InvoiceStatus.Open)
        {
            return Error.Conflict("Only an open invoice can be marked paid.");
        }

        if (string.IsNullOrWhiteSpace(command.Reference))
        {
            return Error.Validation("A payment reference is required.");
        }

        invoice.MarkPaid(command.Reference.Trim(), _tenantContext.UserId, now);
        await _invoices.UpdateAsync(invoice, cancellationToken);

        var subscription = await _subscriptions.GetForTenantAsync(invoice.TenantId, cancellationToken);
        if (subscription is not null)
        {
            var payableDays = (invoice.PeriodEndUtc - invoice.PeriodStartUtc).TotalDays;
            if (payableDays >= 1)
            {
                var effectiveStart = SubscriptionAccessEvaluator.EffectivePeriodStart(
                    subscription.PaidUntilUtc, now);
                subscription.Paid(effectiveStart, TimeSpan.FromDays(payableDays), now);
                await _subscriptions.UpdateAsync(subscription, cancellationToken);
            }
        }

        await _cache.RemoveAsync(
            SubscriptionEntitlementCache.Key(invoice.TenantId), cancellationToken);
        return Result.Success(InvoiceMappers.ToDto(invoice));
    }
}

// ── Issue Vouchers (platform/owner desk) ────────────────────────
/// <summary>
/// Creates a batch of prepaid codes the owner sells (manual M-Pesa first; Flutterwave later).
/// Codes are CSPRNG-generated, unambiguously readable, and persisted with the issuing
/// platform identity for audit.
/// </summary>
public sealed record IssueVouchersCommand(int Count, int ValueDays, DateTime? ExpiresAtUtc)
    : IRequest<Result<IReadOnlyList<string>>>;

public sealed class IssueVouchersCommandHandler
    : IRequestHandler<IssueVouchersCommand, Result<IReadOnlyList<string>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IVoucherRepository _vouchers;

    public IssueVouchersCommandHandler(
        ITenantContext tenantContext, IVoucherRepository vouchers)
    {
        _tenantContext = tenantContext;
        _vouchers = vouchers;
    }

    public async Task<Result<IReadOnlyList<string>>> Handle(
        IssueVouchersCommand command, CancellationToken cancellationToken)
    {
        var issuerTenantId = _tenantContext.TenantId;
        var issuedByUserId = _tenantContext.UserId;

        var codes = new HashSet<string>(StringComparer.Ordinal);
        var created = new List<Voucher>(command.Count);
        while (created.Count < command.Count)
        {
            var code = VoucherCodes.Generate();
            if (!codes.Add(code))
            {
                continue; // collision within the batch: regenerate (astronomically unlikely)
            }

            var voucher = Voucher.Create(issuerTenantId, issuedByUserId, code, command.ValueDays, command.ExpiresAtUtc);
            created.Add(voucher);
        }

        foreach (var voucher in created)
        {
            await _vouchers.AddAsync(voucher, cancellationToken);
        }

        created[^1].RecordBatchIssued(codes.ToList(), issuedByUserId);

        return Result.Success<IReadOnlyList<string>>(codes.ToList());
    }
}

// ── Activate Package ────────────────────────────────────────────
public sealed record ActivatePackageCommand(string PlanCode)
    : IRequest<Result<IReadOnlyList<string>>>, IRequiresTenantAdvisoryLock;

public sealed class ActivatePackageCommandHandler
    : IRequestHandler<ActivatePackageCommand, Result<IReadOnlyList<string>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IPlanRepository _plans;
    private readonly ISubscriptionItemRepository _subscriptionItems;
    private readonly ICacheService _cache;

    public ActivatePackageCommandHandler(
        ITenantContext tenantContext,
        IPlanRepository plans,
        ISubscriptionItemRepository subscriptionItems,
        ICacheService cache)
    {
        _tenantContext = tenantContext;
        _plans = plans;
        _subscriptionItems = subscriptionItems;
        _cache = cache;
    }

    public async Task<Result<IReadOnlyList<string>>> Handle(
        ActivatePackageCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;

        if (string.IsNullOrWhiteSpace(command.PlanCode))
        {
            return Error.Validation("A plan code is required.");
        }

        var code = command.PlanCode.Trim();
        var plan = await _plans.GetByCodeAsync(code, cancellationToken);
        if (plan is null)
        {
            return Error.NotFound("Plan not found.");
        }

        if (!plan.IsActive)
        {
            return Error.Conflict("This plan is not available.");
        }

        if (!plan.IsPackage)
        {
            return Error.Validation("Only add-on packages can be activated.");
        }

        var current = await _subscriptionItems.ListForTenantAsync(tenantId, cancellationToken);
        if (current.Any(item => string.Equals(
                item.PlanCode, plan.Code, StringComparison.OrdinalIgnoreCase)))
        {
            return Error.Conflict("This package is already active.");
        }

        await _subscriptionItems.AddAsync(
            SubscriptionItem.Create(tenantId, plan.Code), cancellationToken);
        await _cache.RemoveAsync(SubscriptionEntitlementCache.Key(tenantId), cancellationToken);

        var packages = current
            .Select(item => item.PlanCode)
            .Append(plan.Code)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(package => package, StringComparer.Ordinal)
            .ToArray();

        return Result.Success<IReadOnlyList<string>>(packages);
    }
}

// ── Remove Package ──────────────────────────────────────────────
public sealed record RemovePackageCommand(string PlanCode)
    : IRequest<Result<IReadOnlyList<string>>>, IRequiresTenantAdvisoryLock;

public sealed class RemovePackageCommandHandler
    : IRequestHandler<RemovePackageCommand, Result<IReadOnlyList<string>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ISubscriptionItemRepository _subscriptionItems;
    private readonly ICacheService _cache;

    public RemovePackageCommandHandler(
        ITenantContext tenantContext,
        ISubscriptionItemRepository subscriptionItems,
        ICacheService cache)
    {
        _tenantContext = tenantContext;
        _subscriptionItems = subscriptionItems;
        _cache = cache;
    }

    public async Task<Result<IReadOnlyList<string>>> Handle(
        RemovePackageCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;

        if (string.IsNullOrWhiteSpace(command.PlanCode))
        {
            return Error.Validation("A plan code is required.");
        }

        var code = command.PlanCode.Trim();
        var item = await _subscriptionItems.GetForTenantByPlanAsync(tenantId, code, cancellationToken);
        if (item is null)
        {
            return Error.NotFound("This package is not active on the workspace.");
        }

        var current = await _subscriptionItems.ListForTenantAsync(tenantId, cancellationToken);
        item.Remove();
        await _subscriptionItems.RemoveAsync(item, cancellationToken);
        await _cache.RemoveAsync(SubscriptionEntitlementCache.Key(tenantId), cancellationToken);

        return Result.Success<IReadOnlyList<string>>(
            current
                .Select(existing => existing.PlanCode)
                .Where(existing => !string.Equals(
                    existing, item.PlanCode, StringComparison.OrdinalIgnoreCase))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .OrderBy(package => package, StringComparer.Ordinal)
                .ToArray());
    }
}