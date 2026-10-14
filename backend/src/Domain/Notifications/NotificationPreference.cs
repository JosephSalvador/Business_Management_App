using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Notifications;

public sealed class NotificationPreference : Entity
{
    private NotificationPreference(
        Guid id,
        Guid tenantId,
        Guid? userId,
        bool notifyCashShortage,
        bool notifySaleVoided,
        bool notifyLowStock,
        decimal highSaleThreshold,
        bool pushEnabled)
        : base(id)
    {
        TenantId = tenantId;
        UserId = userId;
        NotifyCashShortage = notifyCashShortage;
        NotifySaleVoided = notifySaleVoided;
        NotifyLowStock = notifyLowStock;
        HighSaleThreshold = highSaleThreshold;
        PushEnabled = pushEnabled;
    }

    public Guid TenantId { get; private set; }
    public Guid? UserId { get; private set; }
    public bool NotifyCashShortage { get; private set; }
    public bool NotifySaleVoided { get; private set; }
    public bool NotifyLowStock { get; private set; }
    public decimal HighSaleThreshold { get; private set; }
    public bool PushEnabled { get; private set; }

    public static NotificationPreference CreateDefault(Guid tenantId, Guid? userId = null)
        => new(
            Guid.NewGuid(),
            tenantId,
            userId,
            notifyCashShortage: true,
            notifySaleVoided: true,
            notifyLowStock: true,
            highSaleThreshold: 500000m,
            pushEnabled: true);

    public void Update(
        bool notifyCashShortage,
        bool notifySaleVoided,
        bool notifyLowStock,
        decimal highSaleThreshold,
        bool pushEnabled)
    {
        NotifyCashShortage = notifyCashShortage;
        NotifySaleVoided = notifySaleVoided;
        NotifyLowStock = notifyLowStock;
        HighSaleThreshold = highSaleThreshold;
        PushEnabled = pushEnabled;
    }
}
