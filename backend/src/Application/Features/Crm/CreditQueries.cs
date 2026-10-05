using BusinessOS.Application.Features.Crm.Commands;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Crm;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Crm.Queries;

// ── Get Customer Credit ─────────────────────────────────────────
public sealed record GetCustomerCreditQuery(Guid CustomerId)
    : IRequest<Result<CustomerCreditDto?>>, IRequiresTenantAdvisoryLock;

public sealed class GetCustomerCreditQueryHandler
    : IRequestHandler<GetCustomerCreditQuery, Result<CustomerCreditDto?>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ICustomerCreditRepository _credits;

    public GetCustomerCreditQueryHandler(ITenantContext tenantContext, ICustomerCreditRepository credits)
    {
        _tenantContext = tenantContext;
        _credits = credits;
    }

    public async Task<Result<CustomerCreditDto?>> Handle(
        GetCustomerCreditQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var credit = await _credits.GetByCustomerIdAsync(tenantId, query.CustomerId, cancellationToken);
        // Resource-identifying GET driven by a path id: no credit record (whether the customer is
        // unknown or the record does not exist) is "not found", consistent with GET /customers/{id}.
        if (credit is null)
            return Error.NotFound("Customer credit record not found.");

        return Result.Success<CustomerCreditDto?>(CreditMappers.ToDto(credit));
    }
}

// ── List Outstanding Credit ─────────────────────────────────────
public sealed record ListOutstandingCreditQuery()
    : IRequest<Result<IReadOnlyList<CustomerCreditDto>>>, IRequiresTenantAdvisoryLock;

public sealed class ListOutstandingCreditQueryHandler
    : IRequestHandler<ListOutstandingCreditQuery, Result<IReadOnlyList<CustomerCreditDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ICustomerCreditRepository _credits;

    public ListOutstandingCreditQueryHandler(ITenantContext tenantContext, ICustomerCreditRepository credits)
    {
        _tenantContext = tenantContext;
        _credits = credits;
    }

    public async Task<Result<IReadOnlyList<CustomerCreditDto>>> Handle(
        ListOutstandingCreditQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var outstanding = await _credits.ListOutstandingAsync(tenantId, cancellationToken);
        return Result.Success<IReadOnlyList<CustomerCreditDto>>(
            outstanding.Select(CreditMappers.ToDto).ToList());
    }
}

// ── List Credit Transactions ────────────────────────────────────
public sealed record ListCreditTransactionsQuery(
    Guid CustomerId, int Page, int PageSize)
    : IRequest<Result<IReadOnlyList<CreditTransactionDto>>>, IRequiresTenantAdvisoryLock;

public sealed class ListCreditTransactionsQueryHandler
    : IRequestHandler<ListCreditTransactionsQuery, Result<IReadOnlyList<CreditTransactionDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ICustomerCreditRepository _credits;

    public ListCreditTransactionsQueryHandler(ITenantContext tenantContext, ICustomerCreditRepository credits)
    {
        _tenantContext = tenantContext;
        _credits = credits;
    }

    public async Task<Result<IReadOnlyList<CreditTransactionDto>>> Handle(
        ListCreditTransactionsQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var txs = await _credits.ListTransactionsAsync(
            tenantId, query.CustomerId, query.Page, query.PageSize, cancellationToken);
        return Result.Success<IReadOnlyList<CreditTransactionDto>>(
            txs.Select(CreditMappers.ToDto).ToList());
    }
}
