using BusinessOS.Application.Ports;
using BusinessOS.Domain.Events;
using Microsoft.Extensions.Logging;

namespace BusinessOS.Notifications.Events;

/// <summary>
/// Fans warehouse and stock ledger domain events out to the activity feed.
/// </summary>
public sealed class InventoryActivityFeedHandler
    : IDomainEventHandler<WarehouseCreatedEvent>,
      IDomainEventHandler<WarehouseUpdatedEvent>,
      IDomainEventHandler<WarehouseStatusChangedEvent>,
      IDomainEventHandler<OpeningStockRecordedEvent>,
      IDomainEventHandler<StockMovementRecordedEvent>
{
    private readonly ILogger<InventoryActivityFeedHandler> _logger;

    public InventoryActivityFeedHandler(ILogger<InventoryActivityFeedHandler> logger) => _logger = logger;

    public Task HandleAsync(WarehouseCreatedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Activity feed: Warehouse {Name} ({Code}) created for tenant {TenantId}",
            domainEvent.Name, domainEvent.Code, domainEvent.TenantId);
        return Task.CompletedTask;
    }

    public Task HandleAsync(WarehouseUpdatedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Activity feed: Warehouse {Name} ({Code}) updated for tenant {TenantId}",
            domainEvent.Name, domainEvent.Code, domainEvent.TenantId);
        return Task.CompletedTask;
    }

    public Task HandleAsync(WarehouseStatusChangedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Activity feed: Warehouse {Name} ({Code}) status {Status} for tenant {TenantId}",
            domainEvent.Name, domainEvent.Code, domainEvent.IsActive, domainEvent.TenantId);
        return Task.CompletedTask;
    }

    public Task HandleAsync(OpeningStockRecordedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Activity feed: Opening stock {Quantity} for product {ProductId} at location {StockLocationId} " +
            "for tenant {TenantId}",
            domainEvent.Quantity, domainEvent.ProductId, domainEvent.StockLocationId, domainEvent.TenantId);
        return Task.CompletedTask;
    }

    public Task HandleAsync(StockMovementRecordedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Activity feed: Stock movement {MovementType} {Quantity} for product {ProductId} " +
            "at location {StockLocationId} for tenant {TenantId}",
            domainEvent.MovementType, domainEvent.Quantity, domainEvent.ProductId,
            domainEvent.StockLocationId, domainEvent.TenantId);
        return Task.CompletedTask;
    }
}
