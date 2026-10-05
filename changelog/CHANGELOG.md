# Changelog

## Unreleased

- **Modules:** subscription entitlements now drive the UI, not just the API. Effective
  features are `(base plan keys ∪ add-on package keys) ∩ enabled tenant feature flags`, so a
  package can never widen a tenant past the flags it was provisioned for. Both the `More`
  menu and the primary tabs are capability-gated: locked tabs show a lock badge, route to
  billing when the session may manage it or to a dedicated `/module-locked` screen
  otherwise, and render a placeholder rather than the real page. POS and inventory are debt
  backstops, so a tenant in arrears keeps taking money.
- **Modules — 403 vs 402:** a healthy plan with a module switched off is refused with
  `ModuleDisabled` (403, "upgrade"), while a tenant in debt is refused with
  `BillingRequired` (402, "pay"). The two are deliberately distinct answers; collapsing
  them was rejected. Both carry a `module` extension so the client can explain itself.
- **Packages:** the first add-on, `invoice-manager`, ships end to end. It is a
  `SubscriptionItem`, never a base plan, so `invoicing.enabled` cannot leak into Free or
  Pro. Activation and removal are available from the billing page to `Billing.Manage`
  sessions and take effect on the next capabilities read.
- **Capabilities + offline:** `GET /api/v1/capabilities` reports the plan's keys, active
  packages, quotas, and a `validOfflineUntil` window (`min(nextDue + 7d, now + 30d)`). The
  client caches it per tenant and trusts it only until that instant — including for
  full-access tenants — then falls back to the backstop set instead of either unlocking
  unpaid modules or locking out the cashier. A stale-cache banner explains the reduced
  state instead of failing silently.
- **Invoicing:** customer invoicing is now a real module (list, detail, create, partial
  payments, void) behind `Invoices.View/Create/Manage`, with status
  `Unpaid → PartiallyPaid → Paid` plus terminal `Void`, overpayment rejection, and
  server-recomputed totals. It is independent of subscription billing: an overdue
  subscription invoice does not block healthy customer invoices. The list endpoint returns
  a summary shape and the detail endpoint the full document, which is why the client has
  separate `CustomerInvoiceSummary` / `CustomerInvoice` models.
- **Sync:** a queued offline sale refused because its module is disabled now fails
  terminally instead of retrying forever, and one refused for billing reasons is released
  unattempted — no attempt is burned, so it simply goes through after payment.
- **POS:** checkout stays reachable regardless of capabilities. The existing
  `offlineWindowOpen()` control is an authentication window, not a plan check, and is
  unchanged.
- **Fix:** the committed generated localizations were badly out of date (363 ARB keys
  missing, 295 of them referenced from `lib/`), so the app could not compile. Localizations
  were regenerated from the ARB sources, which remain the only place to edit them.
- **Fix:** login no longer fetches the subscription and the capabilities separately —
  capabilities carry a superset of that data, so the subscription endpoint is now only a
  fallback.

- **Receipts:** the on-screen ticket and the thermal slip are now one artifact
  (`specs/receipts.md`). `Thermal80mmRenderer` was rewritten around a 42-column width
  invariant with a Jolinx-style ticket: centered business header (branch, address, phone,
  **email**, tax no.), meta block with **cashier and customer**, a 4-column item table that
  now prints the **unit price**, `Subtotal` / `Discount (n%)` / `GRAND
  TOTAL` rows (VAT/tax is deferred — no tax row and no derived percentage), payment block
  with **transaction id** (first tender reference), fiscal
  `Verification:` and a QR block that only print when there is content, and a policy footer.
- **Receipts API:** `ReceiptPreviewDto` gains `email`, `branchName`, `cashierName`,
  `customerName`, `currency` and `payments[].reference`, projected by
  `GetReceiptPreviewQuery` (branch/user display names, customer, tenant currency, tender
  reference) — no more `Business` / `Walk-in` placeholders.
- **Receipts UI:** new provider-free `ReceiptTicketCard` replaces the raw monospace text on
  `ReceiptPreviewPage` and `SaleSuccessPage`; the **RobotoMono** font is finally registered
  (it was silently falling back to a proportional font and misaligning every column).
