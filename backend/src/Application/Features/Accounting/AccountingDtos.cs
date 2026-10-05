using BusinessOS.Domain.Accounting;

namespace BusinessOS.Application.Features.Accounting;

public sealed record AccountDto(
    Guid Id, Guid TenantId, string Code, string Name,
    AccountType Type, bool IsActive, DateTime CreatedAt);

public sealed record JournalEntryLineDto(
    Guid Id, Guid AccountId, decimal DebitAmount, decimal CreditAmount, string? Description);

public sealed record JournalEntryDto(
    Guid Id, Guid TenantId, string Description, DateTime EntryDate,
    string? SourceType, Guid? SourceId, JournalEntryStatus Status,
    decimal TotalDebit, decimal TotalCredit, DateTime? PostedAt,
    DateTime? VoidedAt, IReadOnlyList<JournalEntryLineDto> Lines, DateTime CreatedAt);

public sealed record TenantAccountMappingDto(
    Guid Id, Guid TenantId, string MappingKey, Guid AccountId, DateTime CreatedAt);

public sealed record TrialBalanceRowDto(
    Guid AccountId, string Code, string Name, AccountType Type,
    decimal TotalDebit, decimal TotalCredit, decimal Balance);

public sealed record TrialBalanceDto(
    decimal TotalDebit, decimal TotalCredit, IReadOnlyList<TrialBalanceRowDto> Rows);

public sealed record GeneralLedgerLineDto(
    Guid JournalEntryId, DateTime EntryDate, string Description,
    decimal DebitAmount, decimal CreditAmount, string? LineDescription);

public sealed record GeneralLedgerAccountDto(
    Guid AccountId, string Code, string Name, AccountType Type,
    IReadOnlyList<GeneralLedgerLineDto> Lines, decimal ClosingBalance);

public sealed record GeneralLedgerDto(
    IReadOnlyList<GeneralLedgerAccountDto> Accounts, decimal TotalDebit, decimal TotalCredit);

public sealed record ExpenseDto(
    Guid Id, Guid TenantId, Guid? CategoryId, string Description, decimal Amount,
    DateTime ExpenseDate, string? PaymentMethod, string? Reference, string? Notes,
    DateTime CreatedAt, string? CategoryName = null);

public sealed record PagedExpenses(
    IReadOnlyList<ExpenseDto> Items, int Total);

public sealed record ExpenseCategoryDto(
    Guid Id, Guid TenantId, string Name, DateTime CreatedAt);

public sealed record ExpenseSummaryDto(
    decimal Total, IReadOnlyList<ExpenseCategoryTotalDto> ByCategory);

public sealed record ExpenseCategoryTotalDto(
    Guid? CategoryId, string? CategoryName, decimal Total);
