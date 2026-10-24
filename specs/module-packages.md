# Module Packages & Capabilities

> Monetization entitlements, add-on packages, capability-gated navigation, and customer
> invoicing. See `tasks/module-packages/TASKS.md` for the one-responsibility task breakdown.

## Feature

`Module Packages — subscription entitlements, add-on packages, offline capability gating, and customer invoicing`

## Purpose

Turn the platform into a monetizable product. A tenant's plan plus any add-on packages
decide which modules its staff may open and write to, and the same decision must hold
offline so a tablet in a market with no signal never hard-locks a cashier. Customer
invoicing is delivered as the first add-on package (`invoice-manager`) to prove the
package model end to end.

Serves: platform owner (revenue), tenant owner (buys packages and sees what is active),
tenant staff (get a clear "why is this locked" answer instead of a silent 403).

## Business rules

- **Effective features** = `(base plan feature keys ∪ keys of every active SubscriptionItem plan) ∩ enabled tenant feature flags`.
  A package can never *widen* the tenant beyond the feature flags it was provisioned with.
- **Plan catalog** (seeded idempotently by `DatabaseSeeder.EnsureBillingCatalogAsync`):
  - `Free` — 0 TZS, keys = `pos.enabled`, `inventory.enabled`, no quotas.
  - `Pro` — `Plan.ProMonthlyPriceDefaultTzs`, keys = all except `invoicing.enabled`, quotas 3 branches / 5 users / 3000 products.
  - `invoice-manager` — `Plan.InvoiceManagerMonthlyPriceDefaultTzs`, `IsPackage = true`, keys = `invoicing.enabled`.
- **Packages are add-ons, never base plans.** `invoice-manager` is only purchasable on top
  of an existing subscription and is stored as a `SubscriptionItem`; it never replaces
  `Subscription.PlanId` and never grants `invoicing.enabled` to Free or Pro on its own.
- **Access level is derived, not stored.** `SubscriptionAccessEvaluator` derives
  `Full` / `PosAndInventory` from subscription dates; the stored `Subscription.Status` is
  advisory history only.
- **Debt backstop**: while in debt (`AccessLevel.PosAndInventory`) a tenant keeps
  `pos.enabled` and `inventory.enabled`. Every other module is refused.
- **Refusal shape depends on health, not on the module**:
  - healthy plan, feature key missing → **403 `ModuleDisabled`** (tenant is well, module simply off).
  - in debt, feature key missing on a non-backstop module → **402 `BillingRequired`** (tenant owes money).
  This ordering matters: telling a healthy tenant to "go pay" when the real answer is
  "upgrade your plan" is a support ticket generator.
- **Quotas apply only under `Full` access.** `MaxBranches` / `MaxUsers` / `MaxProducts` are
  nulled for degraded access so a debt tenant is never blocked by a plan limit on the modules
  it still owns. Exceeding a quota → **403 `QuotaExceeded`**.
- **Offline window is explicit, never implicit.** `GET /api/v1/capabilities` returns
  `validOfflineUntil = min(nextDue + 7 days, now + 30 days)`; with no due date it is `now + 30 days`.
  The client trusts a cached copy only until that instant, then falls back to the backstop
  set. The client must not invent a longer window.
- **Cache lifetime** is 30 seconds server-side (`SubscriptionEntitlementCache.Lifetime`),
  keyed `billing:entitlement:{tenantId}`.
- **Package activation/removal is immediate and authoritative**: the server recomputes
  entitlements and invalidates the cache, so the next `/capabilities` read reflects it.
- **Customer invoices are not subscription invoices.** They are a separate aggregate with
  their own permissions, status machine, and payment recording. A tenant may hold an
  overdue subscription invoice and still have healthy customer invoices.
- **Invoice status machine**: `Unpaid → PartiallyPaid → Paid`, plus terminal `Void`.
  Voiding is only legal from a non-void, non-Paid state; recording a payment is only legal
  while `AmountPaid < TotalAmount` and the invoice is not void.
- **Payments are partial by design.** `AmountPaid` and `BalanceDue` are maintained
  incrementally; `BalanceDue = TotalAmount − AmountPaid`. An overpayment is a validation
  error, not a negative balance.
- **Totals are server-authoritative.** The client displays a computed preview for UX, but
  subtotal and total are recalculated on the server from the submitted lines.
  Tax and VAT have been removed across invoice workflows.

## Screens (Flutter)

