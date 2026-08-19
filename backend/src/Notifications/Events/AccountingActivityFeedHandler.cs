using BusinessOS.Application.Ports;
using BusinessOS.Domain.Events;
using Microsoft.Extensions.Logging;

namespace BusinessOS.Notifications.Events;

public sealed class AccountingActivityFeedHandler
    : IDomainEventHandler<JournalEntryPostedEvent>,
      IDomainEventHandler<JournalEntryVoidedEvent>
{
    private readonly ILogger<AccountingActivityFeedHandler> _logger;

    public AccountingActivityFeedHandler(ILogger<AccountingActivityFeedHandler> logger) => _logger = logger;

    public Task HandleAsync(JournalEntryPostedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Activity feed: Journal entry {JournalEntryId} posted for tenant {TenantId}: {Description} ({TotalDebit:N2}/{TotalCredit:N2})",
            domainEvent.JournalEntryId, domainEvent.TenantId, domainEvent.Description,
            domainEvent.TotalDebit, domainEvent.TotalCredit);
        return Task.CompletedTask;
    }

    public Task HandleAsync(JournalEntryVoidedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Activity feed: Journal entry {JournalEntryId} voided for tenant {TenantId}: {Description} ({TotalDebit:N2}/{TotalCredit:N2})",
            domainEvent.JournalEntryId, domainEvent.TenantId, domainEvent.Description,
            domainEvent.TotalDebit, domainEvent.TotalCredit);
        return Task.CompletedTask;
    }
}
