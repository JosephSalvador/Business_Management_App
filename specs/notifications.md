# Feature Spec — Notifications (Slice 11)

> Status: `[ ]` spec draft · awaiting approval before implementation.

## Feature

Multi-tenant, zero-cost notification engine with In-App Notification Center,
Owner Anti-Theft & Operations alerts, and Firebase Cloud Messaging (FCM) push dispatch.

## Purpose

Enables business owners and staff to stay informed about critical business events in real time
without paying for expensive SMS APIs. Shop owners who are away from their stores receive instant
anti-theft and financial push alerts (e.g. cash shortages, voided sales, large transactions), while
cashiers and managers receive operational updates (low stock warnings, sync issues, debt due dates).

## Sub-slices

| Slice | Scope |
|-------|-------|
| **11a** | **Domain & Persistence (Backend)**: Domain entities (`AppNotification`, `UserDevice`, `NotificationPreference`), database migration, repositories, `PermissionNames.Notifications*`. |
| **11b** | **Commands, Queries & REST API (Backend)**: List notifications (paged, filtered), unread count badge, mark as read / mark all read, register / unregister device token, get/update preferences. |
| **11c** | **Event Handlers & Outbox Consumers (Backend)**: Outbox consumers for `CashSessionClosedEvent` (shortage alert), `SaleVoidedEvent`, `StockMovementRecordedEvent` (low stock threshold), `CustomerCreditPaymentEvent`. |
| **11d** | **FCM Push Dispatcher (Backend)**: Firebase Admin SDK integration, token resolution by tenant/role/user, multi-device delivery, error handling and dead token pruning. |
| **11e** | **Flutter UI & State Management (Client)**: Top App Bar notification bell with unread badge, Notification Center bottom sheet / screen with Swahili/English relative times, category filter pills, mark-as-read interactions, deep linking via `go_router`. |
| **11f** | **Flutter Device Lifecycle & Push Receiver (Client)**: FCM token registration on login, unregister on logout, foreground message banner, background click handler navigating to target route. |

## Business Rules

1. **Strict Multi-Tenancy**: Every notification and device token is strictly tied to a `TenantId`. Under no circumstances can a notification or device token cross tenant boundaries.
2. **Targeting Matrix**:
   - `Personal`: `UserId != null`. Only delivered to the designated user within the tenant.
   - `Role-based`: `UserId == null` and `TargetRole != null` (e.g. `Administrator`, `Manager`). Delivered to all active users with that role in the tenant.
   - `Branch-scoped`: When `BranchId != null`, role-targeted notifications are restricted to staff assigned to that branch.
3. **Owner Anti-Theft Alerts**:
   - **Cash Shortage**: If a cash session closes with `CountedCash < ExpectedCash`, immediately dispatch a high-priority alert to tenant Administrators with the cashier name and shortage amount.
   - **Sale Voided**: When a sale is voided, send a high-priority alert with the receipt number, amount, and reason.
   - **Excess Discount / High-Value Sale**: When a sale exceeds the tenant's configured threshold (default TZS 500,000), notify the owner.
4. **Idempotency & Deduplication**: Outbox consumers must ensure the same domain event does not generate duplicate notification rows or push messages.
5. **Localization**: Notifications store both Swahili (`_sw`) and English (`_en`) strings. Clients render based on the current locale setting.

## API (Backend)

All endpoints require authentication and are tenant-scoped:

- `GET /api/v1/notifications` (`Notifications.View`)
  - Query: `page=1`, `pageSize=20`, `category=Cash|Sales|Stock|Credit|Security`, `unreadOnly=true|false`
  - Response: `PagedResult<NotificationDto>`
- `GET /api/v1/notifications/unread-count` (`Notifications.View`)
  - Response: `{ "unreadCount": 5 }`
- `PATCH /api/v1/notifications/{id}/read` (`Notifications.View`)
  - Response: `Result<bool>`
- `POST /api/v1/notifications/mark-all-read` (`Notifications.View`)
  - Response: `Result<int>` (count updated)
- `POST /api/v1/devices/register` (Authenticated User)
  - Body: `{ "deviceId": "...", "fcmToken": "...", "platform": "android|ios|web|linux|windows", "deviceName": "..." }`
  - Upserts device registration for `(TenantId, UserId, DeviceId)`.
- `DELETE /api/v1/devices/{deviceId}` (Authenticated User)
  - Deactivates device registration on logout.
- `GET /api/v1/notifications/preferences` (`Notifications.View`)
  - Response: `NotificationPreferencesDto`
- `PUT /api/v1/notifications/preferences` (`Notifications.Manage`)
  - Body: `UpdateNotificationPreferencesInput`

## Database

Tables in `public` schema (per `ArchitectureRules.md`):

1. `UserDevices`:
   - `Id` (UUID PK), `TenantId` (UUID FK), `UserId` (UUID FK), `DeviceId` (string), `FcmToken` (text), `Platform` (string), `DeviceName` (string), `IsActive` (bool), `CreatedAt`, `UpdatedAt`.
   - Unique index on `(TenantId, UserId, DeviceId)`.
2. `Notifications`:
   - `Id` (UUID PK), `TenantId` (UUID FK), `UserId` (UUID nullable FK), `TargetRole` (string nullable), `BranchId` (UUID nullable FK), `Category` (string), `Type` (string), `TitleSw`, `TitleEn`, `BodySw`, `BodyEn`, `DataJson` (jsonb/text), `IsRead` (bool), `ReadAt` (timestamptz nullable), `CreatedAt`, `UpdatedAt`.
   - Composite index on `(TenantId, UserId, CreatedAt DESC)` and `(TenantId, UserId, IsRead)`.
3. `NotificationPreferences`:
   - `Id` (UUID PK), `TenantId` (UUID FK), `UserId` (UUID nullable FK), `NotifyCashShortage` (bool), `NotifySaleVoided` (bool), `NotifyLowStock` (bool), `HighSaleThreshold` (decimal), `PushEnabled` (bool), `CreatedAt`, `UpdatedAt`.

## Permissions

- `Notifications.View`: View notification feed, unread count, mark read, manage personal devices. (Granted to `Administrator` and `Staff`).
- `Notifications.Manage`: Configure tenant-wide notification preferences and thresholds. (Granted to `Administrator`).

## Screens & UI (Flutter)

1. **Top AppBar Bell Icon**:
   - Placed in `HomeShell` and POS header.
   - Badged with unread counter; tapping opens the Notification Center.
2. **Notification Center Sheet / Page**:
   - Paged list of notifications.
   - Filter chips: `Zote` (All), `Fedha & Mauzo` (Cash & Sales), `Stock` (Inventory), `Madeni` (Credit).
   - "Weka zote zimesomwa" (Mark all as read) action.
   - Tapping an item marks it as read and deep-links to the target route (e.g. `/sales/:id`, `/cash-sessions/:id`).
3. **Notification Preferences Settings Screen**:
   - Toggles for cash alerts, low stock alerts, and high-value sale threshold input.

## Offline & Sync

- Offline actions: Devices operate in offline mode as normal. When offline, local notifications (`flutter_local_notifications`) handle immediate device-level warnings (e.g., sync errors).
- Online sync: When connection restores and offline sales sync, the server generates notifications if triggers match (e.g., cash session closed or low stock detected).
- In-app notification center caches the latest 50 notifications locally so the user can review them without an internet connection.
