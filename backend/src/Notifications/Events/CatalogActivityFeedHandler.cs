using BusinessOS.Application.Ports;
using BusinessOS.Domain.Events;
using Microsoft.Extensions.Logging;

namespace BusinessOS.Notifications.Events;

/// <summary>
/// Fans product catalog domain events out to the activity feed.
/// </summary>
public sealed class CatalogActivityFeedHandler
    : IDomainEventHandler<ProductCreatedEvent>,
      IDomainEventHandler<ProductUpdatedEvent>,
      IDomainEventHandler<ProductStatusChangedEvent>,
      IDomainEventHandler<ProductVariantsChangedEvent>
{
    private readonly ILogger<CatalogActivityFeedHandler> _logger;

    public CatalogActivityFeedHandler(ILogger<CatalogActivityFeedHandler> logger) => _logger = logger;

    public Task HandleAsync(ProductCreatedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Activity feed: Product {Name} ({Sku}) created for tenant {TenantId}",
            domainEvent.Name, domainEvent.Sku, domainEvent.TenantId);
        return Task.CompletedTask;
    }

    public Task HandleAsync(ProductUpdatedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Activity feed: Product {Name} updated for tenant {TenantId}",
            domainEvent.Name, domainEvent.TenantId);
        return Task.CompletedTask;
    }

    public Task HandleAsync(ProductStatusChangedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Activity feed: Product {ProductId} status {Status} for tenant {TenantId}",
            domainEvent.ProductId, domainEvent.Status, domainEvent.TenantId);
        return Task.CompletedTask;
    }

    public Task HandleAsync(ProductVariantsChangedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Activity feed: Product {ProductId} variants {VariantIds} ({Count}) for tenant {TenantId}",
            domainEvent.ProductId, string.Join(",", domainEvent.VariantIds), domainEvent.VariantIds.Length, domainEvent.TenantId);
        return Task.CompletedTask;
    }
}
