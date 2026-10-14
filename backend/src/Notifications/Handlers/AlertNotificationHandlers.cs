using System.Text.Json;
using BusinessOS.Application.Notifications;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Events;
using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Notifications;
using Microsoft.Extensions.Logging;

namespace BusinessOS.Notifications.Handlers;

/// <summary>
/// Dispatches an alert when a cash session is closed with a negative variance (shortage).
/// </summary>
public sealed class CashShortageAlertNotificationHandler : IDomainEventHandler<CashSessionClosedEvent>
{
    private readonly IAppNotificationRepository _notifications;
    private readonly INotificationPreferenceRepository _preferences;
    private readonly IUserDeviceRepository _devices;
    private readonly INotificationService _notificationService;
    private readonly ILogger<CashShortageAlertNotificationHandler> _logger;

    public CashShortageAlertNotificationHandler(
        IAppNotificationRepository notifications,
        INotificationPreferenceRepository preferences,
        IUserDeviceRepository devices,
        INotificationService notificationService,
        ILogger<CashShortageAlertNotificationHandler> logger)
    {
        _notifications = notifications;
        _preferences = preferences;
        _devices = devices;
        _notificationService = notificationService;
        _logger = logger;
    }

    public async Task HandleAsync(CashSessionClosedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        if (domainEvent.Variance >= 0)
        {
            return;
        }

        var pref = await _preferences.GetByTenantAndUserAsync(domainEvent.TenantId, null, cancellationToken);
        if (pref is not null && !pref.NotifyCashShortage)
        {
            return;
        }

        var shortage = Math.Abs(domainEvent.Variance);
        var titleSw = "Pengo la Fedha";
        var titleEn = "Cash Shortage Alert";
        var bodySw = $"Kikao cha fedha kimefungwa kikiwa na upungufu wa TZS {shortage:N0}.";
        var bodyEn = $"Cash session closed with a shortage of TZS {shortage:N0}.";
        var dataJson = JsonSerializer.Serialize(new
        {
            sessionId = domainEvent.SessionId,
            variance = domainEvent.Variance,
            route = $"/cash-sessions/{domainEvent.SessionId}"
        });

        var notif = AppNotification.Create(
            domainEvent.TenantId,
            userId: null,
            targetRole: SystemRoles.Administrator,
            branchId: null,
            category: "Cash",
            type: "CASH_SHORTAGE",
            titleSw: titleSw,
            titleEn: titleEn,
            bodySw: bodySw,
            bodyEn: bodyEn,
            dataJson: dataJson);

        await _notifications.AddAsync(notif, cancellationToken);
        _logger.LogWarning("Created cash shortage notification for tenant {TenantId}: {Shortage}", domainEvent.TenantId, shortage);

        if (pref is null || pref.PushEnabled)
        {
            var devices = await _devices.ListActiveForRoleAsync(domainEvent.TenantId, SystemRoles.Administrator, cancellationToken);
            foreach (var dev in devices)
            {
                await _notificationService.SendPushAsync(
                    new PushMessage(dev.FcmToken, titleSw, bodySw, dataJson),
                    cancellationToken);
            }
        }
    }
}

/// <summary>
/// Dispatches an alert when a sale is voided.
/// </summary>
public sealed class SaleVoidedAlertNotificationHandler : IDomainEventHandler<SaleVoidedEvent>
{
    private readonly IAppNotificationRepository _notifications;
    private readonly INotificationPreferenceRepository _preferences;
    private readonly IUserDeviceRepository _devices;
    private readonly INotificationService _notificationService;
    private readonly ILogger<SaleVoidedAlertNotificationHandler> _logger;

    public SaleVoidedAlertNotificationHandler(
        IAppNotificationRepository notifications,
        INotificationPreferenceRepository preferences,
        IUserDeviceRepository devices,
        INotificationService notificationService,
        ILogger<SaleVoidedAlertNotificationHandler> logger)
    {
        _notifications = notifications;
        _preferences = preferences;
        _devices = devices;
        _notificationService = notificationService;
        _logger = logger;
    }

    public async Task HandleAsync(SaleVoidedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        var pref = await _preferences.GetByTenantAndUserAsync(domainEvent.TenantId, null, cancellationToken);
        if (pref is not null && !pref.NotifySaleVoided)
        {
            return;
        }

        var titleSw = "Mauzo Yamefutwa";
        var titleEn = "Sale Voided Alert";
        var bodySw = $"Risiti #{domainEvent.Number} ya {domainEvent.Currency} {domainEvent.TotalAmount:N0} imefutwa. Sababu: {domainEvent.Reason}";
        var bodyEn = $"Receipt #{domainEvent.Number} of {domainEvent.Currency} {domainEvent.TotalAmount:N0} was voided. Reason: {domainEvent.Reason}";
        var dataJson = JsonSerializer.Serialize(new
        {
            saleId = domainEvent.SaleId,
            number = domainEvent.Number,
            route = $"/sales/{domainEvent.SaleId}"
        });

        var notif = AppNotification.Create(
            domainEvent.TenantId,
            userId: null,
            targetRole: SystemRoles.Administrator,
            branchId: domainEvent.BranchId,
            category: "Sales",
            type: "SALE_VOIDED",
            titleSw: titleSw,
            titleEn: titleEn,
            bodySw: bodySw,
            bodyEn: bodyEn,
            dataJson: dataJson);

        await _notifications.AddAsync(notif, cancellationToken);
        _logger.LogInformation("Created sale voided notification for sale {Number} in tenant {TenantId}", domainEvent.Number, domainEvent.TenantId);

        if (pref is null || pref.PushEnabled)
        {
            var devices = await _devices.ListActiveForRoleAsync(domainEvent.TenantId, SystemRoles.Administrator, cancellationToken);
            foreach (var dev in devices)
            {
                await _notificationService.SendPushAsync(
                    new PushMessage(dev.FcmToken, titleSw, bodySw, dataJson),
                    cancellationToken);
            }
        }
    }
}

