namespace BusinessOS.Api.Http;

public sealed class RequestContext
{
    public string CorrelationId { get; set; } = string.Empty;
    public Guid? UserId { get; set; }
    public Guid? TenantId { get; set; }
    public string? IpAddress { get; set; }
    public string? TlsFingerprint { get; set; }
    public int? BotScore { get; set; }
    public DateTime StartedAtUtc { get; } = DateTime.UtcNow;
}