- **Receipts localization:** receipt labels follow the app locale (`ReceiptLanguage.en/sw`)
  through `ReceiptLabels`, so screen, copied text, PDF and thermal print all speak the same
  language.
- **Receipts reprint + audit:** the previously dead reprint watermark is wired — pages render
  `*** REPRINT ***` once `printCount > 0` (plus a same-session counter) and fire-and-forget
  `POST /receipts/{saleId}/print` after every successful print (`Original` then `Reprint`).
  `SaleSuccessPage` now uses the real workspace name instead of the hard-coded `Business`.
- **Receipts cleanup:** the legacy `sales/domain/receipt.dart` text builder is deleted;
  `ReceiptPrinterService.saleToReceipt` is the single offline/just-closed path to a ticket
  (it also fixes `isVoided` being hard-coded to `false`), and the QR payload now carries the
  tenant currency.
- **Roles:** new tenant registration now provisions protected `Administrator` and `Staff` roles
  together with editable `Manager`, `Cashier`, `Inventory Officer`, and `Accountant` starter
  roles. The owner receives only `Administrator`; starter roles can be adjusted or deleted.
- **Roles UI:** starter roles are identified as editable defaults, system-role permission edits
  show a lockout warning, and the permission picker is grouped by business area.

## v0.7.0 — 2026-08-16 — Slice 6: Sales POS backend

- **Domain:** `Sale` aggregate (`SaleLine`, `SalePayment`, `SaleStatus`/`SaleSource`/
  `FiscalStatus`/`PaymentMethod`, exact reconciliation + full-payment guard, fiscal
  placeholders written only by the fiscal adapter), `SaleCompletedEvent`, `NumberSequence`
  (`{prefix}-{year}-{sequence:NNN}`, monotonic `Allocate`, advisory-locked), and
  `SaleStockDebitService` (row-lock, check-all-then-apply, whole-sale rejection,
  `DebitsStock:false` service path).
- **Tax Engine:** `TaxCategory`/`TaxRegime`/`TaxRule`/`TaxExemption` entities,
  `ITaxEngine` port + `TaxService` (temporal rule matching, category fallback, exemption
  overlay, strategy dispatch), core `DefaultPercentageTaxStrategy` (`Simple`), and
  `TZ_DUAL_VAT` dual-VAT A/B plugin under `BusinessOS.Localizations.Tanzania.Tax` —
  selection is data-driven via `TaxRule.CalculationStrategyKey` (core never references a
  country).
- **Catalog/tenant wiring:** `Products.TaxCategoryId`, `Tenants.CountryCode`
  (`UpdateOrganizationCommand` requires `^[A-Z]{2}$`, tenant default `TZ`), migrations
  `AddProductTaxCategory`/`AddTenantCountryCode`/`AddSalesAndTax`, tax catalog seeded
  get-or-create.
- **Application:** `CreateSaleCommand` (branch/warehouse resolution, per-line
  `ResolvePricesAsync` + `PriceResolver`, `TaxEngine`, totals = Σ line taxes,
  payments-cover-total, number allocated then stock debit, **idempotent `ClientSaleId`
  replay**), `GetSaleQuery`/`ListSalesQuery` (branch/date-range/status/search filter,
  paged), DTOs + mappers, FluentValidation validators, `ITaxEngine → TaxService` DI
  registration.
- **API + events:** `SalesEndpoints` — `POST/GET /api/v1/sales`, `GET /api/v1/sales/{id}`,
  `RequirePermission(Sales.Create/View)`; POST honors an `Idempotency-Key` header
  (authoritative `ClientSaleId` when parseable); `SalesActivityFeedHandler` consumes
  `SaleCompletedEvent`; outbox writer stamps `OutboxMessage.TenantId`.
- **Tests:** 357 passing (14 new integration tests: happy path, no-price 400,
  insufficient-stock 400 with full rollback, mixed A/C cart, electronic w/o TIN → rate B,
  service line skips stock, replay idempotency, header-vs-body key precedence, split
  cash + M-Pesa, tenant isolation, 403 viewer, paged list). Integration run exposed and
  fixed four real defects: missing `ITaxEngine` DI registration, `Sale.Reconcile`
  cross-check incompatible with rate-B totals, auto-selected warehouse loading without
  `Include(Locations)`, and un-stamped outbox `TenantId`.
