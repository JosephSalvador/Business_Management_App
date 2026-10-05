using BusinessOS.Application.Ports;
using BusinessOS.Domain.Billing;
using BusinessOS.Domain.Features;
using BusinessOS.Domain.Tenants;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Tenants.Commands;

public static class TenantProvisioningMappers
{
    public static TenantDto ToDto(Tenant t) => new(
        t.Id, t.Name, t.Currency, t.CountryCode, t.ContactEmail,
        t.ContactPhone, t.TaxId, t.BusinessType, t.IsActive, t.CreatedAt);
}

public sealed record TenantDto(
    Guid Id, string Name, string Currency, string CountryCode,
    string? ContactEmail, string? ContactPhone, string? TaxId,
    string? BusinessType, bool IsActive, DateTime CreatedAt);

// ── Provision Tenant ────────────────────────────────────────────
public sealed record ProvisionTenantCommand(
    string Name, string? Currency, string? CountryCode, string? BusinessType,
    string? ContactEmail, string? ContactPhone)
    : IRequest<Result<TenantDto>>;

public sealed class ProvisionTenantCommandHandler
    : IRequestHandler<ProvisionTenantCommand, Result<TenantDto>>
{
    private readonly ITenantRepository _tenants;
    private readonly IFeatureFlagRepository _flags;
    private readonly ISubscriptionRepository _subscriptions;

    public ProvisionTenantCommandHandler(
        ITenantRepository tenants,
        IFeatureFlagRepository flags,
        ISubscriptionRepository subscriptions)
    {
        _tenants = tenants;
        _flags = flags;
        _subscriptions = subscriptions;
    }

    public async Task<Result<TenantDto>> Handle(
        ProvisionTenantCommand command, CancellationToken cancellationToken)
    {
        var existing = await _tenants.GetByNameAsync(command.Name, cancellationToken);
        if (existing is not null)
            return Error.Conflict("Tenant with this name already exists.");

        var tenant = Tenant.Create(
            Guid.NewGuid(),
            command.Name,
            command.Currency,
            null,
            command.CountryCode);

        if (command.BusinessType is not null || command.ContactEmail is not null || command.ContactPhone is not null)
        {
            tenant.CompleteOnboarding(
                command.Name,
                command.BusinessType,
                command.CountryCode ?? Tenant.DefaultCountryCode,
                command.Currency ?? Tenant.DefaultCurrency,
                command.ContactPhone,
                null);
        }

        await _tenants.AddAsync(tenant, cancellationToken);

        foreach (var key in FeatureKeys.All)
        {
            var flag = FeatureFlag.Create(tenant.Id, key, true);
            await _flags.AddAsync(flag, cancellationToken);
        }

        // Every provisioned workspace starts on the free 14-day Pro trial.
        await _subscriptions.AddAsync(
            Subscription.StartTrial(tenant.Id), cancellationToken);

        return Result.Success(TenantProvisioningMappers.ToDto(tenant));
    }
}

// ── Activate / Deactivate Tenant ────────────────────────────────
public sealed record ToggleTenantCommand(Guid TenantId, bool IsActive)
    : IRequest<Result<TenantDto>>;

public sealed class ToggleTenantCommandHandler
    : IRequestHandler<ToggleTenantCommand, Result<TenantDto>>
{
    private readonly ITenantRepository _tenants;

    public ToggleTenantCommandHandler(ITenantRepository tenants) => _tenants = tenants;

    public async Task<Result<TenantDto>> Handle(
        ToggleTenantCommand command, CancellationToken cancellationToken)
    {
        var tenant = await _tenants.GetByIdAsync(command.TenantId, cancellationToken);
        if (tenant is null) return Error.NotFound("Tenant not found.");

        if (command.IsActive) tenant.Activate(); else tenant.Deactivate();
        await _tenants.UpdateAsync(tenant, cancellationToken);

        return Result.Success(TenantProvisioningMappers.ToDto(tenant));
    }
}
