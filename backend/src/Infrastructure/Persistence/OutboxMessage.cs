namespace BusinessOS.Infrastructure.Persistence;

/// <summary>
/// Reliable-delivery queue for domain events. Written in the same transaction as the
/// state change; dispatched in-process and/or by the outbox worker; idempotent consumers.
/// </summary>
public sealed class OutboxMessage
{
    public Guid Id { get; set; }
    public string Type { get; set; } = string.Empty;
    public string Payload { get; set; } = string.Empty;
    public DateTime OccurredAt { get; set; }
    public Guid? TenantId { get; set; }
    public DateTime? ProcessedAt { get; set; }
    public string? Error { get; set; }
}
