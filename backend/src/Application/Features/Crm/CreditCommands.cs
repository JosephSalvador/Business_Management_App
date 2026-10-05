using BusinessOS.Application.Ports;
using BusinessOS.Domain.Crm;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Crm.Commands;

public static class CreditMappers
{
    public static CustomerCreditDto ToDto(CustomerCredit cc) => new(
        cc.Id, cc.TenantId, cc.CustomerId, cc.Balance,
        cc.CreditLimit, cc.LastPaymentAt, cc.CreatedAt);

    public static CreditTransactionDto ToDto(CreditTransaction ct) => new(
        ct.Id, ct.TenantId, ct.CustomerId, ct.Type, ct.Amount,
        ct.BalanceAfter, ct.Description, ct.RelatedSaleId, ct.CreatedAt);
}

// ── Set Credit Limit ────────────────────────────────────────────
public sealed record SetCreditLimitCommand(
    Guid CustomerId, decimal Limit)
    : IRequest<Result<CustomerCreditDto>>, IRequiresTenantAdvisoryLock;

public sealed class SetCreditLimitCommandHandler
    : IRequestHandler<SetCreditLimitCommand, Result<CustomerCreditDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ICustomerCreditRepository _credits;

    public SetCreditLimitCommandHandler(ITenantContext tenantContext, ICustomerCreditRepository credits)
    {
        _tenantContext = tenantContext;
        _credits = credits;
    }

    public async Task<Result<CustomerCreditDto>> Handle(
        SetCreditLimitCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var credit = await _credits.GetByCustomerIdAsync(tenantId, command.CustomerId, cancellationToken);
        var created = credit is null;
        if (credit is null)
        {
            credit = CustomerCredit.Create(tenantId, command.CustomerId);
            await _credits.AddAsync(credit, cancellationToken);
        }

        credit.SetCreditLimit(command.Limit);
        if (!created)
        {
            await _credits.UpdateAsync(credit, cancellationToken);
        }
        return Result.Success(CreditMappers.ToDto(credit));
    }
}

// ── Record Credit Sale ──────────────────────────────────────────
public sealed record RecordCreditSaleCommand(
    Guid CustomerId, decimal Amount, string Description, Guid? RelatedSaleId)
    : IRequest<Result<CustomerCreditDto>>, IRequiresTenantAdvisoryLock;

public sealed class RecordCreditSaleCommandHandler
    : IRequestHandler<RecordCreditSaleCommand, Result<CustomerCreditDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ICustomerCreditRepository _credits;

    public RecordCreditSaleCommandHandler(ITenantContext tenantContext, ICustomerCreditRepository credits)
    {
        _tenantContext = tenantContext;
        _credits = credits;
    }

    public async Task<Result<CustomerCreditDto>> Handle(
        RecordCreditSaleCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var credit = await _credits.GetByCustomerIdAsync(tenantId, command.CustomerId, cancellationToken);
        var created = credit is null;
        if (credit is null)
        {
            credit = CustomerCredit.Create(tenantId, command.CustomerId);
            await _credits.AddAsync(credit, cancellationToken);
        }

        credit.RecordSale(command.Amount);
        if (!created)
        {
            await _credits.UpdateAsync(credit, cancellationToken);
        }

        var tx = CreditTransaction.Create(
            tenantId, command.CustomerId, CreditTransactionType.Sale,
            command.Amount, credit.Balance, command.Description, command.RelatedSaleId);
        await _credits.AddTransactionAsync(tx, cancellationToken);

        return Result.Success(CreditMappers.ToDto(credit));
    }
}

// ── Record Credit Payment ───────────────────────────────────────
public sealed record RecordCreditPaymentCommand(
    Guid CustomerId, decimal Amount, string Description)
    : IRequest<Result<CustomerCreditDto>>, IRequiresTenantAdvisoryLock;

public sealed class RecordCreditPaymentCommandHandler
    : IRequestHandler<RecordCreditPaymentCommand, Result<CustomerCreditDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly ICustomerCreditRepository _credits;

    public RecordCreditPaymentCommandHandler(ITenantContext tenantContext, ICustomerCreditRepository credits)
    {
        _tenantContext = tenantContext;
        _credits = credits;
    }

    public async Task<Result<CustomerCreditDto>> Handle(
        RecordCreditPaymentCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var credit = await _credits.GetByCustomerIdAsync(tenantId, command.CustomerId, cancellationToken);
        if (credit is null)
            return Error.NotFound("Customer credit record not found.");

        if (command.Amount > credit.Balance)
            return Error.Validation("Payment exceeds outstanding balance.");

        credit.RecordPayment(command.Amount);
        await _credits.UpdateAsync(credit, cancellationToken);

        var tx = CreditTransaction.Create(
            tenantId, command.CustomerId, CreditTransactionType.Payment,
            command.Amount, credit.Balance, command.Description);
        await _credits.AddTransactionAsync(tx, cancellationToken);

        return Result.Success(CreditMappers.ToDto(credit));
    }
}
