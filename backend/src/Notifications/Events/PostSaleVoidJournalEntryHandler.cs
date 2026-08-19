using BusinessOS.Application.Accounting;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Accounting;
using BusinessOS.Domain.Events;
using Microsoft.Extensions.Logging;

namespace BusinessOS.Notifications.Events;

public sealed class PostSaleVoidJournalEntryHandler
    : IDomainEventHandler<SaleVoidedEvent>
{
    private readonly IAccountMappingService _accountMappings;
    private readonly IJournalEntryRepository _journalEntries;
    private readonly ILogger<PostSaleVoidJournalEntryHandler> _logger;

    public PostSaleVoidJournalEntryHandler(
        IAccountMappingService accountMappings,
        IJournalEntryRepository journalEntries,
        ILogger<PostSaleVoidJournalEntryHandler> logger)
    {
        _accountMappings = accountMappings;
        _journalEntries = journalEntries;
        _logger = logger;
    }

    public async Task HandleAsync(SaleVoidedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        var existing = await _journalEntries.GetBySourceAsync(
            domainEvent.TenantId, "SaleVoid", domainEvent.SaleId, cancellationToken);
        if (existing is not null)
        {
            _logger.LogDebug("Reversing journal entry already exists for voided sale {SaleId}, skipping.", domainEvent.SaleId);
            return;
        }

        var arAccountId = await _accountMappings.GetAccountIdAsync(
            domainEvent.TenantId, AccountMappingKeys.AccountsReceivable, cancellationToken);
        var revenueAccountId = await _accountMappings.GetAccountIdAsync(
            domainEvent.TenantId, AccountMappingKeys.SalesRevenue, cancellationToken);

        if (arAccountId is null || revenueAccountId is null)
        {
            _logger.LogWarning(
                "Account mappings not configured for tenant {TenantId}. Skipping reversing entry for voided sale {SaleId}.",
                domainEvent.TenantId, domainEvent.SaleId);
            return;
        }

        var lines = new List<JournalEntryLine>
        {
            JournalEntryLine.Create(revenueAccountId.Value, domainEvent.TotalAmount, 0, $"Revenue reversal - Voided sale {domainEvent.SaleId}"),
            JournalEntryLine.Create(arAccountId.Value, 0, domainEvent.TotalAmount, $"AR reversal - Voided sale {domainEvent.SaleId}")
        };

        var entry = JournalEntry.Create(
            domainEvent.TenantId,
            $"Reversal for voided sale {domainEvent.SaleId}",
            domainEvent.OccurredAt,
            "SaleVoid",
            domainEvent.SaleId,
            lines);

        entry.Post(domainEvent.OccurredAt);
        await _journalEntries.AddAsync(entry, cancellationToken);

        _logger.LogInformation(
            "Posted reversing journal entry for voided sale {SaleId}: {TotalAmount:N2}",
            domainEvent.SaleId, domainEvent.TotalAmount);
    }
}
