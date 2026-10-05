using BusinessOS.Application.Features.Accounting.Commands;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Accounting;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Accounting.Queries;

// ── Update Account ───────────────────────────────────────────────
public sealed record UpdateAccountCommand(
    Guid AccountId, string Name, AccountType Type)
    : IRequest<Result<AccountDto>>, IRequiresTenantAdvisoryLock;

public sealed class UpdateAccountCommandHandler
    : IRequestHandler<UpdateAccountCommand, Result<AccountDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IAccountRepository _accounts;

    public UpdateAccountCommandHandler(ITenantContext tenantContext, IAccountRepository accounts)
    {
        _tenantContext = tenantContext;
        _accounts = accounts;
    }

    public async Task<Result<AccountDto>> Handle(
        UpdateAccountCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var account = await _accounts.GetByIdAsync(tenantId, command.AccountId, cancellationToken);
        if (account is null) return Error.NotFound("Account not found.");

        account.UpdateDetails(command.Name, command.Type);
        await _accounts.UpdateAsync(account, cancellationToken);
        return Result.Success(Commands.AccountingMappers.ToDto(account));
    }
}

// ── List Accounts ────────────────────────────────────────────────
public sealed record ListAccountsQuery(bool? IsActive)
    : IRequest<Result<IReadOnlyList<AccountDto>>>, IRequiresTenantAdvisoryLock;

public sealed class ListAccountsQueryHandler
    : IRequestHandler<ListAccountsQuery, Result<IReadOnlyList<AccountDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IAccountRepository _accounts;

    public ListAccountsQueryHandler(ITenantContext tenantContext, IAccountRepository accounts)
    {
        _tenantContext = tenantContext;
        _accounts = accounts;
    }

    public async Task<Result<IReadOnlyList<AccountDto>>> Handle(
        ListAccountsQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var accounts = await _accounts.ListAsync(tenantId, query.IsActive, cancellationToken);
        return Result.Success<IReadOnlyList<AccountDto>>(
            accounts.Select(Commands.AccountingMappers.ToDto).ToList());
    }
}

// ── Trial Balance ────────────────────────────────────────────────
public sealed record TrialBalanceQuery()
    : IRequest<Result<TrialBalanceDto>>, IRequiresTenantAdvisoryLock;

public sealed class TrialBalanceQueryHandler
    : IRequestHandler<TrialBalanceQuery, Result<TrialBalanceDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IAccountRepository _accounts;
    private readonly IJournalEntryRepository _journalEntries;

    public TrialBalanceQueryHandler(
        ITenantContext tenantContext, IAccountRepository accounts,
        IJournalEntryRepository journalEntries)
    {
        _tenantContext = tenantContext;
        _accounts = accounts;
        _journalEntries = journalEntries;
    }

    public async Task<Result<TrialBalanceDto>> Handle(
        TrialBalanceQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var accounts = await _accounts.ListAsync(tenantId, null, cancellationToken);
        var entryCount = await _journalEntries.CountAsync(tenantId, cancellationToken);

        if (entryCount == 0)
        {
            var emptyRows = accounts.Select(a =>
                new TrialBalanceRowDto(a.Id, a.Code, a.Name, a.Type, 0, 0, 0)).ToList();
            return Result.Success(new TrialBalanceDto(0, 0, emptyRows));
        }

        var debitByAccount = new Dictionary<Guid, decimal>();
        var creditByAccount = new Dictionary<Guid, decimal>();

        for (int page = 1; ; page++)
        {
            var batch = await _journalEntries.ListAsync(tenantId, page, 100, cancellationToken);
            if (batch.Count == 0) break;

            foreach (var entry in batch.Where(e => e.Status == JournalEntryStatus.Posted))
            {
                foreach (var line in entry.Lines)
                {
                    if (!debitByAccount.ContainsKey(line.AccountId))
                        debitByAccount[line.AccountId] = 0;
                    if (!creditByAccount.ContainsKey(line.AccountId))
                        creditByAccount[line.AccountId] = 0;

                    debitByAccount[line.AccountId] += line.DebitAmount;
                    creditByAccount[line.AccountId] += line.CreditAmount;
                }
            }
        }

        decimal totalDebit = 0, totalCredit = 0;
        var rows = new List<TrialBalanceRowDto>();

        foreach (var account in accounts)
        {
            var debit = debitByAccount.GetValueOrDefault(account.Id, 0);
            var credit = creditByAccount.GetValueOrDefault(account.Id, 0);
            totalDebit += debit;
            totalCredit += credit;
            rows.Add(new TrialBalanceRowDto(
                account.Id, account.Code, account.Name, account.Type,
                debit, credit, debit - credit));
        }

        return Result.Success(new TrialBalanceDto(totalDebit, totalCredit, rows));
    }
}