- `/invoices` → `InvoicesPage`: paged list of `CustomerInvoiceSummary` with search,
  status filter, refresh, empty and failure states. Rows show number, customer, status,
  total, balance.
- `/invoices/new` → `CreateInvoicePage`: customer dropdown (null-safe), issue/due date,
  dynamic lines (description, quantity, unit price), notes, live totals, save.
- `/invoices/:id` → `InvoiceDetailPage`: full invoice, line items, payment history,
  record-payment sheet (amount / method / reference), void action.
- `/module-locked` → `ModuleLockedPage`: shown when a route is refused and the session may
  not manage billing. Offers "go to billing" when the session holds `Billing.Manage`.
- Billing page (`Routes.billing`) → package section: base plan cards (non-package plans
  only) plus a separate list of active/available add-on packages with activate/remove.
- `More` tab of `home_page.dart`: every module entry is gated by `enabledModulesProvider`;
  disabled entries are visibly locked and route to billing (if permitted) or
  `/module-locked`. Informational banners show stale capabilities, debt backstop, and the
  pending-sync count.
- **POS is never capability-gated in checkout.** The M5 `offlineWindowOpen()` session-journal
  control is an authentication/security window and stays untouched; the point of the
  backstop rules is that a cashier is never locked out of taking money.

## API (backend)

Success responses use `Result<T>.ToApiResult()` → **HTTP 200** with
`{ title, status, code, detail, errors? }` on failure. The Flutter repositories correctly
expect 200 for every call in this slice.

- `GET /api/v1/capabilities` — permission: authenticated tenant member. Returns
  `CapabilitiesDto(FeatureKeys, PlanFeatureKeys, Packages, PlanCode, AccessLevel, Status,
  EvaluatedAtUtc, ValidOfflineUntil, NextDueUtc, HasOpenInvoice, MaxBranches, MaxUsers, MaxProducts)`.
- `POST /api/v1/billing/packages/{planCode}` — activate an add-on package. Requires
  `Billing.Manage`. Returns the recalculated package code list.
- `DELETE /api/v1/billing/packages/{planCode}` — remove an add-on package. Requires
  `Billing.Manage`. Returns the recalculated package code list.
- `GET /api/v1/invoices?page&pageSize&status&customerId&search` — `Invoices.View`.
  Returns `PagedResult<CustomerInvoiceSummaryDto>` (Items, Page, PageSize, Total).
- `GET /api/v1/invoices/{invoiceId}` — `Invoices.View`. Returns `CustomerInvoiceDto` including `Lines`.
- `POST /api/v1/invoices` — `Invoices.Create`. Body `{ lines[], customerId?, currency, issueDate?, dueDate?, notes? }`.
- `POST /api/v1/invoices/{invoiceId}/payments` — `Invoices.Manage`. Body `{ amount, method?, reference? }`.
- `POST /api/v1/invoices/{invoiceId}/void` — `Invoices.Manage`. No body.

**The list/detail shape asymmetry is deliberate and must not be "fixed" in the client**:
the list omits `Lines`, `Subtotal`, `TaxAmount`, `PaymentMethod`, `PaymentReference`,
`PaidAtUtc`, `VoidedAtUtc`, `Currency`, and `Notes` for bandwidth. Hence two Dart models,
`CustomerInvoiceSummary` and `CustomerInvoice`.

Enum note: `CustomerInvoiceStatus` is serialized as an **integer** (no
`JsonStringEnumConverter` is registered), and the Dart client sends `status` as
`status.code` in query strings for the same reason.

## Database

Migration `20260925001000_AddCustomerInvoices` (Postgres, schema `public`):

- `CustomerInvoices` — `Id`, `TenantId`, `Number` (50), `CustomerId?`, `CustomerName?` (200),
  `Currency` (3), `IssueDate`, `DueDate?`, `Notes?`, `Status` (int), `Subtotal`,
  `TaxAmount`, `TotalAmount`, `AmountPaid` (`numeric(18,2)`), `PaymentMethod?` (50),
  `PaymentReference?` (100),   `PaymentRecordedByUserId?`, `PaidAtUtc?`, `VoidedAtUtc?`,
  `VoidedByUserId?`, `CreatedAt`, `CreatedBy?`, `UpdatedAt?`, `UpdatedBy?`.
  Indexes: `(TenantId)`, `(TenantId, Number)`, `(TenantId, Status)`.
