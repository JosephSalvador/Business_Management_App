using BusinessOS.Application.Features.Finance.Commands;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Finance;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Finance.Queries;

// ── List Money Accounts ─────────────────────────────────────────
public sealed record ListMoneyAccountsQuery()
    : IRequest<Result<IReadOnlyList<MoneyAccountDto>>>, IRequiresTenantAdvisoryLock;

public sealed class ListMoneyAccountsQueryHandler
    : IRequestHandler<ListMoneyAccountsQuery, Result<IReadOnlyList<MoneyAccountDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IMoneyAccountRepository _accounts;

    public ListMoneyAccountsQueryHandler(ITenantContext tenantContext, IMoneyAccountRepository accounts)
    {
        _tenantContext = tenantContext;
        _accounts = accounts;
    }

    public async Task<Result<IReadOnlyList<MoneyAccountDto>>> Handle(
        ListMoneyAccountsQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var accounts = await _accounts.ListAsync(tenantId, cancellationToken);
        return Result.Success<IReadOnlyList<MoneyAccountDto>>(
            accounts.Select(FinanceMappers.ToDto).ToList());
    }
}

// ── Get Money Account ───────────────────────────────────────────
public sealed record GetMoneyAccountQuery(Guid AccountId)
    : IRequest<Result<MoneyAccountDto>>, IRequiresTenantAdvisoryLock;

public sealed class GetMoneyAccountQueryHandler
    : IRequestHandler<GetMoneyAccountQuery, Result<MoneyAccountDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IMoneyAccountRepository _accounts;

    public GetMoneyAccountQueryHandler(ITenantContext tenantContext, IMoneyAccountRepository accounts)
    {
        _tenantContext = tenantContext;
        _accounts = accounts;
    }

    public async Task<Result<MoneyAccountDto>> Handle(
        GetMoneyAccountQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var account = await _accounts.GetByIdAsync(tenantId, query.AccountId, cancellationToken);
        if (account is null) return Error.NotFound("Account not found.");
        return Result.Success(FinanceMappers.ToDto(account));
    }
}

// ── List Account Transactions ───────────────────────────────────
public sealed record ListAccountTransactionsQuery(
    Guid AccountId, int Page, int PageSize)
    : IRequest<Result<IReadOnlyList<MoneyAccountTransactionDto>>>, IRequiresTenantAdvisoryLock;

public sealed class ListAccountTransactionsQueryHandler
    : IRequestHandler<ListAccountTransactionsQuery, Result<IReadOnlyList<MoneyAccountTransactionDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IMoneyAccountRepository _accounts;

    public ListAccountTransactionsQueryHandler(ITenantContext tenantContext, IMoneyAccountRepository accounts)
    {
        _tenantContext = tenantContext;
        _accounts = accounts;
    }

    public async Task<Result<IReadOnlyList<MoneyAccountTransactionDto>>> Handle(
        ListAccountTransactionsQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var txs = await _accounts.ListTransactionsAsync(
            tenantId, query.AccountId, query.Page, query.PageSize, cancellationToken);
        return Result.Success<IReadOnlyList<MoneyAccountTransactionDto>>(
            txs.Select(FinanceMappers.ToDto).ToList());
    }
}

// ── Get Current Cash Session ────────────────────────────────────
public sealed record GetCurrentCashSessionQuery(Guid AccountId)
    : IRequest<Result<CashSessionDto?>>, IRequiresTenantAdvisoryLock;

public sealed class GetCurrentCashSessionQueryHandler
    : IRequestHandler<GetCurrentCashSessionQuery, Result<CashSessionDto?>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ICashSessionRepository _sessions;

    public GetCurrentCashSessionQueryHandler(ITenantContext tenantContext, ICashSessionRepository sessions)
    {
        _tenantContext = tenantContext;
        _sessions = sessions;
    }

    public async Task<Result<CashSessionDto?>> Handle(
        GetCurrentCashSessionQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var session = await _sessions.GetOpenSessionAsync(tenantId, query.AccountId, cancellationToken);
        return Result.Success(session is null ? null : FinanceMappers.ToDto(session));
    }
}