- **Scope:** core backend slice only — void/returns (6c-void), fiscal adapters, and the
  Flutter offline POS are tracked follow-ups.

## v0.6.0 — 2026-08-15 — Slice 5: Operational Dashboard (backend slice)

- **Ports + repository:** `IDashboardRepository` in `Application/Ports` with snapshot records
  (`DashboardCatalogSnapshot`, `DashboardInventorySnapshot`, `DashboardPricingSnapshot`,
  `DashboardOrganizationSnapshot`, `DashboardSnapshot`) + `LowStockItem`/`RecentActivityItem`;
  EF `DashboardRepository` in `Infrastructure/Repositories` — tenant-scoped GROUP BY/SUM
  aggregations over existing catalog/inventory/pricing/organization tables, `Users` join for
  actor emails, newest-first ordering; registered in DI.
- **Application:** `Features/Dashboard` DTOs (`DashboardSummaryDto`, `DashboardLowStockDto`,
  `DashboardActivityDto`), mapper, and queries `GetDashboardSummaryQuery`,
  `GetLowStockQuery` (default `maxQuantity` 0, `limit` 20), `GetRecentActivityQuery`
  (default `limit` 20) with FluentValidation (`limit` 1..100, `maxQuantity` >= 0).
- **API:** `DashboardEndpoints` — `GET /api/v1/dashboard/summary`,
  `GET /api/v1/dashboard/low-stock?maxQuantity=&limit=`,
  `GET /api/v1/dashboard/recent-activity?limit=`, all
  `RequirePermission(PermissionNames.DashboardView)`-gated; registered in `Program.cs`.
- **KPIs:** catalog (products by status/type, variants, categories), inventory (warehouses,
  stock lines, on-hand units, stocked/zero-stock products, movements), pricing (price lists,
  default list name, active-price products, branch overrides), organization (branches, users,
  roles).
