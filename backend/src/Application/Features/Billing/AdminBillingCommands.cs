using BusinessOS.Application.Ports;
using BusinessOS.Domain.Billing;
using BusinessOS.Domain.Features;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Billing.Commands;

// ── Create Plan / Package ─────────────────────────────────────────
public sealed record CreatePlanCommand(
    string Code,
    string Name,
    decimal MonthlyPrice,
    string Currency,
    string[] FeatureKeys,
    int? MaxBranches = null,
    int? MaxUsers = null,
    int? MaxProducts = null,
    bool IsPackage = false)
    : IRequest<Result<PlanAdminDto>>;

public sealed class CreatePlanCommandHandler
    : IRequestHandler<CreatePlanCommand, Result<PlanAdminDto>>
{
    private readonly IPlanRepository _plans;

    public CreatePlanCommandHandler(IPlanRepository plans) => _plans = plans;

    public async Task<Result<PlanAdminDto>> Handle(
        CreatePlanCommand command, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(command.Code))
        {
            return Error.Validation("Plan code is required.");
        }

        var existing = await _plans.GetByCodeAsync(command.Code, cancellationToken);
        if (existing is not null)
        {
            return Error.Conflict($"A plan with code '{command.Code}' already exists.");
        }

        Plan plan;
        try
        {
            plan = Plan.Create(
                command.Code,
                command.Name,
                command.MonthlyPrice,
                command.Currency,
                command.FeatureKeys,
                command.MaxBranches,
                command.MaxUsers,
                command.MaxProducts,
                command.IsPackage);
        }
        catch (ArgumentException ex)
        {
            return Error.Validation(ex.Message);
        }

        await _plans.AddAsync(plan, cancellationToken);

        return Result.Success(new PlanAdminDto(
            plan.Id,
            plan.Code,
            plan.Name,
            plan.MonthlyPrice,
            plan.Currency,
            plan.FeatureKeys,
            plan.MaxBranches,
            plan.MaxUsers,
            plan.MaxProducts,
            plan.IsPackage,
            plan.IsActive));
    }
}

// ── Update Plan / Package ─────────────────────────────────────────
public sealed record UpdatePlanCommand(
    string Code,
    string Name,
    decimal MonthlyPrice,
    string Currency,
    string[] FeatureKeys,
    int? MaxBranches = null,
    int? MaxUsers = null,
    int? MaxProducts = null,
    bool IsPackage = false,
    bool IsActive = true)
    : IRequest<Result<PlanAdminDto>>;

public sealed class UpdatePlanCommandHandler
    : IRequestHandler<UpdatePlanCommand, Result<PlanAdminDto>>
{
    private readonly IPlanRepository _plans;
    private readonly ICacheService _cache;

    public UpdatePlanCommandHandler(IPlanRepository plans, ICacheService cache)
    {
        _plans = plans;
        _cache = cache;
    }

    public async Task<Result<PlanAdminDto>> Handle(
        UpdatePlanCommand command, CancellationToken cancellationToken)
    {
        var plan = await _plans.GetByCodeAsync(command.Code, cancellationToken);
        if (plan is null)
        {
            return Error.NotFound("Plan not found.");
        }

        try
        {
            plan.Update(
                command.Name,
                command.MonthlyPrice,
                command.Currency,
                command.FeatureKeys,
                command.MaxBranches,
                command.MaxUsers,
                command.MaxProducts,
                command.IsPackage);

            if (command.IsActive && !plan.IsActive)
            {
                plan.Reactivate();
            }
            else if (!command.IsActive && plan.IsActive)
            {
                plan.Deactivate();
            }
        }
        catch (ArgumentException ex)
        {
            return Error.Validation(ex.Message);
        }

        await _plans.UpdateAsync(plan, cancellationToken);

        // Immediate zero-app-update sync: all tenant capabilities derived from this
        // plan reflect new features and price as soon as the 30s cache expires or is refreshed.

        return Result.Success(new PlanAdminDto(
            plan.Id,
            plan.Code,
            plan.Name,
            plan.MonthlyPrice,
            plan.Currency,
            plan.FeatureKeys,
            plan.MaxBranches,
            plan.MaxUsers,
            plan.MaxProducts,
            plan.IsPackage,
            plan.IsActive));
    }
}

// ── Update Dynamic Payment Instructions ───────────────────────────
public sealed record UpdatePaymentInstructionsCommand(
    string MpesaTill,
    string AirtelMoney,
    string BankName,
    string BankAccountNumber,
    string BankAccountName,
    string WhatsAppContact,
    string Notes)
    : IRequest<Result<PaymentInstructionDto>>;

