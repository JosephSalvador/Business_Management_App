using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Audit;

public sealed class AuditLog : Entity
{
    private AuditLog(
        Guid id,
        Guid tenantId,
        Guid? userId,
        string action,
        string entityType,
        string? entityId,
        string? changes,
        string? ipAddress)
        : base(id)
    {
        TenantId = tenantId;
        UserId = userId;
        Action = action;
        EntityType = entityType;
        EntityId = entityId;
        Changes = changes;
        IpAddress = ipAddress;
    }

    public Guid TenantId { get; private set; }
    public Guid? UserId { get; private set; }
    public string Action { get; private set; }
    public string EntityType { get; private set; }
    public string? EntityId { get; private set; }
    public string? Changes { get; private set; }
    public string? IpAddress { get; private set; }

    public static AuditLog Create(
        Guid tenantId,
        Guid? userId,
        string action,
        string entityType,
        string? entityId = null,
        string? changes = null,
        string? ipAddress = null)
        => new(Guid.NewGuid(), tenantId, userId, action, entityType, entityId, changes, ipAddress);
}
