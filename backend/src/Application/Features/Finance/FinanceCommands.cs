using BusinessOS.Application.Ports;
using BusinessOS.Domain.Finance;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Finance.Commands;

public static class FinanceMappers
{
    public static MoneyAccountDto ToDto(MoneyAccount a) => new(
        a.Id, a.TenantId, a.Name, a.Type, a.Reference, a.Balance, a.IsActive, a.CreatedAt);

    public static MoneyAccountTransactionDto ToDto(MoneyAccountTransaction t) => new(
        t.Id, t.TenantId, t.AccountId, t.Type, t.Amount,
        t.BalanceAfter, t.Description, t.RelatedAccountId, t.Reference, t.CreatedAt);

    public static CashSessionDto ToDto(CashSession s) => new(
        s.Id, s.TenantId, s.AccountId, s.OpeningCash, s.ClosingCash,
        s.ExpectedCash, s.Variance, s.Status, s.OpenedAt, s.ClosedAt, s.Notes, s.CreatedAt);
}

// ── Create Money Account ────────────────────────────────────────
public sealed record CreateMoneyAccountCommand(
    string Name, MoneyAccountType Type, string? Reference)
    : IRequest<Result<MoneyAccountDto>>, IRequiresTenantAdvisoryLock;

public sealed class CreateMoneyAccountCommandHandler
    : IRequestHandler<CreateMoneyAccountCommand, Result<MoneyAccountDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IMoneyAccountRepository _accounts;

    public CreateMoneyAccountCommandHandler(ITenantContext tenantContext, IMoneyAccountRepository accounts)
    {
        _tenantContext = tenantContext;
        _accounts = accounts;
    }

    public async Task<Result<MoneyAccountDto>> Handle(
        CreateMoneyAccountCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var existing = await _accounts.ListAsync(tenantId, cancellationToken);
        if (existing.Any(a => a.Name.Equals(command.Name, StringComparison.OrdinalIgnoreCase)))
            return Error.Conflict($"An account named '{command.Name}' already exists.");

        var account = MoneyAccount.Create(tenantId, command.Name, command.Type, command.Reference);
        await _accounts.AddAsync(account, cancellationToken);
        return Result.Success(FinanceMappers.ToDto(account));
    }
}

// ── Transfer Between Accounts ───────────────────────────────────
public sealed record TransferMoneyCommand(
    Guid FromAccountId, Guid ToAccountId, decimal Amount, string Description)
    : IRequest<Result>, IRequiresTenantAdvisoryLock;

public sealed class TransferMoneyCommandHandler
    : IRequestHandler<TransferMoneyCommand, Result>
{
    private readonly ITenantContext _tenantContext;
    private readonly IMoneyAccountRepository _accounts;

    public TransferMoneyCommandHandler(ITenantContext tenantContext, IMoneyAccountRepository accounts)
    {
        _tenantContext = tenantContext;
        _accounts = accounts;
    }

    public async Task<Result> Handle(
        TransferMoneyCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        if (command.FromAccountId == command.ToAccountId)
            return Result.Failure(Error.Validation("Cannot transfer to the same account."));

        var from = await _accounts.GetByIdAsync(tenantId, command.FromAccountId, cancellationToken);
        if (from is null) return Result.Failure(Error.NotFound("Source account not found."));

        var to = await _accounts.GetByIdAsync(tenantId, command.ToAccountId, cancellationToken);
        if (to is null) return Result.Failure(Error.NotFound("Destination account not found."));

        try
        {
            from.Debit(command.Amount);
        }
        catch (InvalidOperationException ex)
        {
            return Result.Failure(Error.Validation(ex.Message));
        }

        to.Credit(command.Amount);

        await _accounts.UpdateAsync(from, cancellationToken);
        await _accounts.UpdateAsync(to, cancellationToken);

        var debitTx = MoneyAccountTransaction.Create(
            tenantId, from.Id, TransactionType.Debit, command.Amount,
            from.Balance, $"Transfer to {to.Name}", to.Id);
        var creditTx = MoneyAccountTransaction.Create(
            tenantId, to.Id, TransactionType.Credit, command.Amount,
            to.Balance, $"Transfer from {from.Name}", from.Id);

        await _accounts.AddTransactionAsync(debitTx, cancellationToken);
        await _accounts.AddTransactionAsync(creditTx, cancellationToken);

        return Result.Success();
    }
}

// ── Record Income ───────────────────────────────────────────────
public sealed record RecordIncomeCommand(
    Guid AccountId, decimal Amount, string Description)
    : IRequest<Result>, IRequiresTenantAdvisoryLock;

public sealed class RecordIncomeCommandHandler
    : IRequestHandler<RecordIncomeCommand, Result>
{
    private readonly ITenantContext _tenantContext;
    private readonly IMoneyAccountRepository _accounts;

    public RecordIncomeCommandHandler(ITenantContext tenantContext, IMoneyAccountRepository accounts)
    {
        _tenantContext = tenantContext;
        _accounts = accounts;
    }

    public async Task<Result> Handle(
        RecordIncomeCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var account = await _accounts.GetByIdAsync(tenantId, command.AccountId, cancellationToken);
        if (account is null) return Result.Failure(Error.NotFound("Account not found."));

        account.Credit(command.Amount);
        await _accounts.UpdateAsync(account, cancellationToken);

        var tx = MoneyAccountTransaction.Create(
            tenantId, account.Id, TransactionType.Credit, command.Amount,
            account.Balance, command.Description);
        await _accounts.AddTransactionAsync(tx, cancellationToken);

        return Result.Success();
    }
}

