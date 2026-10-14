using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Notifications;

public sealed class AppNotification : Entity
{
    private AppNotification(
        Guid id,
        Guid tenantId,
        Guid? userId,
        string? targetRole,
        Guid? branchId,
        string category,
        string type,
        string titleSw,
        string titleEn,
        string bodySw,
        string bodyEn,
        string? dataJson)
        : base(id)
    {
        TenantId = tenantId;
        UserId = userId;
        TargetRole = targetRole;
        BranchId = branchId;
        Category = category;
        Type = type;
        TitleSw = titleSw;
        TitleEn = titleEn;
        BodySw = bodySw;
        BodyEn = bodyEn;
        DataJson = dataJson;
        IsRead = false;
        ReadAt = null;
    }

    public Guid TenantId { get; private set; }
    public Guid? UserId { get; private set; }
    public string? TargetRole { get; private set; }
    public Guid? BranchId { get; private set; }
    public string Category { get; private set; }
    public string Type { get; private set; }
    public string TitleSw { get; private set; }
    public string TitleEn { get; private set; }
    public string BodySw { get; private set; }
    public string BodyEn { get; private set; }
    public string? DataJson { get; private set; }
    public bool IsRead { get; private set; }
    public DateTime? ReadAt { get; private set; }

    public static AppNotification Create(
        Guid tenantId,
        Guid? userId,
        string? targetRole,
        Guid? branchId,
        string category,
        string type,
        string titleSw,
        string titleEn,
        string bodySw,
        string bodyEn,
        string? dataJson = null)
        => new(
            Guid.NewGuid(),
            tenantId,
            userId,
            targetRole,
            branchId,
            category,
            type,
            titleSw,
            titleEn,
            bodySw,
            bodyEn,
            dataJson);

    public void MarkAsRead(DateTime readAt)
    {
        if (IsRead)
        {
            return;
        }

        IsRead = true;
        ReadAt = readAt;
    }
}
