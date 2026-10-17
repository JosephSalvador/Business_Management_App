using BusinessOS.Application.Ports;
using BusinessOS.Domain.Billing;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Billing.Queries;

// ── List All Plans (Admin View) ──────────────────────────────────
public sealed record ListAllPlansAdminQuery()
    : IRequest<Result<IReadOnlyList<PlanAdminDto>>>;

public sealed class ListAllPlansAdminQueryHandler
    : IRequestHandler<ListAllPlansAdminQuery, Result<IReadOnlyList<PlanAdminDto>>>
{
    private readonly IPlanRepository _plans;

    public ListAllPlansAdminQueryHandler(IPlanRepository plans) => _plans = plans;

    public async Task<Result<IReadOnlyList<PlanAdminDto>>> Handle(
        ListAllPlansAdminQuery query, CancellationToken cancellationToken)
    {
        var plans = await _plans.ListAllAsync(cancellationToken);
        var dtos = plans.Select(p => new PlanAdminDto(
            p.Id,
            p.Code,
            p.Name,
            p.MonthlyPrice,
            p.Currency,
            p.FeatureKeys,
            p.MaxBranches,
            p.MaxUsers,
            p.MaxProducts,
            p.IsPackage,
            p.IsActive)).ToList();

        return Result.Success<IReadOnlyList<PlanAdminDto>>(dtos);
    }
}

// ── Get Payment Instructions (Client & Admin) ─────────────────────
public sealed record GetPaymentInstructionsQuery()
    : IRequest<Result<PaymentInstructionDto>>;

public sealed class GetPaymentInstructionsQueryHandler
    : IRequestHandler<GetPaymentInstructionsQuery, Result<PaymentInstructionDto>>
{
    private readonly IPaymentInstructionRepository _instructions;

    public GetPaymentInstructionsQueryHandler(IPaymentInstructionRepository instructions)
    {
        _instructions = instructions;
    }

    public async Task<Result<PaymentInstructionDto>> Handle(
        GetPaymentInstructionsQuery query, CancellationToken cancellationToken)
    {
        var instruction = await _instructions.GetOrCreateAsync(cancellationToken);
        return Result.Success(new PaymentInstructionDto(
            instruction.MpesaTill,
            instruction.AirtelMoney,
            instruction.BankName,
            instruction.BankAccountNumber,
            instruction.BankAccountName,
            instruction.WhatsAppContact,
            instruction.Notes));
    }
}

// ── List Vouchers (Admin View) ───────────────────────────────────
public sealed record ListVouchersAdminQuery(int Page = 1, int PageSize = 50, VoucherStatus? Status = null)
    : IRequest<Result<IReadOnlyList<VoucherAdminDto>>>;

public sealed class ListVouchersAdminQueryHandler
    : IRequestHandler<ListVouchersAdminQuery, Result<IReadOnlyList<VoucherAdminDto>>>
{
    private readonly IVoucherRepository _vouchers;

    public ListVouchersAdminQueryHandler(IVoucherRepository vouchers)
    {
        _vouchers = vouchers;
    }

    public async Task<Result<IReadOnlyList<VoucherAdminDto>>> Handle(
        ListVouchersAdminQuery query, CancellationToken cancellationToken)
    {
        var vouchers = await _vouchers.ListAsync(
            query.Page, query.PageSize, query.Status, cancellationToken);

        var dtos = vouchers.Select(v => new VoucherAdminDto(
            v.Id,
            v.Code,
            v.ValueDays,
            v.Status,
            v.CreatedAt,
            v.ExpiresAtUtc,
            v.RedeemedAtUtc,
            v.RedeemedByTenantId,
            v.TargetTenantId,
            v.PlanCode)).ToList();

        return Result.Success<IReadOnlyList<VoucherAdminDto>>(dtos);
    }
}
