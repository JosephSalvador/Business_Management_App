using BusinessOS.Domain.Finance;

namespace BusinessOS.Application.Features.Finance;

public sealed record MoneyAccountDto(
    Guid Id, Guid TenantId, string Name, MoneyAccountType Type,
    string? Reference, decimal Balance, bool IsActive, DateTime CreatedAt);

public sealed record MoneyAccountTransactionDto(
    Guid Id, Guid TenantId, Guid AccountId, TransactionType Type,
    decimal Amount, decimal BalanceAfter, string Description,
    Guid? RelatedAccountId, string? Reference, DateTime CreatedAt);

public sealed record CashSessionDto(
    Guid Id, Guid TenantId, Guid AccountId, decimal OpeningCash,
    decimal? ClosingCash, decimal? ExpectedCash, decimal? Variance,
    CashSessionStatus Status, DateTime OpenedAt, DateTime? ClosedAt,
    string? Notes, DateTime CreatedAt);
