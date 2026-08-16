using BusinessOS.Application.Ports;
using BusinessOS.Domain.Events;
using BusinessOS.Notifications.Channels;
using BusinessOS.Notifications.Events;
using Microsoft.Extensions.DependencyInjection;
using INotificationService = BusinessOS.Application.Ports.INotificationService;

namespace BusinessOS.Notifications;

public static class NotificationEngineExtensions
{
    public static IServiceCollection AddNotificationEngine(this IServiceCollection services)
    {
        services.AddOptions();

        services.AddScoped<EmailChannel>();
        services.AddScoped<LoggingSmsChannel>();
        services.AddScoped<LoggingPushChannel>();
        services.AddScoped<LoggingWhatsAppChannel>();
        services.AddScoped<INotificationService, NotificationService>();
        services.AddScoped<IDomainEventHandler<UserRegisteredEvent>, UserRegisteredNotificationHandler>();
        services.AddScoped<IDomainEventHandler<UserRegisteredEvent>, UserRegisteredAnalyticsHandler>();
        services.AddScoped<IDomainEventHandler<UserRegisteredEvent>, UserRegisteredActivityFeedHandler>();
        services.AddScoped<IDomainEventHandler<BranchCreatedEvent>, BranchActivityFeedHandler>();
        services.AddScoped<IDomainEventHandler<BranchUpdatedEvent>, BranchActivityFeedHandler>();
        services.AddScoped<IDomainEventHandler<BranchStatusChangedEvent>, BranchActivityFeedHandler>();
        services.AddScoped<IDomainEventHandler<UserCreatedEvent>, IdentityActivityFeedHandler>();
        services.AddScoped<IDomainEventHandler<UserProfileUpdatedEvent>, IdentityActivityFeedHandler>();
        services.AddScoped<IDomainEventHandler<UserRolesChangedEvent>, IdentityActivityFeedHandler>();
        services.AddScoped<IDomainEventHandler<UserStatusChangedEvent>, IdentityActivityFeedHandler>();
        services.AddScoped<IDomainEventHandler<UserBranchesChangedEvent>, IdentityActivityFeedHandler>();
        services.AddScoped<IDomainEventHandler<RoleCreatedEvent>, IdentityActivityFeedHandler>();
        services.AddScoped<IDomainEventHandler<RoleUpdatedEvent>, IdentityActivityFeedHandler>();
        services.AddScoped<IDomainEventHandler<RolePermissionsChangedEvent>, IdentityActivityFeedHandler>();
        services.AddScoped<IDomainEventHandler<RoleDeletedEvent>, IdentityActivityFeedHandler>();
        services.AddScoped<IDomainEventHandler<ProductCreatedEvent>, CatalogActivityFeedHandler>();
        services.AddScoped<IDomainEventHandler<ProductUpdatedEvent>, CatalogActivityFeedHandler>();
        services.AddScoped<IDomainEventHandler<ProductStatusChangedEvent>, CatalogActivityFeedHandler>();
        services.AddScoped<IDomainEventHandler<ProductVariantsChangedEvent>, CatalogActivityFeedHandler>();
        services.AddScoped<IDomainEventHandler<WarehouseCreatedEvent>, InventoryActivityFeedHandler>();
        services.AddScoped<IDomainEventHandler<WarehouseUpdatedEvent>, InventoryActivityFeedHandler>();
        services.AddScoped<IDomainEventHandler<WarehouseStatusChangedEvent>, InventoryActivityFeedHandler>();
        services.AddScoped<IDomainEventHandler<OpeningStockRecordedEvent>, InventoryActivityFeedHandler>();
        services.AddScoped<IDomainEventHandler<StockMovementRecordedEvent>, InventoryActivityFeedHandler>();
        services.AddScoped<IDomainEventHandler<PriceListCreatedEvent>, PricingActivityFeedHandler>();
        services.AddScoped<IDomainEventHandler<PriceListUpdatedEvent>, PricingActivityFeedHandler>();
        services.AddScoped<IDomainEventHandler<ProductPricesChangedEvent>, PricingActivityFeedHandler>();
        services.AddScoped<IDomainEventHandler<SaleCompletedEvent>, SalesActivityFeedHandler>();

        return services;
    }
}
