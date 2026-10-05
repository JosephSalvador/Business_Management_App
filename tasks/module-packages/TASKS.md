# TASKS — Module Packages & Capabilities (Slice: monetization)

> Spec: `specs/module-packages.md`. Implement one task at a time; run analyzers and tests after each;
> update this file as you go. No code until the spec and this plan are approved.
>
> Sub-slices: A Entitlements + plans → B Packages + capabilities API → C Enforcement
> → D Customer invoicing → E Flutter capabilities + navigation → F Flutter invoicing
> → G Tests + docs. Commit style: `feat(billing): ...`, `feat(invoicing): ...`.

## Status legend

`[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked (note why)

## Architectural notes (from plan review)

- **Derived, not stored** — `AccessLevel` and `Status` come from
  `SubscriptionAccessEvaluator` reading subscription dates. The stored
  `Subscription.Status` is advisory history; never branch on it.
- **403 vs 402 is a product decision** — a healthy tenant with the module switched off gets
  `ModuleDisabled` (403) and should be told to upgrade; a tenant in debt gets
  `BillingRequired` (402) and should be told to pay. Do not collapse these into one code.
- **Packages never widen feature flags** — entitlements intersect with tenant feature flags
  last, so a package cannot enable a module the tenant was never provisioned for.
- **No new domain events** — this slice gates modules; emitting events from it would risk a
  circular dependency with the modules being gated.
- **Client never invents an offline window** — the server's `validOfflineUntil` is the only
  authority for how long a cached entitlement is trusted.
- **Cashier is never locked out** — POS is a debt backstop and checkout is deliberately not
  capability-gated. Keep the M5 `offlineWindowOpen()` security window intact.

## A — Entitlements + plan catalog

- [x] 001 **Permissions/FeatureKeys**: `invoicing.enabled` + package/feature key constants.
- [x] 002 **Domain — Plan**: `InvoiceManagerCode`, `IsPackage`, package-aware `Seed`.
- [x] 003 **Domain — SubscriptionItem**: add-on purchase row (plan + expiry).
- [x] 004 **Domain — SubscriptionEntitlement**: effective keys, access level, quotas.
- [x] 005 **Evaluator**: derive `Full` / `PosAndInventory` from dates (`SubscriptionAccessEvaluator`).
- [x] 006 **Entitlement service**: union of plan + package keys, then intersect tenant flags; null quotas when degraded.
- [x] 007 **Seeder**: idempotent `EnsureBillingCatalogAsync` (Free, Pro, `invoice-manager` + tenant backfill trial).

## B — Packages + capabilities API

- [x] 008 **Commands**: `ActivatePackageCommand`, `RemovePackageCommand` + handlers.
- [x] 009 **Cache invalidation**: drop `billing:entitlement:{tenantId}` on any package change.
- [x] 010 **Queries**: `GetSubscriptionQuery`, `GetCapabilitiesQuery` (30s cache).
- [x] 011 **DTOs**: `CapabilitiesDto` incl. `PlanFeatureKeys`, `Packages`, `ValidOfflineUntil`.
- [x] 012 **Endpoints**: `GET /capabilities`, `POST|DELETE /billing/packages/{planCode}` (`Billing.Manage`).
- [x] 013 **Offline window**: `validOfflineUntil = min(nextDue + 7d, now + 30d)`.

## C — Enforcement

- [x] 014 **ModuleRouteMap**: request path → owning module + feature key.
- [x] 015 **SubscriptionAccessMiddleware**: allow / 403 `ModuleDisabled` / 402 `BillingRequired`, `module` extension.
- [x] 016 **Entitlement guard**: sub-features and quotas the route map cannot express.
- [x] 017 **Quota errors**: `QuotaExceeded` (403), nulled quotas under degraded access.

## D — Customer invoicing

- [x] 018 **Domain**: `CustomerInvoice` aggregate, `CustomerInvoiceLine`, `CustomerInvoiceStatus`.
- [x] 019 **Rules**: partial payments, overpayment rejection, void legality, derived `BalanceDue`.
- [x] 020 **Migration**: `20260925001000_AddCustomerInvoices` (parent before lines, tenant + audit columns).
- [x] 021 **Commands**: create, record payment, void — tenant advisory lock for exactly-once numbering.
- [x] 022 **Queries**: list (summary, paged), get (full).
- [x] 023 **DTOs**: `CustomerInvoiceDto` vs `CustomerInvoiceSummaryDto` (deliberate asymmetry).
- [x] 024 **Validators**: lines, amounts, dates, currency.
- [x] 025 **Permissions**: `Invoices.View`, `Invoices.Create`, `Invoices.Manage` seeded.
- [x] 026 **Endpoints**: `/api/v1/invoices` list/detail/create/payments/void + `Program.cs` registration.

## E — Flutter capabilities + navigation

- [x] 027 **Domain**: `WorkspaceModule`, feature keys, `CapabilitiesSource`.
- [x] 028 **Data**: `CapabilitiesDao` (`MetaEntries`, no migration), `CapabilitiesRepository`.
- [x] 029 **Controller**: cache restore, refresh de-dup, fallback, reset, `enabledModulesProvider`.
- [x] 030 **Cache validity**: honor `validOfflineUntil` for full access too.
- [x] 031 **Wiring**: auth restore/fetch/logout, HTTP 402 refresh, provider exports.
- [x] 032 **Router**: invoice routes, `moduleRouteRedirect`, `/module-locked`.
- [x] 033 **Home**: per-module `More` entries, stale/debt/pending-sync banners.
- [x] 034 **Errors**: `ModuleDisabledException`, `QuotaExceededException`, ProblemDetails `module` parsing.
- [x] 035 **Sync**: `MODULE_DISABLED` terminal, 402 released unattempted, `QUOTA`, `SyncOutcome` flags.

## F — Flutter invoicing

- [x] 036 **Domain**: `CustomerInvoice`, `CustomerInvoiceSummary`, `InvoiceDraftLine`, parsing.
- [x] 037 **Data**: `InvoiceRepository` (200-status, summary vs full mapping), providers.
- [x] 038 **Controller**: list/pagination/search/filter, create, payment, void.
- [x] 039 **UI — list**: `InvoicesPage` with empty/failure states.
- [x] 040 **UI — create**: `CreateInvoicePage`, parsed line getters, safe customer dropdown.
- [x] 041 **UI — detail**: `InvoiceDetailPage`, payment sheet with disposal, void.
- [x] 042 **Billing UI**: package cards on the billing page, `Billing.Manage` gated.
- [x] 043 **Localization**: invoice/package/module-lock keys in `en` + `sw`.

## G — Tests + docs

- [x] 044 **Unit — module map**: `ModuleRouteMapTests`.
- [x] 045 **Unit — invoicing**: `CustomerInvoiceTests`.
- [x] 046 **Integration**: `ModulePackagesTests` (package toggling + 403/402 split).
- [x] 047 **Widget/unit — Flutter**: billing controller test fake implements package methods.
- [x] 048 **Spec + docs**: `specs/module-packages.md`, this file, changelog, `memory/project.md`.
- [!] 049 **Run the suites**: `flutter analyze`, `flutter test`, `dotnet test`, and the
  `AddCustomerInvoices` migration against Postgres. Blocked: the user has restricted command
  execution for this task. Everything above is verified by static review only.
