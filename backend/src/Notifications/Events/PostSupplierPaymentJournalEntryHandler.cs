using BusinessOS.Application.Accounting;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Accounting;
using BusinessOS.Domain.Events;
using Microsoft.Extensions.Logging;

namespace BusinessOS.Notifications.Events;

public sealed class PostSupplierPaymentJournalEntryHandler
    : IDomainEventHandler<SupplierBillPaidEvent>
{
    private readonly IAccountMappingService _accountMappings;
    private readonly IJournalEntryRepository _journalEntries;
    private readonly ILogger<PostSupplierPaymentJournalEntryHandler> _logger;

    public PostSupplierPaymentJournalEntryHandler(
        IAccountMappingService accountMappings,
        IJournalEntryRepository journalEntries,
        ILogger<PostSupplierPaymentJournalEntryHandler> logger)
    {
        _accountMappings = accountMappings;
        _journalEntries = journalEntries;
        _logger = logger;
    }

    public async Task HandleAsync(SupplierBillPaidEvent domainEvent, CancellationToken cancellationToken = default)
    {
        var apAccountId = await _accountMappings.GetAccountIdAsync(
            domainEvent.TenantId, AccountMappingKeys.AccountsPayable, cancellationToken);
        var cashAccountId = await _accountMappings.GetAccountIdAsync(
            domainEvent.TenantId, AccountMappingKeys.CashOnHand, cancellationToken);

        if (apAccountId is null || cashAccountId is null)
        {
            _logger.LogWarning(
                "Account mappings not configured for tenant {TenantId}. Skipping journal entry for supplier payment on bill {BillId}.",
                domainEvent.TenantId, domainEvent.SupplierBillId);
            return;
        }

        var lines = new List<JournalEntryLine>
        {
            JournalEntryLine.Create(apAccountId.Value, domainEvent.AmountPaid, 0, $"AP Payment - Bill {domainEvent.SupplierBillId}"),
            JournalEntryLine.Create(cashAccountId.Value, 0, domainEvent.AmountPaid, $"Cash Payment - Bill {domainEvent.SupplierBillId}")
        };

        var entry = JournalEntry.Create(
            domainEvent.TenantId,
            $"Supplier payment for bill {domainEvent.SupplierBillId}",
            domainEvent.OccurredAt,
            "SupplierPayment",
            domainEvent.SupplierBillId,
            lines);

        entry.Post(domainEvent.OccurredAt);
        await _journalEntries.AddAsync(entry, cancellationToken);

        _logger.LogInformation(
            "Posted journal entry for supplier payment on bill {BillId}: {AmountPaid:N2}",
            domainEvent.SupplierBillId, domainEvent.AmountPaid);
    }
}
