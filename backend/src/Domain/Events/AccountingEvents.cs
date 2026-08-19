using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record JournalEntryPostedEvent(
    Guid EventId, DateTime OccurredAt,
    Guid JournalEntryId, Guid TenantId,
    string Description, decimal TotalDebit, decimal TotalCredit) : IDomainEvent;

public sealed record JournalEntryVoidedEvent(
    Guid EventId, DateTime OccurredAt,
    Guid JournalEntryId, Guid TenantId,
    string Description, decimal TotalDebit, decimal TotalCredit) : IDomainEvent;
