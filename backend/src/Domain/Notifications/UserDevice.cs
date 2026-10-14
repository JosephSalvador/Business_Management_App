using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Notifications;

public sealed class UserDevice : Entity
{
    private UserDevice(
        Guid id,
        Guid tenantId,
        Guid userId,
        string deviceId,
        string fcmToken,
        string platform,
        string? deviceName,
        bool isActive)
        : base(id)
    {
        TenantId = tenantId;
        UserId = userId;
        DeviceId = deviceId;
        FcmToken = fcmToken;
        Platform = platform;
        DeviceName = deviceName;
        IsActive = isActive;
    }

    public Guid TenantId { get; private set; }
    public Guid UserId { get; private set; }
    public string DeviceId { get; private set; }
    public string FcmToken { get; private set; }
    public string Platform { get; private set; }
    public string? DeviceName { get; private set; }
    public bool IsActive { get; private set; }

    public static UserDevice Create(
        Guid tenantId,
        Guid userId,
        string deviceId,
        string fcmToken,
        string platform,
        string? deviceName = null)
        => new(
            Guid.NewGuid(),
            tenantId,
            userId,
            deviceId,
            fcmToken,
            platform,
            deviceName,
            true);

    public void UpdateToken(string fcmToken, string? deviceName = null)
    {
        FcmToken = fcmToken;
        if (!string.IsNullOrWhiteSpace(deviceName))
        {
            DeviceName = deviceName;
        }

        IsActive = true;
    }

    public void Deactivate()
    {
        IsActive = false;
    }

    public void Activate()
    {
        IsActive = true;
    }
}