public sealed class UpdatePaymentInstructionsCommandHandler
    : IRequestHandler<UpdatePaymentInstructionsCommand, Result<PaymentInstructionDto>>
{
    private readonly IPaymentInstructionRepository _instructions;

    public UpdatePaymentInstructionsCommandHandler(IPaymentInstructionRepository instructions)
    {
        _instructions = instructions;
    }

    public async Task<Result<PaymentInstructionDto>> Handle(
        UpdatePaymentInstructionsCommand command, CancellationToken cancellationToken)
    {
        var instruction = await _instructions.GetOrCreateAsync(cancellationToken);
        instruction.Update(
            command.MpesaTill,
            command.AirtelMoney,
            command.BankName,
            command.BankAccountNumber,
            command.BankAccountName,
            command.WhatsAppContact,
            command.Notes);

        await _instructions.UpdateAsync(instruction, cancellationToken);

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

// ── Extend Tenant Trial ───────────────────────────────────────────
public sealed record ExtendTenantTrialCommand(Guid TenantId, int Days)
    : IRequest<Result<SubscriptionDto>>;

public sealed class ExtendTenantTrialCommandHandler
    : IRequestHandler<ExtendTenantTrialCommand, Result<SubscriptionDto>>
{
    private readonly ISubscriptionRepository _subscriptions;
    private readonly ICacheService _cache;

    public ExtendTenantTrialCommandHandler(
        ISubscriptionRepository subscriptions, ICacheService cache)
    {
        _subscriptions = subscriptions;
        _cache = cache;
    }

    public async Task<Result<SubscriptionDto>> Handle(
        ExtendTenantTrialCommand command, CancellationToken cancellationToken)
    {
        if (command.Days <= 0 || command.Days > 365)
        {
            return Error.Validation("Days must be between 1 and 365.");
        }

        var subscription = await _subscriptions.GetForTenantAsync(command.TenantId, cancellationToken);
        if (subscription is null)
        {
            subscription = Subscription.StartTrial(command.TenantId, trialLength: TimeSpan.FromDays(command.Days));
            await _subscriptions.AddAsync(subscription, cancellationToken);
        }
        else
        {
            subscription.ExtendTrial(TimeSpan.FromDays(command.Days));
            await _subscriptions.UpdateAsync(subscription, cancellationToken);
        }

        await _cache.RemoveAsync(SubscriptionEntitlementCache.Key(command.TenantId), cancellationToken);

        return Result.Success(SubscriptionMappers.ToDto(subscription));
    }
}

// ── Direct 1-Click Manual Activation (Owner Desk) ────────────────
public sealed record DirectActivateTenantCommand(
    Guid TenantId,
    int Months,
    string? PlanCode,
    string? Reference)
    : IRequest<Result<SubscriptionDto>>;

public sealed class DirectActivateTenantCommandHandler
    : IRequestHandler<DirectActivateTenantCommand, Result<SubscriptionDto>>
{
    private readonly ISubscriptionRepository _subscriptions;
    private readonly IPlanRepository _plans;
    private readonly ICacheService _cache;

    public DirectActivateTenantCommandHandler(
        ISubscriptionRepository subscriptions,
        IPlanRepository plans,
        ICacheService cache)
    {
        _subscriptions = subscriptions;
        _plans = plans;
        _cache = cache;
    }

    public async Task<Result<SubscriptionDto>> Handle(
        DirectActivateTenantCommand command, CancellationToken cancellationToken)
    {
        if (command.Months <= 0 || command.Months > 36)
        {
            return Error.Validation("Months must be between 1 and 36.");
        }

        var now = DateTime.UtcNow;
        var subscription = await _subscriptions.GetForTenantAsync(command.TenantId, cancellationToken);
        if (subscription is null)
        {
            subscription = Subscription.StartTrial(command.TenantId, nowUtc: now);
            await _subscriptions.AddAsync(subscription, cancellationToken);
        }

        if (!string.IsNullOrWhiteSpace(command.PlanCode))
        {
            var plan = await _plans.GetByCodeAsync(command.PlanCode, cancellationToken);
            if (plan is not null && !plan.IsPackage)
            {
                subscription.ChangePlan(plan.Code);
            }
        }

        var effectiveStart = SubscriptionAccessEvaluator.EffectivePeriodStart(
            subscription.PaidUntilUtc, now);
        subscription.Paid(effectiveStart, TimeSpan.FromDays(command.Months * 30), now);
        await _subscriptions.UpdateAsync(subscription, cancellationToken);

        await _cache.RemoveAsync(SubscriptionEntitlementCache.Key(command.TenantId), cancellationToken);

        return Result.Success(SubscriptionMappers.ToDto(subscription));
    }
}