// ── General Ledger ───────────────────────────────────────────────
public sealed record GeneralLedgerQuery(DateTime? FromDate, DateTime? ToDate, Guid? AccountId)
    : IRequest<Result<GeneralLedgerDto>>, IRequiresTenantAdvisoryLock;

public sealed class GeneralLedgerQueryHandler
    : IRequestHandler<GeneralLedgerQuery, Result<GeneralLedgerDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IAccountRepository _accounts;
    private readonly IJournalEntryRepository _journalEntries;

    public GeneralLedgerQueryHandler(
        ITenantContext tenantContext, IAccountRepository accounts,
        IJournalEntryRepository journalEntries)
    {
        _tenantContext = tenantContext;
        _accounts = accounts;
        _journalEntries = journalEntries;
    }

    public async Task<Result<GeneralLedgerDto>> Handle(
        GeneralLedgerQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var accounts = await _accounts.ListAsync(tenantId, null, cancellationToken);

        if (query.AccountId.HasValue)
            accounts = accounts.Where(a => a.Id == query.AccountId.Value).ToList();

        var accountIds = accounts.Select(a => a.Id).ToHashSet();
        var linesByAccount = new Dictionary<Guid, List<GeneralLedgerLineDto>>();
        decimal totalDebit = 0, totalCredit = 0;

        for (int page = 1; ; page++)
        {
            var batch = await _journalEntries.ListAsync(tenantId, page, 100, cancellationToken);
            if (batch.Count == 0) break;

            foreach (var entry in batch.Where(e => e.Status == JournalEntryStatus.Posted))
            {
                if (query.FromDate.HasValue && entry.EntryDate < query.FromDate.Value) continue;
                if (query.ToDate.HasValue && entry.EntryDate > query.ToDate.Value) continue;

                foreach (var line in entry.Lines.Where(l => accountIds.Contains(l.AccountId)))
                {
                    if (!linesByAccount.ContainsKey(line.AccountId))
                        linesByAccount[line.AccountId] = new List<GeneralLedgerLineDto>();

                    linesByAccount[line.AccountId].Add(new GeneralLedgerLineDto(
                        entry.Id, entry.EntryDate, entry.Description,
                        line.DebitAmount, line.CreditAmount, line.Description));
                    totalDebit += line.DebitAmount;
                    totalCredit += line.CreditAmount;
                }
            }
        }

        var accountDtos = accounts.Select(a =>
        {
            var lines = linesByAccount.GetValueOrDefault(a.Id, new List<GeneralLedgerLineDto>());
            var closingBalance = lines.Sum(l => l.DebitAmount - l.CreditAmount);
            return new GeneralLedgerAccountDto(
                a.Id, a.Code, a.Name, a.Type, lines, closingBalance);
        }).ToList();

        return Result.Success(new GeneralLedgerDto(accountDtos, totalDebit, totalCredit));
    }
}

// ── Create Tenant Account Mapping ────────────────────────────────
public sealed record CreateTenantAccountMappingCommand(
    string MappingKey, Guid AccountId)
    : IRequest<Result<TenantAccountMappingDto>>, IRequiresTenantAdvisoryLock;

