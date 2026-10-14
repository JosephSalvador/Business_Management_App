# TASKS — Notifications (Slice 11)

> Spec: `specs/notifications.md`. Implement one task at a time; run analyzers and tests after each;
> update this file as you go. No code until the spec and this plan are approved.
>
> Sub-slices: 11a Domain + Persistence → 11b Commands + Endpoints → 11c Outbox Event Consumers
> → 11d FCM Dispatcher → 11e Flutter UI → 11f Flutter Device Lifecycle + Push.

## Status legend

`[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked (note why)

---

## 11a — Domain & Persistence (Backend)

- [x] 001 **Permissions**: Add `NotificationsView` and `NotificationsManage` to `PermissionNames.cs`, update `All` and `Staff` lists.
- [x] 002 **Domain Entities**:
  - `AppNotification` entity (Category, Type, TitleSw/En, BodySw/En, DataJson, IsRead, ReadAt).
  - `UserDevice` entity (DeviceId, FcmToken, Platform, DeviceName, IsActive).
  - `NotificationPreference` entity (TenantId, UserId, NotifyCashShortage, NotifySaleVoided, NotifyLowStock, HighSaleThreshold, PushEnabled).
- [x] 003 **Persistence Schema & Constants**: Add table names (`Notifications`, `UserDevices`, `NotificationPreferences`) in `TableNames.cs`.
- [x] 004 **Entity Configurations & DbContext**: Add EF Core configurations with explicit schema, indexes, and FKs; register DbSets on `BusinessDbContext`.
- [x] 005 **Migration**: Generate and verify EF Core migration `AddNotificationsAndUserDevices`.
- [x] 006 **Repositories**:
  - `IAppNotificationRepository` & EF implementation (`GetByIdAsync`, `ListPagedAsync`, `GetUnreadCountAsync`, `MarkAsReadAsync`, `MarkAllAsReadAsync`, `AddAsync`).
  - `IUserDeviceRepository` & EF implementation (`GetByDeviceAsync`, `UpsertAsync`, `DeactivateAsync`, `ListActiveForRecipientsAsync`).
  - `INotificationPreferenceRepository` & EF implementation (`GetByTenantAndUserAsync`, `UpsertAsync`).

---

## 11b — Application Layer & REST Endpoints (Backend)

- [x] 007 **DTOs, Mappers & Validators**: `NotificationDto`, `UserDeviceDto`, `NotificationPreferencesDto`, `RegisterDeviceCommandValidator`, `UpdateNotificationPreferencesValidator`.
- [x] 008 **Queries**:
  - `GetNotificationsQuery` (paged, filter by category/isRead).
  - `GetUnreadNotificationCountQuery`.
  - `GetNotificationPreferencesQuery`.
- [x] 009 **Commands**:
  - `MarkNotificationReadCommand`.
  - `MarkAllNotificationsReadCommand`.
  - `RegisterUserDeviceCommand`.
  - `UnregisterUserDeviceCommand`.
  - `UpdateNotificationPreferencesCommand`.
- [x] 010 **API Endpoints**: Create `NotificationEndpoints.cs` mapping endpoints under `/api/v1/notifications` and `/api/v1/devices`, wire to `Program.cs`.
- [x] 011 **Backend Unit & Integration Tests**: Verify paged retrieval, unread count accuracy, mark-read isolation, and multi-tenant isolation.

---

## 11c — Outbox Consumers & Alert Triggers (Backend)

- [x] 012 **Cash Shortage Alert Handler**: Consume `CashSessionClosedEvent` (or equivalent cash drawer close); if shortage exists, generate admin notification.
- [x] 013 **Sale Voided Alert Handler**: Consume `SaleVoidedEvent`; generate high-priority notification with reason and amount.
- [x] 014 **Low Stock Alert Handler**: Trigger notification when stock balance drops to or below product reorder threshold.
- [x] 015 **Debt / Credit Alert Handler**: Consume customer credit payment and debt milestone events.
- [x] 016 **Unit Tests for Event Handlers**: Ensure idempotent processing and correct Swahili/English text generation.

---

## 11d — FCM Push Dispatcher (Backend)

- [x] 017 **FCM Client Port & Service**: Implement `IFcmPushSender` using Firebase Admin SDK (with graceful logging fallback when credentials are not configured in dev/test).
- [x] 018 **Notification Dispatch Worker Pipeline**: Background worker / outbox step that looks up `UserDevices` for recipients and pushes FCM messages with payload routing.

---

## 11e — Flutter In-App Notification Center (Client)

- [x] 019 **Notification Models & State**: `NotificationModel`, `NotificationFilter`, Riverpod providers (`notificationsProvider`, `unreadCountProvider`).
- [x] 020 **Notification Repository**: HTTP client calls for listing, unread count, and marking read.
- [x] 021 **App Bar Bell & Badge**: Add interactive bell with unread badge to `HomeShell` and POS top bar.
- [x] 022 **Notification Center Sheet/Page**: Build notification feed with category tabs (All, Cash & Sales, Stock, Debt), relative Swahili timestamps, and unread highlight dots.
- [x] 023 **Deep-Link Navigation**: Configure tap actions on notification items to navigate via `go_router` to the referenced screen (`/sales/:id`, `/cash-sessions/:id`, `/products/:id`).

---

## 11f — Flutter Device Lifecycle & FCM Client (Client)

- [x] 024 **Device Registration Service**: Capture device ID, platform, and FCM token; call `POST /api/v1/devices/register` upon login and token refresh.
- [x] 025 **Device Logout Cleanup**: Call `DELETE /api/v1/devices/{id}` on session termination to prevent cross-tenant notification leaks.
- [x] 026 **Push Message Listener**: Handle foreground push popups and background tap routing.
- [x] 027 **End-to-End Verification**: Run analyzer, unit/widget tests, and build check.
