using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record CashSessionClosedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid SessionId,
    Guid TenantId,
    Guid AccountId,
    decimal OpeningCash,
    decimal ClosingCash,
    decimal ExpectedCash,
    decimal Variance,
    string? Notes) : IDomainEvent;