public sealed class CreateTenantAccountMappingCommandHandler
    : IRequestHandler<CreateTenantAccountMappingCommand, Result<TenantAccountMappingDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IAccountRepository _accounts;
    private readonly ITenantAccountMappingRepository _mappings;

    public CreateTenantAccountMappingCommandHandler(
        ITenantContext tenantContext, IAccountRepository accounts,
        ITenantAccountMappingRepository mappings)
    {
        _tenantContext = tenantContext;
        _accounts = accounts;
        _mappings = mappings;
    }

    public async Task<Result<TenantAccountMappingDto>> Handle(
        CreateTenantAccountMappingCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;

        var account = await _accounts.GetByIdAsync(tenantId, command.AccountId, cancellationToken);
        if (account is null) return Error.NotFound("Account not found.");

        var existing = await _mappings.GetByMappingKeyAsync(tenantId, command.MappingKey, cancellationToken);
        if (existing is not null)
            return Error.Conflict($"Mapping key '{command.MappingKey}' already exists.");

        var mapping = TenantAccountMapping.Create(tenantId, command.MappingKey, command.AccountId);
        await _mappings.AddAsync(mapping, cancellationToken);

        return Result.Success(new TenantAccountMappingDto(
            mapping.Id, mapping.TenantId, mapping.MappingKey, mapping.AccountId, mapping.CreatedAt));
    }
}

// ── Get Tenant Account Mapping ───────────────────────────────────
public sealed record GetTenantAccountMappingQuery(string MappingKey)
    : IRequest<Result<TenantAccountMappingDto?>>, IRequiresTenantAdvisoryLock;

public sealed class GetTenantAccountMappingQueryHandler
    : IRequestHandler<GetTenantAccountMappingQuery, Result<TenantAccountMappingDto?>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ITenantAccountMappingRepository _mappings;

    public GetTenantAccountMappingQueryHandler(
        ITenantContext tenantContext, ITenantAccountMappingRepository mappings)
    {
        _tenantContext = tenantContext;
        _mappings = mappings;
    }

    public async Task<Result<TenantAccountMappingDto?>> Handle(
        GetTenantAccountMappingQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var mapping = await _mappings.GetByMappingKeyAsync(tenantId, query.MappingKey, cancellationToken);
        // Resource-identifying GET driven by a path key: a missing mapping is "not found".
        if (mapping is null) return Error.NotFound("Tenant account mapping not found.");

        return Result.Success<TenantAccountMappingDto?>(new TenantAccountMappingDto(
            mapping.Id, mapping.TenantId, mapping.MappingKey, mapping.AccountId, mapping.CreatedAt));
    }
}

// ── List Expenses ───────────────────────────────────────────────
public sealed record ListExpensesQuery(
    int Page, int PageSize, DateTime? FromDate, DateTime? ToDate, string? Search)
    : IRequest<Result<PagedExpenses>>, IRequiresTenantAdvisoryLock;

public sealed class ListExpensesQueryHandler
    : IRequestHandler<ListExpensesQuery, Result<PagedExpenses>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IExpenseRepository _expenses;

    public ListExpensesQueryHandler(ITenantContext tenantContext, IExpenseRepository expenses)
    {
        _tenantContext = tenantContext;
        _expenses = expenses;
    }

    public async Task<Result<PagedExpenses>> Handle(
        ListExpensesQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var items = await _expenses.ListAsync(
            tenantId, query.Page, query.PageSize,
            query.FromDate, query.ToDate, query.Search, cancellationToken);
        var total = await _expenses.CountAsync(
            tenantId, query.FromDate, query.ToDate, query.Search, cancellationToken);

        var categoryNames = (await _expenses.ListCategoriesAsync(tenantId, cancellationToken))
            .ToDictionary(c => c.Id, c => c.Name);

        var dtos = items
            .Select(e => AccountingMappers.ToDto(
                e,
                e.CategoryId is not null && categoryNames.TryGetValue(e.CategoryId.Value, out var name)
                    ? name
                    : null))
            .ToList();
        return Result.Success(new PagedExpenses(dtos, total));
    }
}

