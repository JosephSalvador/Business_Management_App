using BusinessOS.Application.Ports;
using BusinessOS.Domain.Events;
using Microsoft.Extensions.Logging;

namespace BusinessOS.Notifications.Events;

/// <summary>
/// Fans pricing domain events out to the activity feed.
/// </summary>
public sealed class PricingActivityFeedHandler
    : IDomainEventHandler<PriceListCreatedEvent>,
      IDomainEventHandler<PriceListUpdatedEvent>,
      IDomainEventHandler<ProductPricesChangedEvent>
{
    private readonly ILogger<PricingActivityFeedHandler> _logger;

    public PricingActivityFeedHandler(ILogger<PricingActivityFeedHandler> logger) => _logger = logger;

    public Task HandleAsync(PriceListCreatedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Activity feed: Price list {Name} ({Currency}) created for tenant {TenantId}",
            domainEvent.Name, domainEvent.Currency, domainEvent.TenantId);
        return Task.CompletedTask;
    }

    public Task HandleAsync(PriceListUpdatedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Activity feed: Price list {Name} updated (active: {IsActive}) for tenant {TenantId}",
            domainEvent.Name, domainEvent.IsActive, domainEvent.TenantId);
        return Task.CompletedTask;
    }

    public Task HandleAsync(ProductPricesChangedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Activity feed: Price list {PriceListId} now carries {PriceCount} prices for tenant {TenantId}",
            domainEvent.PriceListId, domainEvent.PriceCount, domainEvent.TenantId);
        return Task.CompletedTask;
    }
}
