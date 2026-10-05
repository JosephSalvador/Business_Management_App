using System.Reflection;
using BusinessOS.Application.Behaviors;
using BusinessOS.Application.Features.Billing;
using BusinessOS.Application.Ports;
using BusinessOS.Application.Tax;
using BusinessOS.Domain.Events;
using FluentValidation;
using Microsoft.Extensions.DependencyInjection;

namespace BusinessOS.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddMediatR(cfg =>
        {
            cfg.RegisterServicesFromAssembly(Assembly.GetExecutingAssembly());
            cfg.AddOpenBehavior(typeof(ValidationBehavior<,>));
            cfg.AddOpenBehavior(typeof(TransactionBehavior<,>));
            cfg.AddOpenBehavior(typeof(AuditBehavior<,>));
        });

        services.AddValidatorsFromAssembly(Assembly.GetExecutingAssembly());
        services.AddScoped<ITaxEngine, TaxService>();
        services.AddScoped<Features.Auth.Services.EmailVerificationService>();
        services.AddScoped<Features.Auth.Services.PasswordResetService>();
        services.AddScoped<Features.Auth.Services.TwoFactorChallengeService>();
        services.AddScoped<Features.Auth.Services.AuthSessionIssuer>();
        services.AddScoped<ISubscriptionEntitlementService, SubscriptionEntitlementService>();
        services.AddScoped<SubscriptionEntitlementGuard>();
        services.AddScoped<SubscriptionEntitlementCacheInvalidationHandler>();
        services.AddScoped<IDomainEventHandler<SubscriptionTrialStartedEvent>>(
            sp => sp.GetRequiredService<SubscriptionEntitlementCacheInvalidationHandler>());
        services.AddScoped<IDomainEventHandler<SubscriptionActivatedEvent>>(
            sp => sp.GetRequiredService<SubscriptionEntitlementCacheInvalidationHandler>());
        services.AddScoped<IDomainEventHandler<SubscriptionDebtTransitionEvent>>(
            sp => sp.GetRequiredService<SubscriptionEntitlementCacheInvalidationHandler>());
        services.AddScoped<IDomainEventHandler<VoucherRedeemedEvent>>(
            sp => sp.GetRequiredService<SubscriptionEntitlementCacheInvalidationHandler>());
        services.AddScoped<IDomainEventHandler<InvoicePaidEvent>>(
            sp => sp.GetRequiredService<SubscriptionEntitlementCacheInvalidationHandler>());
        services.AddScoped<IDomainEventHandler<SubscriptionPackageActivatedEvent>>(
            sp => sp.GetRequiredService<SubscriptionEntitlementCacheInvalidationHandler>());
        services.AddScoped<IDomainEventHandler<SubscriptionPackageRemovedEvent>>(
            sp => sp.GetRequiredService<SubscriptionEntitlementCacheInvalidationHandler>());
        services.AddScoped<IDomainEventHandler<FeatureFlagChangedEvent>>(
            sp => sp.GetRequiredService<SubscriptionEntitlementCacheInvalidationHandler>());

        return services;
    }
}