// ── Get Expense ─────────────────────────────────────────────────
public sealed record GetExpenseQuery(Guid ExpenseId)
    : IRequest<Result<ExpenseDto>>, IRequiresTenantAdvisoryLock;

public sealed class GetExpenseQueryHandler
    : IRequestHandler<GetExpenseQuery, Result<ExpenseDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IExpenseRepository _expenses;

    public GetExpenseQueryHandler(ITenantContext tenantContext, IExpenseRepository expenses)
    {
        _tenantContext = tenantContext;
        _expenses = expenses;
    }

    public async Task<Result<ExpenseDto>> Handle(
        GetExpenseQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var expense = await _expenses.GetByIdAsync(tenantId, query.ExpenseId, cancellationToken);
        if (expense is null) return Error.NotFound("Expense not found.");

        string? categoryName = null;
        if (expense.CategoryId is not null)
        {
            var category = await _expenses.GetCategoryByIdAsync(
                tenantId, expense.CategoryId.Value, cancellationToken);
            categoryName = category?.Name;
        }

        return Result.Success(AccountingMappers.ToDto(expense, categoryName));
    }
}

// ── List Expense Categories ─────────────────────────────────────
public sealed record ListExpenseCategoriesQuery()
    : IRequest<Result<IReadOnlyList<ExpenseCategoryDto>>>, IRequiresTenantAdvisoryLock;

public sealed class ListExpenseCategoriesQueryHandler
    : IRequestHandler<ListExpenseCategoriesQuery, Result<IReadOnlyList<ExpenseCategoryDto>>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IExpenseRepository _expenses;

    public ListExpenseCategoriesQueryHandler(ITenantContext tenantContext, IExpenseRepository expenses)
    {
        _tenantContext = tenantContext;
        _expenses = expenses;
    }

    public async Task<Result<IReadOnlyList<ExpenseCategoryDto>>> Handle(
        ListExpenseCategoriesQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var categories = await _expenses.ListCategoriesAsync(tenantId, cancellationToken);
        return Result.Success<IReadOnlyList<ExpenseCategoryDto>>(
            categories.Select(AccountingMappers.ToDto).ToList());
    }
}

// ── Expense Summary ─────────────────────────────────────────────
public sealed record GetExpenseSummaryQuery(DateTime? FromDate, DateTime? ToDate)
    : IRequest<Result<ExpenseSummaryDto>>, IRequiresTenantAdvisoryLock;

public sealed class GetExpenseSummaryQueryHandler
    : IRequestHandler<GetExpenseSummaryQuery, Result<ExpenseSummaryDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IExpenseRepository _expenses;

    public GetExpenseSummaryQueryHandler(ITenantContext tenantContext, IExpenseRepository expenses)
    {
        _tenantContext = tenantContext;
        _expenses = expenses;
    }

    public async Task<Result<ExpenseSummaryDto>> Handle(
        GetExpenseSummaryQuery query, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;

        var now = DateTime.UtcNow;
        var from = query.FromDate ?? new DateTime(now.Year, now.Month, 1, 0, 0, 0, DateTimeKind.Utc);
        var to = query.ToDate ?? new DateTime(now.Year, now.Month, 1, 0, 0, 0, DateTimeKind.Utc)
            .AddMonths(1)
            .AddTicks(-1);
        if (query.FromDate.HasValue && query.ToDate.HasValue && query.FromDate > query.ToDate)
        {
            return Error.Validation("FromDate must be before or equal to ToDate.");
        }

        var summary = await _expenses.GetSummaryAsync(tenantId, from, to, cancellationToken);
        return Result.Success(AccountingMappers.ToDto(summary));
    }
}
