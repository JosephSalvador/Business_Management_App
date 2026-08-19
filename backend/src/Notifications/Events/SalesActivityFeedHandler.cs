using BusinessOS.Application.Ports;
using BusinessOS.Domain.Events;
using Microsoft.Extensions.Logging;

namespace BusinessOS.Notifications.Events;

/// <summary>
/// Fans sale domain events out to the activity feed.
/// </summary>
public sealed class SalesActivityFeedHandler
    : IDomainEventHandler<SaleCompletedEvent>,
      IDomainEventHandler<SaleVoidedEvent>
{
    private readonly ILogger<SalesActivityFeedHandler> _logger;

    public SalesActivityFeedHandler(ILogger<SalesActivityFeedHandler> logger) => _logger = logger;

    public Task HandleAsync(SaleCompletedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Activity feed: Sale {Number} ({Currency} {TotalAmount:N2}) completed for tenant {TenantId}",
            domainEvent.Number, domainEvent.Currency, domainEvent.TotalAmount, domainEvent.TenantId);
        return Task.CompletedTask;
    }

    public Task HandleAsync(SaleVoidedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Activity feed: Sale {Number} ({Currency} {TotalAmount:N2}) voided for tenant {TenantId}: {Reason}",
            domainEvent.Number, domainEvent.Currency, domainEvent.TotalAmount, domainEvent.TenantId,
            domainEvent.Reason);
        return Task.CompletedTask;
    }
}
