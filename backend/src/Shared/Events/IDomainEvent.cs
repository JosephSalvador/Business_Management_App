namespace BusinessOS.Shared.Events;

public interface IDomainEvent
{
    Guid EventId { get; }
    DateTime OccurredAt { get; }
}

/// <summary>
/// Marker for events and jobs that carry the tenant they belong to. Queued jobs
/// use it to stamp the outbox row so tenant-scoped processing stays possible
/// even when enqueueing happens outside an authenticated request.
/// </summary>
public interface ITenantScopedEvent
{
    Guid TenantId { get; }
}
