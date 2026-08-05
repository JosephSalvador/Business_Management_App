namespace BusinessOS.Shared.Audit;

public sealed record AuditContext(
    Guid? UserId,
    Guid? TenantId,
    string? IpAddress,
    string CorrelationId,
    string? Device);
