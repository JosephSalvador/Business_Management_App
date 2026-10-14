using BusinessOS.Application.Notifications;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Events;
using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Notifications;
using BusinessOS.Notifications.Handlers;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace BusinessOS.Tests.Unit.Notifications;

public sealed class AlertNotificationHandlerTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly Guid SessionId = Guid.NewGuid();
    private static readonly Guid SaleId = Guid.NewGuid();
    private static readonly Guid AccountId = Guid.NewGuid();

    [Fact]
    public async Task CashShortage_CreatesNotification_WhenNegativeVariance()
    {
        var notifRepo = new FakeNotificationRepository();
        var prefRepo = new FakePreferenceRepository(NotificationPreference.CreateDefault(TenantId));
        var devRepo = new FakeUserDeviceRepository();
        var notifService = new FakeNotificationService();

        var handler = new CashShortageAlertNotificationHandler(
            notifRepo, prefRepo, devRepo, notifService, NullLogger<CashShortageAlertNotificationHandler>.Instance);

        var evt = new CashSessionClosedEvent(
            Guid.NewGuid(), DateTime.UtcNow, SessionId, TenantId, AccountId,
            OpeningCash: 100000m, ClosingCash: 80000m, ExpectedCash: 100000m, Variance: -20000m, Notes: null);

        await handler.HandleAsync(evt);

        Assert.NotNull(notifRepo.LastAdded);
        Assert.Equal("Cash", notifRepo.LastAdded.Category);
        Assert.Equal("CASH_SHORTAGE", notifRepo.LastAdded.Type);
        Assert.Equal(SystemRoles.Administrator, notifRepo.LastAdded.TargetRole);
        Assert.Contains("20,000", notifRepo.LastAdded.BodySw);
    }

    [Fact]
    public async Task CashShortage_Ignores_WhenNoShortage()
    {
        var notifRepo = new FakeNotificationRepository();
        var prefRepo = new FakePreferenceRepository(NotificationPreference.CreateDefault(TenantId));
        var devRepo = new FakeUserDeviceRepository();
        var notifService = new FakeNotificationService();

        var handler = new CashShortageAlertNotificationHandler(
            notifRepo, prefRepo, devRepo, notifService, NullLogger<CashShortageAlertNotificationHandler>.Instance);

        var evt = new CashSessionClosedEvent(
            Guid.NewGuid(), DateTime.UtcNow, SessionId, TenantId, AccountId,
            OpeningCash: 100000m, ClosingCash: 100000m, ExpectedCash: 100000m, Variance: 0m, Notes: null);

        await handler.HandleAsync(evt);

        Assert.Null(notifRepo.LastAdded);
    }

    [Fact]
    public async Task SaleVoided_CreatesNotification_WithReason()
    {
        var notifRepo = new FakeNotificationRepository();
        var prefRepo = new FakePreferenceRepository(NotificationPreference.CreateDefault(TenantId));
        var devRepo = new FakeUserDeviceRepository();
        var notifService = new FakeNotificationService();

        var handler = new SaleVoidedAlertNotificationHandler(
            notifRepo, prefRepo, devRepo, notifService, NullLogger<SaleVoidedAlertNotificationHandler>.Instance);

        var evt = new SaleVoidedEvent(
            Guid.NewGuid(), DateTime.UtcNow, SaleId, TenantId, Guid.NewGuid(), Guid.NewGuid(),
            "S-2026-0042", "TZS", 45000m, "Mteja aliahirisha");

        await handler.HandleAsync(evt);

        Assert.NotNull(notifRepo.LastAdded);
        Assert.Equal("Sales", notifRepo.LastAdded.Category);
        Assert.Equal("SALE_VOIDED", notifRepo.LastAdded.Type);
        Assert.Contains("S-2026-0042", notifRepo.LastAdded.BodySw);
        Assert.Contains("Mteja aliahirisha", notifRepo.LastAdded.BodySw);
    }

    [Fact]
    public async Task HighValueSale_CreatesNotification_WhenOverThreshold()
    {
        var notifRepo = new FakeNotificationRepository();
        var pref = NotificationPreference.CreateDefault(TenantId); // default 500,000
        var prefRepo = new FakePreferenceRepository(pref);
        var devRepo = new FakeUserDeviceRepository();
        var notifService = new FakeNotificationService();

        var handler = new HighValueSaleAlertNotificationHandler(
            notifRepo, prefRepo, devRepo, notifService);

        var evt = new SaleCompletedEvent(
            Guid.NewGuid(), DateTime.UtcNow, SaleId, TenantId, Guid.NewGuid(), Guid.NewGuid(),
            Guid.NewGuid(), "S-2026-0099", "TZS", 750000m, 135000m);

        await handler.HandleAsync(evt);

        Assert.NotNull(notifRepo.LastAdded);
        Assert.Equal("HIGH_VALUE_SALE", notifRepo.LastAdded.Type);
        Assert.Contains("750,000", notifRepo.LastAdded.BodySw);
    }

    [Fact]
    public async Task CustomerInvoicePaid_CreatesNotification()
    {
        var notifRepo = new FakeNotificationRepository();
        var prefRepo = new FakePreferenceRepository(NotificationPreference.CreateDefault(TenantId));
        var devRepo = new FakeUserDeviceRepository();
        var notifService = new FakeNotificationService();

        var handler = new CustomerInvoicePaidAlertNotificationHandler(
            notifRepo, prefRepo, devRepo, notifService);

        var evt = new CustomerInvoicePaidEvent(
            Guid.NewGuid(), DateTime.UtcNow, Guid.NewGuid(), TenantId,
            "CI-2026-0015", 350000m, "TZS", "MPESA-REF-123");

        await handler.HandleAsync(evt);

        Assert.NotNull(notifRepo.LastAdded);
        Assert.Equal("INVOICE_PAID", notifRepo.LastAdded.Type);
        Assert.Contains("CI-2026-0015", notifRepo.LastAdded.BodySw);
    }

    private sealed class FakeNotificationRepository : IAppNotificationRepository
    {
        public AppNotification? LastAdded { get; private set; }

        public Task<AppNotification?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken cancellationToken = default)
            => Task.FromResult<AppNotification?>(null);

        public Task<IReadOnlyList<AppNotification>> ListPagedAsync(
            Guid tenantId, Guid? userId, string? targetRole, int page, int pageSize, NotificationListFilter filter, CancellationToken cancellationToken = default)
            => Task.FromResult<IReadOnlyList<AppNotification>>(Array.Empty<AppNotification>());

        public Task<int> GetUnreadCountAsync(Guid tenantId, Guid? userId, string? targetRole, CancellationToken cancellationToken = default)
            => Task.FromResult(0);

        public Task MarkAsReadAsync(Guid tenantId, Guid id, DateTime readAt, CancellationToken cancellationToken = default)
            => Task.CompletedTask;

        public Task<int> MarkAllAsReadAsync(Guid tenantId, Guid userId, DateTime readAt, CancellationToken cancellationToken = default)
            => Task.FromResult(0);

        public Task AddAsync(AppNotification notification, CancellationToken cancellationToken = default)
        {
            LastAdded = notification;
            return Task.CompletedTask;
        }
    }

    private sealed class FakePreferenceRepository(NotificationPreference? preference) : INotificationPreferenceRepository
    {
        public Task<NotificationPreference?> GetByTenantAndUserAsync(Guid tenantId, Guid? userId, CancellationToken cancellationToken = default)
            => Task.FromResult(preference);

        public Task UpsertAsync(NotificationPreference preference, CancellationToken cancellationToken = default)
            => Task.CompletedTask;
    }

    private sealed class FakeUserDeviceRepository : IUserDeviceRepository
    {
        public Task<UserDevice?> GetByDeviceAsync(Guid tenantId, Guid userId, string deviceId, CancellationToken cancellationToken = default)
            => Task.FromResult<UserDevice?>(null);

        public Task<IReadOnlyList<UserDevice>> ListActiveForUsersAsync(Guid tenantId, IReadOnlyList<Guid> userIds, CancellationToken cancellationToken = default)
            => Task.FromResult<IReadOnlyList<UserDevice>>(Array.Empty<UserDevice>());

        public Task<IReadOnlyList<UserDevice>> ListActiveForRoleAsync(Guid tenantId, string roleName, CancellationToken cancellationToken = default)
            => Task.FromResult<IReadOnlyList<UserDevice>>(Array.Empty<UserDevice>());

        public Task UpsertAsync(UserDevice device, CancellationToken cancellationToken = default)
            => Task.CompletedTask;

        public Task DeactivateAsync(Guid tenantId, Guid userId, string deviceId, CancellationToken cancellationToken = default)
            => Task.CompletedTask;
    }

    private sealed class FakeNotificationService : INotificationService
    {
        public Task SendEmailAsync(EmailMessage message, CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task SendSmsAsync(SmsMessage message, CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task SendPushAsync(PushMessage message, CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task SendWhatsAppAsync(WhatsAppMessage message, CancellationToken cancellationToken = default) => Task.CompletedTask;
    }
}
