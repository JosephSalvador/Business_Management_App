using BusinessOS.Application.Accounting;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Accounting;
using BusinessOS.Domain.Events;
using Microsoft.Extensions.Logging;

namespace BusinessOS.Notifications.Events;

public sealed class PostSaleJournalEntryHandler
    : IDomainEventHandler<SaleCompletedEvent>
{
    private readonly IAccountMappingService _accountMappings;
    private readonly IJournalEntryRepository _journalEntries;
    private readonly ILogger<PostSaleJournalEntryHandler> _logger;

    public PostSaleJournalEntryHandler(
        IAccountMappingService accountMappings,
        IJournalEntryRepository journalEntries,
        ILogger<PostSaleJournalEntryHandler> logger)
    {
        _accountMappings = accountMappings;
        _journalEntries = journalEntries;
        _logger = logger;
    }

    public async Task HandleAsync(SaleCompletedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        var existing = await _journalEntries.GetBySourceAsync(
            domainEvent.TenantId, "Sale", domainEvent.SaleId, cancellationToken);
        if (existing is not null)
        {
            _logger.LogDebug("Journal entry already exists for sale {SaleId}, skipping.", domainEvent.SaleId);
            return;
        }

        var arAccountId = await _accountMappings.GetAccountIdAsync(
            domainEvent.TenantId, AccountMappingKeys.AccountsReceivable, cancellationToken);
        var revenueAccountId = await _accountMappings.GetAccountIdAsync(
            domainEvent.TenantId, AccountMappingKeys.SalesRevenue, cancellationToken);

        if (arAccountId is null || revenueAccountId is null)
        {
            _logger.LogWarning(
                "Account mappings not configured for tenant {TenantId}. Skipping journal entry for sale {SaleId}.",
                domainEvent.TenantId, domainEvent.SaleId);
            return;
        }

        var lines = new List<JournalEntryLine>
        {
            JournalEntryLine.Create(arAccountId.Value, domainEvent.TotalAmount, 0, $"AR - Sale {domainEvent.SaleId}"),
            JournalEntryLine.Create(revenueAccountId.Value, 0, domainEvent.TotalAmount, $"Revenue - Sale {domainEvent.SaleId}")
        };

        var entry = JournalEntry.Create(
            domainEvent.TenantId,
            $"Sale {domainEvent.SaleId}",
            domainEvent.OccurredAt,
            "Sale",
            domainEvent.SaleId,
            lines);

        entry.Post(domainEvent.OccurredAt);
        await _journalEntries.AddAsync(entry, cancellationToken);

        _logger.LogInformation(
            "Posted journal entry for sale {SaleId}: {TotalAmount:N2}",
            domainEvent.SaleId, domainEvent.TotalAmount);
    }
}
