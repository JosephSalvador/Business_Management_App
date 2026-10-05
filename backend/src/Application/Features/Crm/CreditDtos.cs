using BusinessOS.Domain.Crm;

namespace BusinessOS.Application.Features.Crm;

public sealed record CustomerCreditDto(
    Guid Id, Guid TenantId, Guid CustomerId, decimal Balance,
    decimal CreditLimit, DateTime? LastPaymentAt, DateTime CreatedAt);

public sealed record CreditTransactionDto(
    Guid Id, Guid TenantId, Guid CustomerId, CreditTransactionType Type,
    decimal Amount, decimal BalanceAfter, string Description,
    Guid? RelatedSaleId, DateTime CreatedAt);