/// <summary>
/// Dispatches an alert when a high-value sale completes exceeding the tenant threshold.
/// </summary>
public sealed class HighValueSaleAlertNotificationHandler : IDomainEventHandler<SaleCompletedEvent>
{
    private readonly IAppNotificationRepository _notifications;
    private readonly INotificationPreferenceRepository _preferences;
    private readonly IUserDeviceRepository _devices;
    private readonly INotificationService _notificationService;

    public HighValueSaleAlertNotificationHandler(
        IAppNotificationRepository notifications,
        INotificationPreferenceRepository preferences,
        IUserDeviceRepository devices,
        INotificationService notificationService)
    {
        _notifications = notifications;
        _preferences = preferences;
        _devices = devices;
        _notificationService = notificationService;
    }

    public async Task HandleAsync(SaleCompletedEvent domainEvent, CancellationToken cancellationToken = default)
    {
        var pref = await _preferences.GetByTenantAndUserAsync(domainEvent.TenantId, null, cancellationToken);
        var threshold = pref?.HighSaleThreshold ?? 500000m;

        if (domainEvent.TotalAmount < threshold)
        {
            return;
        }

        var titleSw = "Mauzo Makubwa!";
        var titleEn = "High-Value Sale!";
        var bodySw = $"Mauzo ya {domainEvent.Currency} {domainEvent.TotalAmount:N0} (Risiti #{domainEvent.Number}) yamekamilika.";
        var bodyEn = $"Sale of {domainEvent.Currency} {domainEvent.TotalAmount:N0} (Receipt #{domainEvent.Number}) completed.";
        var dataJson = JsonSerializer.Serialize(new
        {
            saleId = domainEvent.SaleId,
            number = domainEvent.Number,
            route = $"/sales/{domainEvent.SaleId}"
        });

        var notif = AppNotification.Create(
            domainEvent.TenantId,
            userId: null,
            targetRole: SystemRoles.Administrator,
            branchId: domainEvent.BranchId,
            category: "Sales",
            type: "HIGH_VALUE_SALE",
            titleSw: titleSw,
            titleEn: titleEn,
            bodySw: bodySw,
            bodyEn: bodyEn,
            dataJson: dataJson);

        await _notifications.AddAsync(notif, cancellationToken);

        if (pref is null || pref.PushEnabled)
        {
            var devices = await _devices.ListActiveForRoleAsync(domainEvent.TenantId, SystemRoles.Administrator, cancellationToken);
            foreach (var dev in devices)
            {
                await _notificationService.SendPushAsync(
                    new PushMessage(dev.FcmToken, titleSw, bodySw, dataJson),
                    cancellationToken);
            }
        }
    }
}

/// <summary>
/// Dispatches an alert when an invoice payment is received.
/// </summary>
public sealed class CustomerInvoicePaidAlertNotificationHandler : IDomainEventHandler<CustomerInvoicePaidEvent>
{
    private readonly IAppNotificationRepository _notifications;
    private readonly INotificationPreferenceRepository _preferences;
    private readonly IUserDeviceRepository _devices;
    private readonly INotificationService _notificationService;

    public CustomerInvoicePaidAlertNotificationHandler(
        IAppNotificationRepository notifications,
        INotificationPreferenceRepository preferences,
        IUserDeviceRepository devices,
        INotificationService notificationService)
    {
        _notifications = notifications;
        _preferences = preferences;
        _devices = devices;
        _notificationService = notificationService;
    }

    public async Task HandleAsync(CustomerInvoicePaidEvent domainEvent, CancellationToken cancellationToken = default)
    {
        var titleSw = "Malipo ya Ankara Yamepokelewa";
        var titleEn = "Invoice Payment Received";
        var bodySw = $"Malipo ya {domainEvent.Currency} {domainEvent.AmountPaid:N0} yamepokelewa kwa Ankara #{domainEvent.InvoiceNumber}.";
        var bodyEn = $"Payment of {domainEvent.Currency} {domainEvent.AmountPaid:N0} received for Invoice #{domainEvent.InvoiceNumber}.";
        var dataJson = JsonSerializer.Serialize(new
        {
            invoiceId = domainEvent.CustomerInvoiceId,
            number = domainEvent.InvoiceNumber,
            route = $"/invoices/{domainEvent.CustomerInvoiceId}"
        });

        var notif = AppNotification.Create(
            domainEvent.TenantId,
            userId: null,
            targetRole: SystemRoles.Administrator,
            branchId: null,
            category: "Credit",
            type: "INVOICE_PAID",
            titleSw: titleSw,
            titleEn: titleEn,
            bodySw: bodySw,
            bodyEn: bodyEn,
            dataJson: dataJson);

        await _notifications.AddAsync(notif, cancellationToken);

        var pref = await _preferences.GetByTenantAndUserAsync(domainEvent.TenantId, null, cancellationToken);
        if (pref is null || pref.PushEnabled)
        {
            var devices = await _devices.ListActiveForRoleAsync(domainEvent.TenantId, SystemRoles.Administrator, cancellationToken);
            foreach (var dev in devices)
            {
                await _notificationService.SendPushAsync(
                    new PushMessage(dev.FcmToken, titleSw, bodySw, dataJson),
                    cancellationToken);
            }
        }
    }
}
