using BusinessOS.Application.Accounting;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Accounting;
using BusinessOS.Domain.Events;
using Microsoft.Extensions.Logging;

namespace BusinessOS.Notifications.Events;

public sealed class PostSupplierBillJournalEntryHandler
    : IDomainEventHandler<SupplierBillCreatedEvent>
{
    private readonly IAccountMappingService _accountMappings;
    private readonly IJournalEntryRepository _journalEntries;
    private readonly ILogger<PostSupplierBillJournalEntryHandler> _logger;

    public PostSupplierBillJournalEntryHandler(
        IAccountMappingService accountMappings,
        IJournalEntryRepository journalEntries,
        ILogger<PostSupplierBillJournalEntryHandler> logger)
    {
        _accountMappings = accountMappings;
        _journalEntries = journalEntries;
        _logger = logger;
    }

    public async Task HandleAsync(SupplierBillCreatedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        var existing = await _journalEntries.GetBySourceAsync(
            domainEvent.TenantId, "SupplierBill", domainEvent.SupplierBillId, cancellationToken);
        if (existing is not null)
        {
            _logger.LogDebug("Journal entry already exists for supplier bill {BillId}, skipping.", domainEvent.SupplierBillId);
            return;
        }

        var apAccountId = await _accountMappings.GetAccountIdAsync(
            domainEvent.TenantId, AccountMappingKeys.AccountsPayable, cancellationToken);
        var purchasesAccountId = await _accountMappings.GetAccountIdAsync(
            domainEvent.TenantId, AccountMappingKeys.PurchasesExpense, cancellationToken);

        if (apAccountId is null || purchasesAccountId is null)
        {
            _logger.LogWarning(
                "Account mappings not configured for tenant {TenantId}. Skipping journal entry for supplier bill {BillId}.",
                domainEvent.TenantId, domainEvent.SupplierBillId);
            return;
        }

        var lines = new List<JournalEntryLine>
        {
            JournalEntryLine.Create(purchasesAccountId.Value, domainEvent.TotalAmount, 0, $"Purchases - Bill {domainEvent.SupplierBillId}"),
            JournalEntryLine.Create(apAccountId.Value, 0, domainEvent.TotalAmount, $"AP - Bill {domainEvent.SupplierBillId}")
        };

        var entry = JournalEntry.Create(
            domainEvent.TenantId,
            $"Supplier bill {domainEvent.SupplierBillId}",
            domainEvent.OccurredAt,
            "SupplierBill",
            domainEvent.SupplierBillId,
            lines);

        entry.Post(domainEvent.OccurredAt);
        await _journalEntries.AddAsync(entry, cancellationToken);

        _logger.LogInformation(
            "Posted journal entry for supplier bill {BillId}: {TotalAmount:N2}",
            domainEvent.SupplierBillId, domainEvent.TotalAmount);
    }
}
