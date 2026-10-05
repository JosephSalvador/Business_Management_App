using BusinessOS.Shared.Events;

namespace BusinessOS.Domain.Events;

public sealed record UserTwoFactorEnabledEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid UserId,
    Guid TenantId,
    DateTime EnabledAt) : IDomainEvent;

public sealed record UserTwoFactorDisabledEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid UserId,
    Guid TenantId) : IDomainEvent;

public sealed record UserRecoveryCodesRegeneratedEvent(
    Guid EventId,
    DateTime OccurredAt,
    Guid UserId,
    Guid TenantId,
    int CodeCount) : IDomainEvent;