- **Scope:** read-only slice — no domain changes, no migrations, no events, no audit writes;
  revenue/VAT/top-sellers KPIs deferred until the Sales domain exists (spec "Future
  improvements").
- **Tests:** 236 passing (6 new unit + 6 new integration) — summary KPIs match a seeded
  tenant, low-stock ordering + threshold + limit validation, recent-activity newest-first with
  actor email, 403 for a `Dashboard.View`-less role, tenant isolation, and no audit rows
  written by dashboard reads.

### Docs
- Spec `specs/dashboard.md` implemented & verified; tasks `tasks/dashboard/TASKS.md` 001–004
  ticked; roadmap item 5 marked `[x] backend slice`; readiness report Slice 5 verification +
  release checkpoint; `memory/project.md` updated; final `dotnet build --warnaserror`,
  `dotnet format` and full test run clean. **Slice 5 — Operational Dashboard:
  release-ready.** Recorded as changelog v0.6.0 (no git tag).

## v0.5.0 — 2026-08-14 — Slice 3: Product & Inventory Foundation (backend slice)

### 3a — Product Catalog
- **Domain (`Domain/Catalog`):** `Product` aggregate (`Create` factory, `UpdateProfile`,
  `UpdateIdentifiers` with `NormalizeIdentifier` trim, `SetStatus`, replace-all
  `SetVariants`); `ProductVariant` child (internal `Assign`/`Rename`, no-op replace
  detection); `ProductCategory` (optional `ParentId`, cycle guard in application layer),
  `Brand`, `UnitOfMeasure`; enums `ProductType` (`Product`/`Service`) and `ProductStatus`
  (`Draft`/`Active`/`Inactive`, sellable = `Active`); product-level sku/barcode must be null
  when variants exist; variant names unique (trim, case-sensitive); 4 domain events
  (`ProductCreatedEvent`, `ProductUpdatedEvent`, `ProductStatusChangedEvent`,
  `ProductVariantsChangedEvent`). New permissions `Products.View/Create/Update/Delete`,
  `Categories.View/Manage`, `Brands.View/Manage`, `Units.View/Manage` (auto-granted to admin
  roles by the seeder).
- **Persistence:** `ProductCategories`, `Brands`, `UnitsOfMeasure`, `Products`,
  `ProductVariants` tables via migration `20260813_AddProductInventoryAndPricing`; partial
  unique indexes on tenant+sku/barcode (products and variants); category/brand/uom
  `Restrict` FKs, product→variants `Cascade`.
- **Repositories:** `IProductRepository` (tenant-scoped `GetByIdAsync` with variants,
  `GetBySkuAsync`/`GetByBarcodeAsync`, `ListAsync`/`CountAsync` with
  `ProductListFilter` search/category/brand/type/status, `AddAsync`,
  `VariantSkuExistsAsync`/`VariantBarcodeExistsAsync`), `ICategoryRepository`,
  `IBrandRepository`, `IUnitOfMeasureRepository`.
- **Application:** `Features/Products` commands (create/update/status/delete/variants) +
  queries (list/get/get-variants) with validators and `ProductReferenceGuard`; `Features/Catalog`
  reference-data commands/queries for categories/brands/units with duplicate-name → `Conflict`
  and category cycle (self/ancestor) → `Validation`; mutations run inside a per-tenant
  transaction advisory lock.
- **API:** `CatalogEndpoints` (products group: list/get/create/update/status/delete/
  variants) + `ReferenceDataEndpoints` (categories/brands/units), all
  `RequirePermission`-gated; `DELETE /products/{id}` is a soft delete (status → `Inactive`).
- **Events:** `CatalogActivityFeedHandler` consumes the 4 product domain events (outbox-backed
  activity feed).
- **Tests:** 181 passing (unit + integration) — product invariants, category cycle guard,
  CRUD + status, duplicate sku → `Conflict`, variant round-trip with stable ids, reference
  data, 403 for `Products.View`-only role, tenant isolation, audit rows, outbox dispatch.

### 3b — Inventory Foundation
- **Domain (`Domain/Inventory`):** `Warehouse` aggregate with uppercase code normalization,
  default `MAIN` stock location, replace-all location management, activate/deactivate lifecycle,
  and warehouse domain events; immutable `StockMovement` ledger with `OpeningStock` movement type;
  `StockBalance` running quantity guardrails. Added `Warehouses.*` and `Inventory.*`
  permissions.
- **Persistence:** `Warehouses`, `StockLocations`, `StockBalances`, and `StockMovements` tables
  via migration `20260814051054_AddInventoryWarehousesAndStock`; tenant-scoped warehouse code
  uniqueness; warehouse-location uniqueness; functional stock-balance uniqueness for nullable
  variants; ledger indexes for stock history.
- **Repositories/Application/API:** tenant-scoped warehouse and stock repositories, row locking for
  balances, per-tenant advisory locks around inventory mutations, warehouse commands/queries,
  opening-stock recording, stock balance/movement list queries, and `InventoryEndpoints` under
  `/api/v1/warehouses` and `/api/v1/inventory/*` with permission gates.
- **Events:** `InventoryActivityFeedHandler` records warehouse lifecycle and stock ledger activity
  through the existing outbox-backed notification pipeline.
- **Tests:** 205 passing (unit + integration) — warehouse invariants, stock ledger math and
  no-negative guardrails, warehouse CRUD/status/locations, opening stock balance+movement,
  duplicate opening conflict, variant validation, tenant isolation, permissions, audit rows, and
  outbox events.

### 3c — Pricing Engine
- **Domain (`Domain/Pricing`):** `PriceList` aggregate (per-tenant, unique name, at most one
  `IsDefault` per tenant, effective window, replace-all `SetPrices`), `ProductPrice` child
  (key = product/variant/branch/price-type, price > 0, minQuantity ≥ 1, window guard), pure
  `PriceResolver` (branch override before all-branch base, price-type filter, highest qualifying
  `MinQuantity`, latest `EffectiveFrom` tie-break, no price → no price), `ResolvedPrice`;
  events `PriceListCreatedEvent`/`PriceListUpdatedEvent`/`ProductPricesChangedEvent`. New
  permissions `Pricing.View/Manage` (auto-granted to admin roles by the seeder).
- **Persistence:** `PriceLists` + `ProductPrices` tables via migration
  `20260814113222_AddPricingPriceLists` (unique `(TenantId, Name)`, partial unique on default,
  functional unique price key with `COALESCE` on nullable variant/branch).
- **Repositories:** `IPriceListRepository` (`GetByIdAsync` with `includePrices`, `GetByNameAsync`,
  `GetDefaultAsync`, `ListAsync`, `ResolvePricesAsync`) + `IProductPriceRepository`
  (`ListAsync`, `UpsertManyAsync`, `ResolveAsync` with DB-side resolution filter).
- **Application:** `Features/Pricing` commands (`CreatePriceListCommand`,
  `UpdatePriceListCommand`, `SetProductPricesCommand` bulk upsert) + queries
  (`ListPriceListsQuery`, `GetPriceListQuery`, `GetPriceListPricesQuery`, `ResolvePriceQuery`)
  with FluentValidation (currency ISO-4217 case-insensitive, price > 0, minQuantity ≥ 1,
  effective window), reference guards (product/variant consistency, tenant branch), duplicate
  name/default → `Conflict`; mutations run inside the per-tenant transaction advisory lock.
- **API:** `PricingEndpoints` — `/api/v1/price-lists` (list/create/get/update + prices get/put)
  and `/api/v1/pricing/resolve`, all `RequirePermission(Pricing.View / Pricing.Manage)`-gated.
- **Events:** `PricingActivityFeedHandler` consumes the 3 pricing domain events (outbox-backed
  activity feed).
- **Tests:** 224 passing (unit + integration) — price resolver (branch override, price type,
  min-quantity, effective dates, tie-break, no-price), price-list CRUD + duplicate default →
  `Conflict`, bulk upsert round-trip, resolve endpoint (base/branch/wholesale/no-price/variant
  consistency), 403 for `Pricing.View`-only role, tenant isolation, audit rows, outbox dispatch.
- **Fix (domain, found by 3c integration tests):** `ProductPrice.Assign` now keeps the default
  key for added children (was `Guid.NewGuid()`), matching `StockLocation.Assign` — the
  documented EF child-state pitfall (client Guid keys in added children must be default so EF
  treats them as Added, not Modified; the old code produced `DbUpdateConcurrencyException`).

### 3d — Docs & verification
- **Release checkpoint:** roadmap item 4 marked `[x] backend slice`; `docs/PlatformReadinessReport.md`
  gains the Slice 3 verification + release-ready checkpoint (224/224 tests, 7 migrations applied,
  all endpoints permission-gated); spec `specs/products-inventory.md` marked implemented &
  verified across 3a–3d; `memory/project.md` updated; final `dotnet build --warnaserror`,
  `dotnet format` and full test run clean. Recorded as changelog v0.5.0 (no git tag).

### Docs
- Spec `specs/products-inventory.md` implemented & verified (3a–3d); tasks
  `tasks/products-inventory/TASKS.md` 001–029 ticked; roadmap item 4 `[x] backend slice`;
  readiness report release checkpoint; `memory/project.md` updated. **Slice 3 — Product &
  Inventory Foundation: release-ready.**

## v0.4.0 — 2026-08-13 — Phase 1: Users, Roles & Permissions (backend slice)

### Users, Roles & Permissions
- **Domain:** `UserBranch` entity (`AssignBranches` invariants: single default, default ∈
  assigned, duplicate rejection, stale-child replacement); `User.SetRoles` no-op on
  identical sets; `Role.Description` + `Clone` + `Rename`/`Delete` guard helpers; new
  identity domain events (`UserCreatedEvent`, `UserProfileUpdatedEvent`,
  `UserRolesChangedEvent`, `UserStatusChangedEvent`, `UserBranchesChangedEvent`,
  `RoleCreatedEvent`, `RoleUpdatedEvent`, `RolePermissionsChangedEvent`,
  `RoleDeletedEvent`); `SystemRoles.Administrator` constant.
- **Persistence:** `UserBranches` table (unique `(UserId, BranchId)` + partial unique index
  on default per user), `Roles.Description` column + unique `(TenantId, Name)` index via
  migration `20260806_AddUserRoleAndBranchManagement`; `UserBranch` managed through the
  `User` aggregate (no child repository); `IPermissionRepository` returns the **tracked**
  catalog so `Role.Grant` attaches without re-inserting it.
- **Repositories:** `IUserRepository` tenant-scoped `GetByIdAsync(tenantId, id)`,
  `GetByIdWithRolesAsync`, `ListAsync(tenantId, page, pageSize)`, `CountAsync`,
  `CountActiveAdministratorsAsync(tenantId, excludeUserId)`; `IRoleRepository`
  `GetByIdAsync(tenantId, id)`, `GetByNameAsync`, `ListAsync(tenantId)`,
  `GetPermissionsAsync(tenantId, roleId)`, `RemoveAsync`; new `IPermissionRepository`
  (`ListAsync`, `GetByNameAsync`, `ResolveByNamesAsync`).
- **Application:** `Features/Users` (list/get/create/update/status/delete, roles, branches)
  and `Features/Roles` (list/get/create/update/delete, permissions) with validators,
  DTOs, mappers, and `UserAdminGuard` (self + last-active-Administrator protection).
  Admin-removing ops run inside a per-tenant PostgreSQL transaction advisory lock (same DB
  transaction as the mutation) — the concurrent last-admin race has a passing integration
  test proving exactly one succeeds. Users are **soft-deleted** (deactivate + revoke
  refresh-token families); deactivation keeps refresh tokens active.
- **API:** `IdentityEndpoints` — users, roles and permission-catalog routes under
  `/api/v1`, gated with `RequirePermission(Users.* / Roles.*)`.
- **Events:** `IdentityActivityFeedHandler` (outbox-backed activity feed) registered in the
  notification engine.
- **Tests:** 154 passing (unit + integration) — branch-assignment invariants, last-admin
  guard, role grant idempotency, user/role CRUD + status, duplicate email/role → Conflict,
  self + last-admin protection, permission round-trip, tenant isolation, 403 for
  `Users.View`-only role, audit rows, outbox dispatch.

### Docs
- Spec `specs/users-roles-permissions.md` implemented & verified; tasks
  `tasks/users-roles-permissions/TASKS.md` all ticked; roadmap item 3 marked
  `[x] backend slice` + Slice 3 (Product & Inventory Foundation) outlined as the proposed
  next slice; `memory/project.md` and readiness report updated.
- **Known tech debt:** Swagger UI shows no Authorize button — the top-level OpenAPI `security`
  requirement serializes as `{}` (Bearer scheme IS declared; runtime 401/403 enforcement is
  proven). Platform-wide Swagger config redesign deferred.

## v0.3.0 — 2026-08-06 — Phase 1: Organizations & Branches (backend slice)

### Organizations & Branches
- **Domain:** `Tenant` extended with organization profile (`ContactEmail`, `ContactPhone`,
  `Address`, `Currency` default `TZS`, `TaxId`, `UpdateProfile`); new `Branch` aggregate
  (`Create`, `UpdateProfile`, `Activate`/`Deactivate`, code normalization to uppercase);
  events `BranchCreatedEvent`/`BranchUpdatedEvent`/`BranchStatusChangedEvent`; new
  `PermissionNames`: `Organizations.View/Manage`, `Branches.View/Create/Update/Delete`.
- **Persistence:** `Branch` table (unique index `(TenantId, Code)`) + tenant profile columns
  via migration `20260805202634_AddOrganizationProfileAndBranches`; `IBranchRepository` +
  `BranchRepository`; restored the previously-uncommitted `20260805051819_AddUserLockout`
  migration (test DB already had it; dev DB was missing lockout columns) and consolidated
  migrations under `Infrastructure/Migrations/`.
- **Application:** `Features/Organizations` (GET/PUT) and `Features/Branches` (list/get/
  create/update/status) with validators, `PagedResult<T>`, tenant-scoped repositories.
- **Registration + seeder:** `RegisterUserCommand` auto-creates the default `Head Office`
  (`HQ`) branch from `Payments:Currency`; `DatabaseSeeder` re-grants new permissions to
  existing system `Administrator` roles and seeds the demo tenant's default branch.
- **API:** `OrganizationEndpoints` — `GET/PUT /api/v1/organization`,
  `GET/POST /api/v1/branches`, `GET/PUT /api/v1/branches/{id}`,
  `PATCH /api/v1/branches/{id}/status`, all gated with `RequirePermission`
  (readiness gap #3 closed).
- **Events:** `BranchActivityFeedHandler` (outbox-backed activity feed) registered in the
  notification engine.
- **Tests:** 62 passing (unit + integration) — register default branch, CRUD + status,
  duplicate code → Conflict, 403 for `Branches.View`-only role, tenant isolation (404),
  audit rows, outbox dispatch of `BranchCreatedEvent`.

### Docs
- Spec `specs/organizations-branches.md` marked implemented; tasks
  `tasks/organizations-branches/TASKS.md` all ticked; readiness report gap #3 closed.

## v0.2.0 — 2026-08-05 — Phase 0.5 Platform Hardening

### Platform
- **Exception handling:** `GlobalExceptionHandler` → RFC7807 ProblemDetails with
  trace/correlation ids.
- **Observability:** `CorrelationIdMiddleware` (`X-Correlation-ID`), `UserContextMiddleware`
  (`RequestContext`), Serilog request logging (UserId/TenantId/CorrelationId/Ip).
- **Security:** security headers (nosniff/DENY/no-referrer/permissions-policy), rate limiting
  (auth + global policies), account lockout (`AddUserLockout` migration), `revoke` endpoint,
  `TokenCleanupService`, CORS.
- **Validation:** FluentValidation structured per-field errors (`ValidationProblemDetails`).
- **API versioning:** URL-segment `v1`, Swagger v1 + Bearer; all routes now `/api/v1/*`.
- **Configuration:** options-pattern classes in `Shared/Configuration/PlatformOptions.cs`
  (Database/Redis/Smtp/Sms/Storage/Payments/Cors/RateLimiting/Security).
- **Storage engine:** `IFileStorage` with `LocalFileStorage` (path-traversal safe) and
  `S3FileStorage`; `AddFileStorage`.
- **Messaging/jobs/events:** outbox-backed `IJobQueue`, `SendEmail/Sms/Push/WhatsAppJob`,
  `JobExecutionService`, `ScheduledJobRunner`, `AddJobQueue`/`AddBackgroundJobs`.
- **Notification engine:** channel-based `INotificationService` (Email/SMS/Push/WhatsApp),
  welcome-email + analytics + activity-feed handlers for `UserRegisteredEvent`.
- **Permission engine:** `IPermissionService` + `PermissionCacheService` (5-min TTL),
  `RequirePermission`/`RequirePermissionAttribute`.
- **Audit engine:** `AuditBehavior` in the MediatR pipeline — every successful non-`Get*`
  command writes a redacted audit log (passwords/tokens never persisted).
- **Health/CI:** `/health/live` + `/health/ready` (DB/Redis/storage/worker heartbeats),
  GitHub Actions CI (build `--warnaserror`, `dotnet format`, unit tests, coverage),
  `Directory.Build.props` + `.editorconfig`.
- **Tests:** 45 passing (34 unit + 11 integration) incl. storage, jobs, notifications,
  permission cache, audit behavior.

### Docs
- `MASTER_ARCHITECTURE.md` (single source of truth) added at repo root.
- `memory/project.md` brought up to date. CI comment corrected.

## v0.1.0 — 2026-08-05 — Phase 0 foundation (in progress)

### Backend
- Created modular-monolith solution `backend/BusinessOS.slnx` (Shared, Domain, Application,
  Infrastructure, API, Workers, Notifications, Modules.Sales).
- Domain kernel: `Result<T>`/`Error`, `Entity`/`AggregateRoot`, `IDomainEvent`.
- Platform domain stubs: `Tenant`, `Role`, `Permission`, `PermissionNames`, `UserRegisteredEvent`.
- **Superseded by v0.2.0:** JWT auth, EF Core + Postgres, seed, outbox, audit — all now real.
