using BusinessOS.Application.Features.Notifications;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Notifications;
using BusinessOS.Shared;
using Xunit;

namespace BusinessOS.Tests.Unit.Notifications;

public sealed class NotificationFeatureTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly Guid UserId = Guid.NewGuid();

    [Fact]
    public void AppNotification_Create_InitializesCorrectly()
    {
        var notif = AppNotification.Create(
            TenantId,
            UserId,
            targetRole: null,
            branchId: null,
            category: "Sales",
            type: "SALE_VOIDED",
            titleSw: "Mauzo Yamefutwa",
            titleEn: "Sale Voided",
            bodySw: "Risiti #S-001 imefutwa",
            bodyEn: "Receipt #S-001 voided",
            dataJson: "{\"saleId\":\"123\"}");

        Assert.Equal(TenantId, notif.TenantId);
        Assert.Equal(UserId, notif.UserId);
        Assert.Equal("Sales", notif.Category);
        Assert.Equal("SALE_VOIDED", notif.Type);
        Assert.Equal("Mauzo Yamefutwa", notif.TitleSw);
        Assert.Equal("Sale Voided", notif.TitleEn);
        Assert.False(notif.IsRead);
        Assert.Null(notif.ReadAt);
    }

    [Fact]
    public void AppNotification_MarkAsRead_UpdatesStatus()
    {
        var notif = AppNotification.Create(
            TenantId,
            UserId,
            null,
            null,
            "Cash",
            "CASH_SHORTAGE",
            "Pengo la Fedha",
            "Cash Shortage",
            "Upungufu wa 10,000",
            "Shortage of 10,000");

        var readTime = DateTime.UtcNow;
        notif.MarkAsRead(readTime);

        Assert.True(notif.IsRead);
        Assert.Equal(readTime, notif.ReadAt);
    }

    [Fact]
    public void UserDevice_Lifecycle_Works()
    {
        var device = UserDevice.Create(
            TenantId,
            UserId,
            "device-123",
            "token-abc",
            "android",
            "Samsung A14");

        Assert.True(device.IsActive);
        Assert.Equal("token-abc", device.FcmToken);

        device.UpdateToken("token-xyz", "Samsung A15");
        Assert.Equal("token-xyz", device.FcmToken);
        Assert.Equal("Samsung A15", device.DeviceName);

        device.Deactivate();
        Assert.False(device.IsActive);

        device.Activate();
        Assert.True(device.IsActive);
    }

    [Fact]
    public void NotificationPreference_DefaultAndLifecycle_Works()
    {
        var pref = NotificationPreference.CreateDefault(TenantId, UserId);

        Assert.True(pref.NotifyCashShortage);
        Assert.True(pref.NotifySaleVoided);
        Assert.True(pref.NotifyLowStock);
        Assert.Equal(500000m, pref.HighSaleThreshold);
        Assert.True(pref.PushEnabled);

        pref.Update(false, true, false, 1000000m, false);

        Assert.False(pref.NotifyCashShortage);
        Assert.True(pref.NotifySaleVoided);
        Assert.False(pref.NotifyLowStock);
        Assert.Equal(1000000m, pref.HighSaleThreshold);
        Assert.False(pref.PushEnabled);
    }

    [Fact]
    public void Validators_EnforceRules()
    {
        var deviceValidator = new RegisterDeviceRequestValidator();
        var invalidDevice = new RegisterDeviceRequest("", "", "", null);
        var deviceResult = deviceValidator.Validate(invalidDevice);
        Assert.False(deviceResult.IsValid);

        var validDevice = new RegisterDeviceRequest("dev-1", "fcm-tok", "android", "Phone");
        Assert.True(deviceValidator.Validate(validDevice).IsValid);

        var prefValidator = new UpdateNotificationPreferencesRequestValidator();
        var invalidPref = new UpdateNotificationPreferencesRequest(true, true, true, -10m, true);
        Assert.False(prefValidator.Validate(invalidPref).IsValid);

        var validPref = new UpdateNotificationPreferencesRequest(true, true, true, 200000m, true);
        Assert.True(prefValidator.Validate(validPref).IsValid);
    }

    [Fact]
    public async Task GetUnreadNotificationCountQueryHandler_ReturnsCount()
    {
        var tenantContext = new FakeTenantContext(TenantId, UserId);
        var repo = new FakeNotificationRepository { UnreadCountToReturn = 7 };

        var handler = new GetUnreadNotificationCountQueryHandler(tenantContext, repo);
        var result = await handler.Handle(new GetUnreadNotificationCountQuery(), CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(7, result.Value.Count);
    }

    [Fact]
    public async Task MarkNotificationReadCommandHandler_InvokesRepository()
    {
        var tenantContext = new FakeTenantContext(TenantId, UserId);
        var notifId = Guid.NewGuid();
        var repo = new FakeNotificationRepository();

        var handler = new MarkNotificationReadCommandHandler(tenantContext, repo);
        var result = await handler.Handle(new MarkNotificationReadCommand(notifId), CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.True(result.Value);
        Assert.Equal(notifId, repo.LastMarkedReadId);
    }

    [Fact]
    public async Task RegisterUserDeviceCommandHandler_InvokesRepository()
    {
        var tenantContext = new FakeTenantContext(TenantId, UserId);
        var repo = new FakeUserDeviceRepository();

        var handler = new RegisterUserDeviceCommandHandler(tenantContext, repo);
        var cmd = new RegisterUserDeviceCommand("dev-99", "tok-99", "ios", "iPhone 15");
        var result = await handler.Handle(cmd, CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.NotNull(repo.LastUpserted);
        Assert.Equal("dev-99", repo.LastUpserted.DeviceId);
        Assert.Equal(TenantId, repo.LastUpserted.TenantId);
    }

    private sealed class FakeTenantContext(Guid tenantId, Guid? userId) : ITenantContext
    {
        public Guid TenantId => tenantId;
        public Guid? UserId => userId;
        public string? IpAddress => null;
        public string? UserAgent => null;
        public string? CurrentRefreshToken => null;
    }

    private sealed class FakeNotificationRepository : IAppNotificationRepository
    {
        public int UnreadCountToReturn { get; set; }
        public Guid? LastMarkedReadId { get; private set; }

        public Task<AppNotification?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default)
            => Task.FromResult<AppNotification?>(null);

        public Task<IReadOnlyList<AppNotification>> ListPagedAsync(
            Guid tenantId, Guid? userId, string? targetRole, int page, int pageSize, NotificationListFilter filter, CancellationToken cancellationToken = default)
            => Task.FromResult<IReadOnlyList<AppNotification>>(Array.Empty<AppNotification>());

        public Task<int> GetUnreadCountAsync(Guid tenantId, Guid? userId, string? targetRole, CancellationToken cancellationToken = default)
            => Task.FromResult(UnreadCountToReturn);

        public Task MarkAsReadAsync(Guid tenantId, Guid id, DateTime readAt, CancellationToken cancellationToken = default)
        {
            LastMarkedReadId = id;
            return Task.CompletedTask;
        }

        public Task<int> MarkAllAsReadAsync(Guid tenantId, Guid userId, DateTime readAt, CancellationToken cancellationToken = default)
            => Task.FromResult(1);

        public Task AddAsync(AppNotification notification, CancellationToken cancellationToken = default)
            => Task.CompletedTask;
    }

    private sealed class FakeUserDeviceRepository : IUserDeviceRepository
    {
        public UserDevice? LastUpserted { get; private set; }

        public Task<UserDevice?> GetByDeviceAsync(Guid tenantId, Guid userId, string deviceId, CancellationToken cancellationToken = default)
            => Task.FromResult<UserDevice?>(null);

        public Task<IReadOnlyList<UserDevice>> ListActiveForUsersAsync(Guid tenantId, IReadOnlyList<Guid> userIds, CancellationToken cancellationToken = default)
            => Task.FromResult<IReadOnlyList<UserDevice>>(Array.Empty<UserDevice>());

        public Task<IReadOnlyList<UserDevice>> ListActiveForRoleAsync(Guid tenantId, string roleName, CancellationToken cancellationToken = default)
            => Task.FromResult<IReadOnlyList<UserDevice>>(Array.Empty<UserDevice>());

        public Task UpsertAsync(UserDevice device, CancellationToken cancellationToken = default)
        {
            LastUpserted = device;
            return Task.CompletedTask;
        }

        public Task DeactivateAsync(Guid tenantId, Guid userId, string deviceId, CancellationToken cancellationToken = default)
            => Task.CompletedTask;
    }
}
