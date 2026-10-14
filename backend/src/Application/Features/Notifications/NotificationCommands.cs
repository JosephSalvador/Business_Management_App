using BusinessOS.Application.Ports;
using BusinessOS.Domain.Notifications;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Notifications;

public sealed record MarkNotificationReadCommand(Guid NotificationId) : IRequest<Result<bool>>;

public sealed class MarkNotificationReadCommandHandler : IRequestHandler<MarkNotificationReadCommand, Result<bool>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IAppNotificationRepository _notifications;

    public MarkNotificationReadCommandHandler(
        ITenantContext tenantContext,
        IAppNotificationRepository notifications)
    {
        _tenantContext = tenantContext;
        _notifications = notifications;
    }

    public async Task<Result<bool>> Handle(MarkNotificationReadCommand request, CancellationToken cancellationToken)
    {
        await _notifications.MarkAsReadAsync(
            _tenantContext.TenantId,
            request.NotificationId,
            DateTime.UtcNow,
            cancellationToken);

        return Result.Success(true);
    }
}

public sealed record MarkAllNotificationsReadCommand() : IRequest<Result<int>>;

public sealed class MarkAllNotificationsReadCommandHandler : IRequestHandler<MarkAllNotificationsReadCommand, Result<int>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IAppNotificationRepository _notifications;

    public MarkAllNotificationsReadCommandHandler(
        ITenantContext tenantContext,
        IAppNotificationRepository notifications)
    {
        _tenantContext = tenantContext;
        _notifications = notifications;
    }

    public async Task<Result<int>> Handle(MarkAllNotificationsReadCommand request, CancellationToken cancellationToken)
    {
        var count = await _notifications.MarkAllAsReadAsync(
            _tenantContext.TenantId,
            _tenantContext.UserId ?? Guid.Empty,
            DateTime.UtcNow,
            cancellationToken);

        return Result.Success(count);
    }
}

public sealed record RegisterUserDeviceCommand(
    string DeviceId,
    string FcmToken,
    string Platform,
    string? DeviceName) : IRequest<Result<bool>>;

public sealed class RegisterUserDeviceCommandHandler : IRequestHandler<RegisterUserDeviceCommand, Result<bool>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IUserDeviceRepository _devices;

    public RegisterUserDeviceCommandHandler(
        ITenantContext tenantContext,
        IUserDeviceRepository devices)
    {
        _tenantContext = tenantContext;
        _devices = devices;
    }

    public async Task<Result<bool>> Handle(RegisterUserDeviceCommand request, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var userId = _tenantContext.UserId ?? Guid.Empty;

        var device = UserDevice.Create(
            tenantId,
            userId,
            request.DeviceId,
            request.FcmToken,
            request.Platform,
            request.DeviceName);

        await _devices.UpsertAsync(device, cancellationToken);
        return Result.Success(true);
    }
}

public sealed record UnregisterUserDeviceCommand(string DeviceId) : IRequest<Result<bool>>;

public sealed class UnregisterUserDeviceCommandHandler : IRequestHandler<UnregisterUserDeviceCommand, Result<bool>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IUserDeviceRepository _devices;

    public UnregisterUserDeviceCommandHandler(
        ITenantContext tenantContext,
        IUserDeviceRepository devices)
    {
        _tenantContext = tenantContext;
        _devices = devices;
    }

    public async Task<Result<bool>> Handle(UnregisterUserDeviceCommand request, CancellationToken cancellationToken)
    {
        await _devices.DeactivateAsync(
            _tenantContext.TenantId,
            _tenantContext.UserId ?? Guid.Empty,
            request.DeviceId,
            cancellationToken);

        return Result.Success(true);
    }
}

public sealed record UpdateNotificationPreferencesCommand(
    bool NotifyCashShortage,
    bool NotifySaleVoided,
    bool NotifyLowStock,
    decimal HighSaleThreshold,
    bool PushEnabled) : IRequest<Result<NotificationPreferencesDto>>;

public sealed class UpdateNotificationPreferencesCommandHandler
    : IRequestHandler<UpdateNotificationPreferencesCommand, Result<NotificationPreferencesDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly INotificationPreferenceRepository _preferences;

    public UpdateNotificationPreferencesCommandHandler(
        ITenantContext tenantContext,
        INotificationPreferenceRepository preferences)
    {
        _tenantContext = tenantContext;
        _preferences = preferences;
    }

    public async Task<Result<NotificationPreferencesDto>> Handle(
        UpdateNotificationPreferencesCommand request,
        CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var userId = _tenantContext.UserId;

        var pref = await _preferences.GetByTenantAndUserAsync(tenantId, userId, cancellationToken)
            ?? NotificationPreference.CreateDefault(tenantId, userId);

        pref.Update(
            request.NotifyCashShortage,
            request.NotifySaleVoided,
            request.NotifyLowStock,
            request.HighSaleThreshold,
            request.PushEnabled);

        await _preferences.UpsertAsync(pref, cancellationToken);

        return Result.Success(new NotificationPreferencesDto(
            pref.NotifyCashShortage,
            pref.NotifySaleVoided,
            pref.NotifyLowStock,
            pref.HighSaleThreshold,
            pref.PushEnabled));
    }
}