// ── Record Expense from Account ─────────────────────────────────
public sealed record RecordAccountExpenseCommand(
    Guid AccountId, decimal Amount, string Description)
    : IRequest<Result>, IRequiresTenantAdvisoryLock;

public sealed class RecordAccountExpenseCommandHandler
    : IRequestHandler<RecordAccountExpenseCommand, Result>
{
    private readonly ITenantContext _tenantContext;
    private readonly IMoneyAccountRepository _accounts;

    public RecordAccountExpenseCommandHandler(ITenantContext tenantContext, IMoneyAccountRepository accounts)
    {
        _tenantContext = tenantContext;
        _accounts = accounts;
    }

    public async Task<Result> Handle(
        RecordAccountExpenseCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var account = await _accounts.GetByIdAsync(tenantId, command.AccountId, cancellationToken);
        if (account is null) return Result.Failure(Error.NotFound("Account not found."));

        try
        {
            account.Debit(command.Amount);
        }
        catch (InvalidOperationException ex)
        {
            return Result.Failure(Error.Validation(ex.Message));
        }

        await _accounts.UpdateAsync(account, cancellationToken);

        var tx = MoneyAccountTransaction.Create(
            tenantId, account.Id, TransactionType.Debit, command.Amount,
            account.Balance, command.Description);
        await _accounts.AddTransactionAsync(tx, cancellationToken);

        return Result.Success();
    }
}

// ── Open Cash Session ───────────────────────────────────────────
public sealed record OpenCashSessionCommand(
    Guid AccountId, decimal OpeningCash, Guid? Id = null)
    : IRequest<Result<CashSessionDto>>, IRequiresTenantAdvisoryLock;

public sealed class OpenCashSessionCommandHandler
    : IRequestHandler<OpenCashSessionCommand, Result<CashSessionDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ICashSessionRepository _sessions;
    private readonly IMoneyAccountRepository _accounts;

    public OpenCashSessionCommandHandler(
        ITenantContext tenantContext, ICashSessionRepository sessions, IMoneyAccountRepository accounts)
    {
        _tenantContext = tenantContext;
        _sessions = sessions;
        _accounts = accounts;
    }

    public async Task<Result<CashSessionDto>> Handle(
        OpenCashSessionCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var account = await _accounts.GetByIdAsync(tenantId, command.AccountId, cancellationToken);
        if (account is null) return Error.NotFound("Account not found.");

        // Idempotency: if specific SessionId was supplied, check if that session already exists
        if (command.Id.HasValue && command.Id.Value != Guid.Empty)
        {
            var existingById = await _sessions.GetByIdAsync(tenantId, command.Id.Value, cancellationToken);
            if (existingById is not null)
            {
                return Result.Success(FinanceMappers.ToDto(existingById));
            }
        }

        var existing = await _sessions.GetOpenSessionAsync(tenantId, command.AccountId, cancellationToken);
        if (existing is not null)
        {
            // If the client sent an Id matching the existing open session, replay it
            if (command.Id.HasValue && existing.Id == command.Id.Value)
            {
                return Result.Success(FinanceMappers.ToDto(existing));
            }
            return Error.Conflict("A cash session is already open for this account.");
        }

        var session = CashSession.Open(tenantId, command.AccountId, command.OpeningCash, command.Id);
        await _sessions.AddAsync(session, cancellationToken);
        return Result.Success(FinanceMappers.ToDto(session));
    }
}

// ── Close Cash Session ──────────────────────────────────────────
public sealed record CloseCashSessionCommand(
    Guid SessionId, decimal ClosingCash, string? Notes)
    : IRequest<Result<CashSessionDto>>, IRequiresTenantAdvisoryLock;

public sealed class CloseCashSessionCommandHandler
    : IRequestHandler<CloseCashSessionCommand, Result<CashSessionDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ICashSessionRepository _sessions;

    public CloseCashSessionCommandHandler(ITenantContext tenantContext, ICashSessionRepository sessions)
    {
        _tenantContext = tenantContext;
        _sessions = sessions;
    }

    public async Task<Result<CashSessionDto>> Handle(
        CloseCashSessionCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var session = await _sessions.GetByIdAsync(tenantId, command.SessionId, cancellationToken);
        if (session is null) return Error.NotFound("Cash session not found.");

        // Idempotency: if session was already closed, return it safely
        if (session.Status == CashSessionStatus.Closed)
        {
            return Result.Success(FinanceMappers.ToDto(session));
        }

        // Expected = opening + net sales (simplified: for now just use opening as expected)
        var expected = session.OpeningCash;
        session.Close(command.ClosingCash, expected, command.Notes);
        await _sessions.UpdateAsync(session, cancellationToken);
        return Result.Success(FinanceMappers.ToDto(session));
    }
}