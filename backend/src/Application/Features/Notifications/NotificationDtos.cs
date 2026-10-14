namespace BusinessOS.Application.Features.Notifications;

public sealed record NotificationDto(
    Guid Id,
    Guid? UserId,
    string? TargetRole,
    Guid? BranchId,
    string Category,
    string Type,
    string TitleSw,
    string TitleEn,
    string BodySw,
    string BodyEn,
    string? DataJson,
    bool IsRead,
    DateTime? ReadAt,
    DateTime CreatedAt);

public sealed record UnreadCountDto(int Count);

public sealed record UserDeviceDto(
    Guid Id,
    Guid UserId,
    string DeviceId,
    string Platform,
    string? DeviceName,
    bool IsActive,
    DateTime CreatedAt);

public sealed record NotificationPreferencesDto(
    bool NotifyCashShortage,
    bool NotifySaleVoided,
    bool NotifyLowStock,
    decimal HighSaleThreshold,
    bool PushEnabled);

public sealed record RegisterDeviceRequest(
    string DeviceId,
    string FcmToken,
    string Platform,
    string? DeviceName);

public sealed record UpdateNotificationPreferencesRequest(
    bool NotifyCashShortage,
    bool NotifySaleVoided,
    bool NotifyLowStock,
    decimal HighSaleThreshold,
    bool PushEnabled);
