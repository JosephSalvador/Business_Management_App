using BusinessOS.Application.Ports;
using BusinessOS.Domain.Billing;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Billing.Queries;

// ── Get Subscription (entitlement) ──────────────────────────────
/// <summary>
/// Subscriber view of the workspace's subscription. Reads the service-grade entitlement —
/// status/access/features are derived from the subscription dates by the evaluator.
/// </summary>
public sealed record GetSubscriptionQuery()
    : IRequest<Result<SubscriptionEntitlement>>, IRequiresTenantAdvisoryLock;

public sealed class GetSubscriptionQueryHandler
    : IRequestHandler<GetSubscriptionQuery, Result<SubscriptionEntitlement>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ISubscriptionEntitlementService _entitlement;

    public GetSubscriptionQueryHandler(
        ITenantContext tenantContext,
        ISubscriptionEntitlementService entitlement)
    {
        _tenantContext = tenantContext;
        _entitlement = entitlement;
    }

    public async Task<Result<SubscriptionEntitlement>> Handle(
        GetSubscriptionQuery query, CancellationToken cancellationToken)
        => Result.Success(
            await _entitlement.GetEntitlementAsync(_tenantContext.TenantId, cancellationToken));
}

// ── List Plans ──────────────────────────────────────────────────
public sealed record ListPlansQuery()
    : IRequest<Result<IReadOnlyList<PlanDto>>>, IRequiresTenantAdvisoryLock;

public sealed class ListPlansQueryHandler
    : IRequestHandler<ListPlansQuery, Result<IReadOnlyList<PlanDto>>>
{
    private readonly IPlanRepository _plans;

    public ListPlansQueryHandler(IPlanRepository plans) => _plans = plans;

    public async Task<Result<IReadOnlyList<PlanDto>>> Handle(
        ListPlansQuery query, CancellationToken cancellationToken)
    {
        var plans = await _plans.ListActiveAsync(cancellationToken);
        return Result.Success<IReadOnlyList<PlanDto>>(plans.Select(PlanMappers.ToDto).ToList());
    }
}

// ── List Invoices ───────────────────────────────────────────────
public sealed record ListInvoicesQuery()
    : IRequest<Result<IReadOnlyList<InvoiceDto>>>, IRequiresTenantAdvisoryLock;

public sealed class ListInvoicesQueryHandler
    : IRequestHandler<ListInvoicesQuery, Result<IReadOnlyList<InvoiceDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IInvoiceRepository _invoices;

    public ListInvoicesQueryHandler(ITenantContext tenantContext, IInvoiceRepository invoices)
    {
        _tenantContext = tenantContext;
        _invoices = invoices;
    }

    public async Task<Result<IReadOnlyList<InvoiceDto>>> Handle(
        ListInvoicesQuery query, CancellationToken cancellationToken)
    {
        var invoices = await _invoices.ListAsync(_tenantContext.TenantId, cancellationToken);
        return Result.Success<IReadOnlyList<InvoiceDto>>(invoices.Select(InvoiceMappers.ToDto).ToList());
    }
}

// ── Get Invoice ─────────────────────────────────────────────────
public sealed record GetInvoiceQuery(Guid Id)
    : IRequest<Result<InvoiceDto>>, IRequiresTenantAdvisoryLock;

public sealed class GetInvoiceQueryHandler
    : IRequestHandler<GetInvoiceQuery, Result<InvoiceDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IInvoiceRepository _invoices;

    public GetInvoiceQueryHandler(ITenantContext tenantContext, IInvoiceRepository invoices)
    {
        _tenantContext = tenantContext;
        _invoices = invoices;
    }

    public async Task<Result<InvoiceDto>> Handle(
        GetInvoiceQuery query, CancellationToken cancellationToken)
    {
        var invoice = await _invoices.GetByIdAsync(
            _tenantContext.TenantId, query.Id, cancellationToken);
        if (invoice is null)
        {
            return Error.NotFound("Invoice not found.");
        }

        return Result.Success(InvoiceMappers.ToDto(invoice));
    }
}

// ── List Billing Debts (platform/owner desk) ────────────────────
public sealed record ListBillingDebtsQuery()
    : IRequest<Result<IReadOnlyList<BillingDebtDto>>>;

public sealed class ListBillingDebtsQueryHandler
    : IRequestHandler<ListBillingDebtsQuery, Result<IReadOnlyList<BillingDebtDto>>>
{
    private readonly IInvoiceRepository _invoices;

    public ListBillingDebtsQueryHandler(IInvoiceRepository invoices) => _invoices = invoices;

    public async Task<Result<IReadOnlyList<BillingDebtDto>>> Handle(
        ListBillingDebtsQuery query, CancellationToken cancellationToken)
    {
        var debts = await _invoices.ListDebtsAsync(cancellationToken);
        return Result.Success<IReadOnlyList<BillingDebtDto>>(
            debts.Select(d => new BillingDebtDto(
                d.InvoiceId, d.InvoiceNumber, d.TenantId, d.TenantName,
                d.Amount, d.Currency, d.IssuedAtUtc, d.Reference)).ToList());
    }
}

// ── Get Capabilities ────────────────────────────────────────────
public sealed record GetCapabilitiesQuery() : IRequest<Result<CapabilitiesDto>>;

public sealed class GetCapabilitiesQueryHandler
    : IRequestHandler<GetCapabilitiesQuery, Result<CapabilitiesDto>>
{
    private static readonly TimeSpan OfflineGrace = TimeSpan.FromDays(7);
    private static readonly TimeSpan OfflineCeiling = TimeSpan.FromDays(30);

    private readonly ITenantContext _tenantContext;
    private readonly ISubscriptionEntitlementService _entitlement;
    private readonly ICacheService _cache;

    public GetCapabilitiesQueryHandler(
        ITenantContext tenantContext,
        ISubscriptionEntitlementService entitlement,
        ICacheService cache)
    {
        _tenantContext = tenantContext;
        _entitlement = entitlement;
        _cache = cache;
    }

    public async Task<Result<CapabilitiesDto>> Handle(
        GetCapabilitiesQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var key = SubscriptionEntitlementCache.Key(tenantId);
        var entitlement = await _cache.GetAsync<SubscriptionEntitlement>(key, cancellationToken);
        if (entitlement is null)
        {
            entitlement = await _entitlement.GetEntitlementAsync(tenantId, cancellationToken);
            await _cache.SetAsync(
                key, entitlement, SubscriptionEntitlementCache.Lifetime, cancellationToken);
        }

        var now = DateTime.UtcNow;
        var offlineCeiling = now.Add(OfflineCeiling);
        var validOfflineUntil = entitlement.NextDueUtc is { } due
            ? (due.Add(OfflineGrace) < offlineCeiling ? due.Add(OfflineGrace) : offlineCeiling)
            : offlineCeiling;

        return Result.Success(new CapabilitiesDto(
            entitlement.EffectiveFeatureKeys,
            entitlement.PlanFeatureKeys ?? entitlement.EffectiveFeatureKeys,
            entitlement.Packages ?? Array.Empty<string>(),
            entitlement.PlanCode,
            (int)entitlement.AccessLevel,
            (int)entitlement.Status,
            entitlement.EvaluatedAtUtc,
            validOfflineUntil,
            entitlement.NextDueUtc,
            entitlement.HasOpenInvoice,
            entitlement.MaxBranches,
            entitlement.MaxUsers,
            entitlement.MaxProducts));
    }
}