- `CustomerInvoiceLines` — created **after** `CustomerInvoices` so the FK target exists;
  FK `CustomerInvoiceId` with cascade delete, index on the FK.

Tenant/audit conventions follow the rest of the schema: `TenantId` on every table,
`CreatedAt`/`CreatedBy`/`UpdatedAt`/`UpdatedBy` audit columns, and money as
`numeric(18,2)`. `BalanceDue` is not persisted — it is derived from
`TotalAmount − AmountPaid` to avoid a denormalized field drifting.

## Validation

- Invoice lines: at least one line; description non-empty; quantity > 0; unit price >= 0;
  per-line total recomputed server-side.
- Payment: amount > 0; amount must not exceed the remaining `BalanceDue`.
- Void: refused when already void, and refused when already fully paid.
- Dates: due date must not precede the issue date.
- Currency: 3-letter code, defaults to `TZS`.
- Errors return `400` with `code = "Validation"` and a field → messages map surfaced as
  `ValidationException.fieldErrors` in Dart. User-facing strings exist in both
  `app_en.arb` and `app_sw.arb`.

## Permissions

- `Invoices.View`, `Invoices.Create`, `Invoices.Manage` (added to `PermissionNames` and to
  the seeded permission list).
- `Billing.Manage` gates package activation/removal and the "go to billing" affordance on
  `/module-locked`; `Billing.View` is the weaker read used by the older premium redirect.
- Module-level gating is *not* a permission: it is the subscription entitlement check, kept
  deliberately separate so "you lack the role" and "you did not buy the module" stay
  distinguishable in the UI and in the ProblemDetails code.

## Events

No new domain events. Entitlement changes are cache invalidations, not events; invoice
status changes are aggregate-internal. This slice deliberately introduces no event
decoupling so that enabling the modules it gates cannot create a circular dependency.

## Reports

No new reports. Existing reports gain nothing from this slice; access to them is instead
gated by the module entitlement, so a tenant without `reports.enabled` gets 403
`ModuleDisabled` from the route map before any report query runs.

## Tests

- `backend/tests/BusinessOS.Tests/Unit/Billing/ModuleRouteMapTests.cs` — route → module
  mapping and the backstop/debt decision table.
- `backend/tests/BusinessOS.Tests/Unit/Invoicing/CustomerInvoiceTests.cs` — status machine,
  partial payments, overpayment rejection, void rules, total recomputation.
- `backend/tests/BusinessOS.Tests/Integration/ModulePackagesTests.cs` — package activation
  and removal moving `invoicing.enabled` in and out of `/capabilities`, and the 403/402
  split between a healthy-disabled module and a debt-blocked module.
- `test/features/billing/billing_controller_test.dart` — fake repository now implements
  `activatePackage` / `removePackage`; asserts entitlement is reloaded and published globally.

## Offline & sync

- Capabilities are cached per tenant in the existing `MetaEntries` table under
  `workspace_capabilities:{tenantId}` — **no schema migration**.
- `CapabilitiesDao.load` returns the cached copy only while
  `entitlement.isOfflineValid(now)` holds, i.e. only until `validOfflineUntil`. This check
  is deliberately **not** skipped for full-access tenants: a full-access copy is still only
  trustworthy until the server's stated window, otherwise a full-access cache would be
  trusted forever.
- On an expired, undecodable, or absent cache the app falls back to the backstop set
  (POS + inventory). Failing open to *everything* would let a tenant use modules it never
  paid for; failing closed to *nothing* would lock out a cashier.
- `CapabilitiesState.source` (`network` / `cache` / `fallback`) drives the stale banner.
- Offline writes stay in the M5 outbox. A queued operation that the server later refuses
  with `ModuleDisabled` is failed terminally as `MODULE_DISABLED`; one refused with
  `BillingRequired` is **released unattempted** (not failed, no attempt burned) so it is
  retried after payment; `QuotaExceeded` fails as `QUOTA`. `SyncOutcome` exposes
  `moduleDisabled` and `billingRequired` for the UI to surface.

## Future improvements

- Per-package pricing/entitlement for `credit`, `multi-branch`, and a future
  `payroll` package (the model is already package-agnostic).
- Usage metering to drive quota upgrade prompts from real consumption.
- A server-pushable capability invalidation channel instead of the 30-second cache poll.
- Partial-refund support on customer invoices (currently payment is one-directional).
- Customer statement/aging reports built on the invoice aggregate.
