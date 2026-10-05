# Project Memory — read before every task

## business.md — who we build for

- **Target users:** small shops, retail, wholesale, manufacturing, schools, hospitals,
  hotels, agriculture (East Africa first: Tanzania, Kenya, Uganda).
- **Buyer pain:** offline POS, mobile money, local tax (TRA/KRA/URSB), Swahili UI, low
  bandwidth, simple onboarding (< 10 min), per-branch pricing.
- **Positioning:** the African alternative to Odoo / Zoho / SAP B1 / Dynamics 365. Platform,
  not a single ERP.

## architecture.md — current state (2026-08-15)

- Modular monolith: Shared / Domain / Application / Infrastructure / API / Workers /
  Notifications / Modules.*. Solution `backend/BusinessOS.slnx` (includes the tests project).
- Event-driven + outbox; CQRS (MediatR); UUID PKs; shared-DB tenancy with `tenant_id`.
- **Implemented:** JWT auth (register/login/refresh/revoke) + BCrypt + account lockout;
  RBAC with permission cache; audit pipeline (redacted); notification engine (email/SMS/
  push/WhatsApp channels + welcome email + analytics/activity handlers); outbox-backed job
  queue (`SendEmailJob` etc.) + scheduled jobs; local/S3 file storage; health endpoints
  (`/health`, `/health/live`, `/health/ready`); API versioning (v1) + Swagger; exception
  handler (ProblemDetails), correlation/security-headers middleware, rate limiting, CORS,
  structured Serilog logging; options-pattern configuration. Build is clean
  (`--warnaserror`, 0 warnings); `dotnet format` passes.
- **Phase 1 slice 1 (Organizations & Branches, done 2026-08-06):** `Tenant` organization
  profile (contact/address/currency/taxId); `Branch` aggregate with code normalization;
  tenant-scoped `IBranchRepository`; `Features/Organizations` + `Features/Branches`
  commands/queries with validators + `PagedResult<T>`; endpoints
  `GET/PUT /api/v1/organization`, `GET/POST /api/v1/branches`,
  `GET/PUT /api/v1/branches/{id}`, `PATCH /api/v1/branches/{id}/status` — all gated with
  `RequirePermission` (readiness gap #3 closed); registration auto-creates the default
  `HQ` branch; seeder re-grants new permissions to existing admin roles; outbox-backed
  `BranchActivityFeedHandler`; 62 tests pass (unit + integration against real Postgres).
- **Phase 1 slice 2a (Users, Roles & Permissions), done 2026-08-13 (tasks 001–009):**
  domain hardening (`UserBranch` invariants: single default, duplicate-rejection, stale
  replacement; `User.SetRoles` no-op on identical; `SystemRoles.Administrator` constant);
  migration `20260806_AddUserRoleAndBranchManagement` (UserBranches table + Roles Description +
  unique `(TenantId, Name)`); tenant-scoped repositories (`IUserRepository`
  `GetByIdAsync/GetByIdWithRolesAsync/ListAsync/CountAsync/CountActiveAdministratorsAsync/
  RevokeAllForUserAsync/ListByIdsAsync`, `IRoleRepository`
  `GetByIdAsync/GetByNameAsync/ListAsync/GetPermissionsAsync/GetManyByIdsAsync/RemoveAsync`,
  new `IPermissionRepository` `ListAsync/GetByNameAsync/ResolveByNamesAsync`); application
  layer `Features/Users` (6 commands, 3 queries) + `Features/Roles` (4 commands, 4 queries)
  with validators/DTOs/mappers/`UserAdminGuard`; `IdentityEndpoints` — 17 endpoints under
  `/api/v1/users`, `/api/v1/roles`, `/api/v1/permissions`, all `RequirePermission`-gated
  (Users.View/Create/Update/Delete, Roles.View/Manage); `IdentityActivityFeedHandler` consumes
  the 9 identity domain events. Guardrails: users **deactivated never hard-deleted** (DELETE =
  deactivate + revoke refresh-token families); self-deactivate/self-delete → Conflict; last
  active `Administrator` protected (`UserAdminGuard`, lockout prevention) enforced inside a
  per-tenant Postgres transaction advisory lock (`pg_advisory_xact_lock`, same DB transaction
  as the mutation); system roles non-renamable/non-deletable but permission-adjustable
  (ADR-0001); role deletion removes grants but never users. Key decisions: `UserBranch` is
  managed only through the `User` aggregate (no child repo); `IPermissionRepository` returns
  **tracked** catalog entities so grants attach without re-inserting the catalog; EF
  child-state pitfall (client Guid keys in added children must use default keys so EF treats
  them as Added, not Modified). **154 tests pass** (unit + integration incl. concurrent
  last-admin race + audit rows for every mutation); build clean (`--warnaserror`),
  `dotnet format` clean. Changelog v0.4.0.
- Key docs: `MASTER_ARCHITECTURE.md` (single source of truth), `docs/ArchitectureRules.md`,
  `docs/Architecture.md`, `docs/roadmap.md`, `specs/organizations-branches.md`,
  `specs/users-roles-permissions.md`.

- **Phase 1 slice 3a (Product Catalog), done 2026-08-13 (tasks 001–009):** `Domain/Catalog`
  aggregates `Product` (variants via replace-all `SetVariants`, product-level sku/barcode
  null when variants exist, `NormalizeIdentifier` trim, sellable = status `Active`),
  `ProductCategory` (optional parent, cycle guard in app layer), `Brand`, `UnitOfMeasure`;
  4 product domain events; new permissions `Products.*`, `Categories.*`, `Brands.*`,
  `Units.*`; migration `20260813_AddProductInventoryAndPricing` (5 catalog tables, partial
  unique tenant+sku/barcode); repositories `IProductRepository` (+filtered
  `ListAsync`/`CountAsync`, variant sku/barcode existence checks) +
  `ICategoryRepository`/`IBrandRepository`/`IUnitOfMeasureRepository`; application
  `Features/Products` (6 commands incl. `SetProductVariantsCommand`, 3 queries) +
  `Features/Catalog` (categories/brands/units commands+queries, duplicate name →
  `Conflict`, cycle → `Validation`); API `CatalogEndpoints` + `ReferenceDataEndpoints` all
  `RequirePermission`-gated; `DELETE /products/{id}` = soft delete (status `Inactive`);
  `CatalogActivityFeedHandler` consumes the product events. 181 tests pass (unit +
  integration). Spec sub-slice 3a marked implemented & verified; 3b Inventory Foundation now
  implemented in the following entry; 3c Pricing Engine pending.

- **Phase 1 slice 3b (Inventory Foundation), done 2026-08-14 (tasks 010–020):** 3a errata fixed
  cross-table product/variant SKU and barcode uniqueness in application commands; new
  `Domain/Inventory` aggregate `Warehouse` with default `MAIN` `StockLocation`, uppercase code
  normalization, replace-all locations, soft delete via deactivate, and warehouse lifecycle
  events; immutable `StockMovement` ledger (`OpeningStock` only in 3b, signed quantity delta,
  effective/created timestamps, opening-stock events) plus `StockBalance` running quantity with
  no-negative guard. New permissions `Warehouses.View/Create/Update/Delete` and
  `Inventory.View/Manage`. Migration `20260814051054_AddInventoryWarehousesAndStock` adds
  `Warehouses`, `StockLocations`, `StockBalances`, `StockMovements`; stock-balance uniqueness
  uses a COALESCE functional unique index to handle null `VariantId`. New warehouse and stock
  repositories include tenant-scoped list/count APIs, `GetBalanceWithLockAsync` using Postgres
  `FOR UPDATE`, and movement persistence. Application/API layer adds warehouse CRUD/status/
  locations, opening-stock recording, stock balance and movement queries, and endpoints under
  `/api/v1/warehouses` and `/api/v1/inventory/*`, all permission-gated. Opening stock is
  auditable and creates both ledger movement and derived balance in the same mutation path.
  `InventoryActivityFeedHandler` consumes warehouse and stock events. 205 tests pass (unit +
  integration). Spec sub-slice 3b marked implemented & verified; 3c Pricing Engine pending.

- **Phase 1 slice 3c (Pricing Engine), done 2026-08-15 (tasks 021–028):** new
  `Domain/Pricing` aggregate `PriceList` (per-tenant unique name, at most one `IsDefault` per
  tenant, effective window, replace-all `SetPrices`) + child `ProductPrice` (price key =
  product/variant/branch/price-type, price > 0, minQuantity ≥ 1, window guard), pure
  `PriceResolver` (`ResolvedPrice`: branch override beats all-branch base, price-type filter,
  highest qualifying min-quantity, latest `EffectiveFrom` tie-break, inactive/out-of-window/
  no-price → null), events `PriceListCreatedEvent`/`PriceListUpdatedEvent`/
  `ProductPricesChangedEvent`; permissions `Pricing.View/Manage`; migration
  `20260814113222_AddPricingPriceLists` (`PriceLists` + `ProductPrices`, functional unique
  price key with COALESCE on nullable variant/branch); repositories `IPriceListRepository`
  (`GetByIdAsync` with `includePrices`, `GetByNameAsync`, `GetDefaultAsync`, `ListAsync`,
  `ResolvePricesAsync`) + `IProductPriceRepository` (`ListAsync`, `UpsertManyAsync`,
  `ResolveAsync` DB-side filter); application `Features/Pricing` (commands
  `CreatePriceListCommand`/`UpdatePriceListCommand`/`SetProductPricesCommand` bulk upsert,
  queries list/get/get-prices/resolve) with FluentValidation (ISO-4217 currency
  case-insensitive, price > 0, minQuantity ≥ 1) and reference guards (product/variant
  consistency, tenant branch); duplicate name/default → `Conflict`; API `PricingEndpoints`
  `/api/v1/price-lists` + `/api/v1/pricing/resolve`, permission-gated; `PricingActivityFeedHandler`
  consumes the 3 pricing events. **Erratum found by 3c integration tests:** `ProductPrice.Assign`
  pre-generated child Guids → `DbUpdateConcurrencyException` on second bulk upsert; fixed to
  keep default keys for added children (matches `StockLocation.Assign` and the documented EF
  child-state pitfall). 224 tests pass (unit + integration). Spec sub-slice 3c marked
  implemented & verified.
- **Phase 1 slice 3d (Docs & final verification), done 2026-08-15 (task 029):** roadmap item 4
  marked `[x] backend slice`; `docs/PlatformReadinessReport.md` Slice 3 verification +
  release-ready checkpoint; spec marked implemented & verified (3a–3d); changelog v0.5.0 final
  entry; final build/format/test run clean. **Slice 3 — Product & Inventory Foundation is
  release-ready.** Next: Dashboard aggregates from events, or Sales + Offline POS (uses the
  now-real product/price/stock foundation).
- **Phase 1 slice 5 (Operational Dashboard), done 2026-08-15 (tasks 001–005):** read-only
  backend slice over existing catalog/inventory/pricing/organization tables — no domain
  changes, no migrations, no events, no audit writes. `IDashboardRepository` (+ 3 snapshot
  records + `LowStockItem`/`RecentActivityItem`) in `Application/Ports`, EF `DashboardRepository`
  (tenant-scoped GROUP BY/SUM over existing DbSets, `Users` join for actor emails, newest-first);
  `Features/Dashboard` DTOs + mapper + queries `GetDashboardSummaryQuery`/`GetLowStockQuery`/
  `GetRecentActivityQuery` with FluentValidation (limit 1..100, maxQuantity ≥ 0); API
  `DashboardEndpoints` `GET /api/v1/dashboard/summary`, `/low-stock?maxQuantity=&limit=`,
  `/recent-activity?limit=` — all `RequirePermission(PermissionNames.DashboardView)`. KPIs:
  catalog (products by status/type, variants, categories), inventory (warehouses, stock lines,
  on-hand units, stocked/zero-stock products, movements), pricing (lists, default name, active
  price products, branch overrides), organization (branches, users, roles). Revenue/VAT/top-
  sellers KPIs deferred until the Sales domain exists (spec "Future improvements"). Tests:
  6 unit + 6 integration (summary KPIs, low-stock ordering/threshold, recent-activity
  newest-first with actor email, 403 for Dashboard.View-less role, tenant isolation, no audit
  rows on reads). Full suite 236/236 passing; changelog v0.6.0. Flutter dashboard screens are
  the follow-up.
- **Phase 1 slice 6 (Sales POS backend), in progress (tasks 004–013 done 2026-08-16):** the
  active slice (6a core + 6b application/API/events + 6c tests/docs). See
  `tasks/sales-pos/TASKS.md`. **Tax/VAT strategy (DEFERRED to future addon):** core sales
  flow works without tax calculation; tax engine is a stub returning NONE/0. Country-specific
  tax rules (TRA dual-VAT etc.) will be implemented later as an addon for users who need it.
  Current: `DefaultPercentageTaxStrategy` (simple fallback); `TzDualVatTaxStrategy` exists but
  Calculate is a stub. No tax-rules read API exposed to client.
  Done: 004 `Products.TaxCategoryId` + `Tenants.CountryCode` (+ migration `AddProductTaxCategory`/
  `AddTenantCountryCode`, `ProductReferenceGuard`, `ITaxRuleRepository` EF impl + DI); 005
  `UpdateOrganizationCommand` requires `CountryCode` (`^[A-Z]{2}$`, tenant default `TZ`);
  002a localization reorg (`Localizations/BusinessOS.Localizations.csproj`,
  `AddLocalizations()`); 006 `Sale` aggregate (`SaleLine`, `SalePayment`, enums
  `SaleStatus/SaleSource/FiscalStatus/PaymentMethod`, `SaleCompletedEvent`, exact
  reconciliation + full payment, fiscal placeholders written only by the fiscal adapter); 007
  `NumberSequence` (pattern `{prefix}-{year}-{sequence:NNN}`, monotonic `Allocate`, manual
  placeholder parsing); 008 `SaleStockDebitService` (row-lock, check-all-then-apply,
  whole-sale rejection, `DebitsStock:false` skip, movement refs `Sale`/SaleId); 009 migration
  `20260816061229_AddSalesAndTax` (Sales/SaleLines/SalePayments/NumberSequences, unique
  `(TenantId, ClientSaleId)` + partial unique `(TenantId, Number)`, cascade FKs) applied to
  dev DB; 010 repositories `ISaleRepository` (+`SaleListFilter`) and
  `INumberSequenceRepository.AllocateAsync` (advisory-lock + `SELECT ... FOR UPDATE`,
  get-or-create via `NumberSequence.CreateSaleSequence`) + EF impls + DI registration; 011
  `CreateSaleCommand` + handler (branch/warehouse resolution — explicit warehouse must belong
  to branch else `Validation`, default = branch's first warehouse; price via
  `ResolvePricesAsync` + `PriceResolver` (Retail); per-line tax item + `TaxEngine`; totals =
  Σ line taxes, `TotalAmount` = Σ(lineTotal − disc); payments must fully cover; number
  allocated then `SaleStockDebitService`; persist + event) + `CreateSaleCommandValidator`
  (`EffectiveAt ≤ UtcNow+5min` skew, lines/payments non-empty, line qty ≥ 1, discount ≥ 0) +
  `SalesDtos` + `SalesMappers` (customer nulled when Name/Tin/IsVatRegistered all null) +
  **idempotent `ClientSaleId` replay** (existing sale returned before any side work). Default
  tax category `VAT_STANDARD`; money 2-dp `MidpointRounding.AwayFromZero`. Unit tests: +14
  command (happy path, replay, no-price, payments-below-total, non-active, branch-not-found,
  service line skips stock, discount applies/caps, split payment, no-cashier, wrong-branch
  warehouse, insufficient stock zero-movements, variant-without-variant) + 7 validator
  (future-skew, empty lines, fractional qty, no payments, bad source, negative discount).
  Full suite 331/331 passing, build `--warnaserror` clean. Integration coverage lands in
  014/015. 012 queries `GetSaleQuery`/`ListSalesQuery` (branch/date-range/status/search
  `SaleListFilter`, paged `PagedResult<SaleDto>`, reuses 011 DTOs/mappers; not-found → 404)
  + `GetSaleQueryValidator`/`ListSalesQueryValidator` (page ≥ 1, pageSize 1..100,
  FromDate ≤ ToDate); unit tests +10 (suite 341/341). 013 `SalesEndpoints` `POST/GET
  `/api/v1/sales` + `GET /{id}` (`Sales.Create`/`Sales.View`) + `Program.cs` registration +
  `SalesActivityFeedHandler` (`SaleCompletedEvent`); POST honors `Idempotency-Key` header
  (authoritative `ClientSaleId` when parseable); spec contract `customer { name?, phone?,
  tin? }` threaded through (`CustomerPhone` → `Sale.BuyerMobile`, `SaleCustomerDto.Phone`);
  unit tests +2 customer snapshot (suite 343/343). **Next:** 014 offline contract,
  015 integration suite, 016 docs + commit.
- **014/015 offline contract + integration suite, done 2026-08-16:** 14 integration tests
  (`SalesOfflineContractTests` + `SalesEndpointsTests`, real API + Postgres) added and green —
  full suite 357/357, build `--warnaserror` clean. Coverage: happy path (stock 5→4, `Sale`
  movement, `S-2026-000001`, audit row, processed outbox), no-price → 400, insufficient stock →
  400 with full rollback (no sale/movement/outbox; retry issues 000001 proving no sequence
  burn), split cash + M-Pesa reconciliation, mixed A/C cart, electronic w/o TIN → rate B
  (98.31/13.56), service line skips stock, replay idempotency (no double stock/number/event),
  `Idempotency-Key` authoritative over body `clientSaleId`, tenant isolation, 403 for viewer.
  **Real defects found & fixed by the integration run:** (1) `ITaxEngine → TaxService` was never
  registered in DI — all sales 500'd (`Unable to resolve service`); added `AddScoped` in
  `Application/DependencyInjection.cs`. (2) `Sale.Reconcile` demanded `totalAmount == subtotal −
  discount`, impossible under dual-VAT rate B (collectable 98.31 < shelf gross 100); relaxed to
  header-as-aggregator (`total == Σ(lineTotal − disc)`), the cross-check removed deliberately.
  (3) `CreateSaleCommandHandler` else-branch (no `warehouseId`) loaded the branch warehouse via
  `ListAsync` (`AsNoTracking`, no `Include(Locations)`) then `ResolveStockLocation` threw
  `Sequence contains no elements`; now re-loads via `GetByIdAsync` (locations included). (4)
  Outbox writer never populated `OutboxMessage.TenantId` (column existed, all rows NULL); now
  stamped from the aggregate's `TenantId` via reflection — the shared-DB integration tests can
  assert tenant-scoped, and tenant-scoped outbox queries work. Test-side fixes only: opening
  stock writes a `StockMovement` (so "exactly 1 movement" → filter `MovementType == Sale`);
  `discountAmount` must be `0m` not `null` (non-nullable `decimal` in
  `CreateSaleLineInput`); insufficient-stock test needs `amountPaid = 200m` (payment check runs
  before stock check); `SetPrices` REPLACES the list's prices (mixed cart must PUT both prices
  in one call); Maize Flour needs opening stock. **Next:** 016 docs + commit.

- **Accounting (Slice 9) complete, done 2026-08-19 (tasks 001–026):** Domain entities
  `Account` (`AccountType` enum: Asset/Liability/Equity/Revenue/Expense), `JournalEntry`
  aggregate with `JournalEntryLine` children, `TenantAccountMapping`, `AccountMappingKeys`
  constants; events `JournalEntryPostedEvent`/`JournalEntryVoidedEvent`; migration
  `AddAccounting` (4 tables + indexes); repositories `IAccountRepository`,
  `IJournalEntryRepository` (with `GetBySourceAsync` for idempotency),
  `ITenantAccountMappingRepository` + EF impls + DI; commands `CreateAccount`,
  `CreateJournalEntry`, `PostJournalEntry`, `VoidJournalEntry`, `CreateTenantAccountMapping`;
  queries `ListAccounts`, `TrialBalance`, `GeneralLedger`, `GetTenantAccountMapping`;
  `IAccountMappingService` for mapping resolution; API endpoints under `/api/v1/accounts`,
  `/api/v1/journal-entries`, `/api/v1/account-mappings`, `/api/v1/accounting-reports`
  (trial-balance, general-ledger) all permission-gated (`AccountingView`/`AccountingCreate`/
  `AccountingApprove`); event consumers `PostSaleJournalEntryHandler`,
  `PostSupplierBillJournalEntryHandler`, `PostSupplierPaymentJournalEntryHandler` (all
  idempotent + mapping-resolved), `PostSaleVoidJournalEntryHandler` (reversing entry),
  `AccountingActivityFeedHandler`; 14 unit tests passing. Integration tests blocked on Postgres.
  **Next:** Reporting+Tax, Workflow v1, Dynamic Forms v1.

- **Reporting+Tax (Slice 10) complete, done 2026-08-19 (tasks 001–012):** `IReportRepository`
  (TaxSummary, SalesSummary, TopProducts queries using explicit Sale→SaleLine joins — no
  navigation properties on domain entities) in `Application/Ports`; EF `ReportRepository` in
  `Infrastructure`; `ICsvExportService` + `CsvExportService` (handles commas/quotes/newlines,
  UTF-8); 4 query handlers (`TaxSummaryQuery`, `SalesSummaryQuery`, `TopProductsQuery`,
  `DashboardTaxKpisQuery`); 3 export command handlers (`ExportTaxSummaryCommand`,
  `ExportSalesSummaryCommand`, `ExportTopProductsCommand`); DTOs in `ReportingDtos.cs`;
  FluentValidation in `ReportingValidators.cs`; new permissions `SalesReportsView` and
  `SalesReportsExport` added to `PermissionNames`; API endpoints under `/api/v1/reports`
  (tax-summary, sales-summary, top-products, dashboard-tax-kpis, export/*) all permission-gated;
  DI registration for `IReportRepository`, `ICsvExportService`; 12 unit tests passing. Integration
  tests blocked on Postgres (same as all other modules). Task 013 (docs + commit) pending.
  **Next:** Workflow v1, Dynamic Forms v1.

- **M2 Email Verification + Onboarding (backend + Flutter), done 2026-08-23:** backend —
  `EmailVerificationCode` domain (crypto-random 6-digit, SHA-256 at rest, TTL, max attempts,
  resend cooldown via `SecurityOptions`), `VerificationCodeService` issuing through the outbox
  `SendEmailJob` pipeline; register no longer returns tokens, login gates unverified accounts
  (`AccountNotVerified` → 403); endpoints `POST /auth/verify-email`,
  `/auth/resend-verification`, `GET /workspaces/mine`, `POST /organization/onboarding`;
  migration `AddEmailVerificationAndOnboarding` (codes table + `Tenants.BusinessType` +
  `Tenants.OnboardingCompletedAt`). Infra fixes surfaced by the new integration suite:
  `BusinessOsApiFactory` env-var injection (JWT validated at Program.cs top level), missing
  `[Migration]` attributes on three hand-written migrations (attribute-only Designer.cs added),
  model snapshot regenerated, **OutboxJobQueue TenantId stamping** (`ITenantScopedEvent`
  marker interface — production bug: 300 orphaned NULL-tenant rows), JournalEntry shadow-FK
  duplicate relationship fix, seeder empty-currency fallback. 535/535 tests green on real
  Postgres; fresh-DB migration chain verified end to end. Flutter — `AuthNeedsVerification`
  controller state + verify/resend repository methods (register → RegisteredUser, no tokens);
  new workspace feature (domain/repo/controller over `/workspaces/mine` + onboarding);
  pure `journeyRedirect` router state machine (splash/login/register/verify/zero-workspace/
  create-business/picker/home); pages VerifyEmail (60s cooldown), ZeroWorkspace
  ("Hujaanzisha biashara bado"), CreateBusiness, WorkspacePicker; ScriptedAdapter now records
  request bodies. flutter analyze clean, 38/38 tests green. Tech debt: attribute-only
  Designer.cs ×3; single-tenant-per-user data model (registration IS org creation) — true
  multi-workspace needs membership redesign.

- **M3 Business Setup + Product Catalog (backend + Flutter), done 2026-08-23:** backend —
  `CompleteOnboarding` now unconditionally (idempotent guards) ensures a default warehouse
  "Main Store"/`MAINSTORE` (location `MAIN`) under the tenant's first active branch + default
  "Retail Prices" price list in the tenant currency (command holds tenant advisory lock);
  new `GET /api/v1/tax-categories` (`Products.View`, seeded TZ catalog VAT_STANDARD/VAT_ZERO/
  EXEMPT); product search case-insensitive via `EF.Functions.ILike`; fixed latent bug —
  `WarehouseRepository.ListAsync` lacked `.Include(Locations)` so list endpoints returned
  empty `locations[]`. 540/540 tests green. Flutter — `features/products` end to end:
  domain (Product/UnitOfMeasure/TaxCategory/Warehouse/StockBalance/PriceList), repository
  over real endpoints with **GET-merge-PUT price upsert** (`PUT /price-lists/{id}/prices`
  REPLACES all rows — preserve existing row ids!), CatalogController lazily seeds starter
  units Kipande/Kilo/Lita/Gunia on setup entry, ProductsController enriches list with default-
  list retail prices + stock totals client-side, StockController aggregates balances per
  product; pages Products ("Hujaongeza bidhaa bado"), ProductForm (create sends status=1,
  edit loads before first build; Conflict → duplicate-SKU message), OpeningStockSheet
  (409 on repeat), StockPage; HomeShell bottom-nav IndexedStack Mauzo/Bidhaa/Stock/Ripoti/
  Zaidi at `/home?tab=`; `/setup` shown after create-business, CTA → `/home?tab=bidhaa`;
  all four products controllers reset on logout. flutter analyze clean, 55/55 tests green.
  Real-API E2E verified the whole journey incl. API restart + fresh login persistence and
   409 duplicate opening stock. Debt: backend search matches contiguous substrings only;
   stock badges join one balances page (pageSize 200); buying price unsupported by backend.

- **M5 Offline-first POS + Sync, done 2026-08-23:** local encrypted store via
   `core/local` (Drift schema v1: meta/cached_products/cached_stock/local_sales/
   lines/payments/sync_queue; SQLCipher key from flutter_secure_storage — plain
   SQLite silently ignores PRAGMA key, so LocalDatabase warns when cipher_version
   is absent, e.g. Linux desktop). DeviceIdentity = UUIDv4 in secure storage.
   PosCatalogController is cache-FIRST (search never hits API); projected stock =
   cached balance − Σ pending offline sale lines; grid blocks ≤0. Checkout falls
   back to OfflineSaleRecorder on NetworkException/TimeoutException ONLY — the
   recorder reuses the SAME clientSaleId the online attempt used, writes
   sale+lines+payment+queue row atomically, and enforces the conservative stock
   guard. Provisional receipts show "Mauzo ya Offline" until server confirms.
   SyncEngine: single-flight FIFO drain, exponential backoff (5s→30min cap,
   12 attempts then manual-only), price-drift pre-check → CONFLICT/PRICE,
   insufficient stock → CONFLICT/STOCK, 403 → failed PERMISSION, 401 → pause
   without attempt increment; failed/conflict rows are NEVER deleted.
   ConnectivityMonitor distinguishes offline/unreachable/online via probe +
   hysteresis + noteApiSuccess(); connectivity_plus alone is never trusted.
   72 h offline selling window anchored by SessionJournal.markAuthenticated()
   fired from AuthRepository.onSessionEstablished (login AND refresh).
   Logout warns about pending count; DB retained encrypted per installation.
   Backend change (only one): TenantActiveMiddleware — suspended tenant gets 403
   on every authenticated request, cached 30 s (documented enforcement lag).
   E2E m5_e2e.sh proves exactly-once incl. aborted-mid-request acceptance.
   Debt: full-refetch catalog sync (no backend delta cursors); single warehouse
   aggregate ('*') in cache; no device registration API yet.

- **M4 POS Core / Sales (Flutter-only), done 2026-08-23:** backend sales engine reused
   unchanged (540/540). Flutter `features/sales` end to end — domain (CartLine,
   PaymentMethod ints Cash=0/MobileMoney=1/Card=2/BankTransfer=3/Credit=4/Other=5,
   buildCreateSaleBody sends NO price fields, SaleDto/SaleLineData/SalePaymentData/PagedSales
   parsers, buildReceiptText monospace ticket), SaleRepository (`POST /api/v1/sales` with
   **Idempotency-Key header = clientSaleId Guid**; server header wins and replays return the
   original SaleDto; GET /sales/{id}; GET /sales list with from/to/status/search;
   GET /pricing/resolve → null on 404), CheckoutController (**clientSaleId drawn once per
   logical sale and kept across retryable NetworkException/TimeoutException/ServerException/
   UnknownException so retries can never double-charge; new key only after definitive
   rejection or success; double-tap guarded by submitting state; pre-submit resolvePrice
   per line with silent fallback to cart snapshot**), CartController, SalesHistoryController
   (today window pageSize 100). Pages: PosPage (debounced search 300 ms, product grid,
   out-of-stock guard, zero-price guard, bottom cart bar), CartSheet (± qty; qty→0 removes),
   PaymentSheet (Cash/Mobile Money; ref.listenManual on CheckoutSuccess → clear cart +
   refresh history + pop + pushReplacement success), SaleSuccessPage (server-truth
   subtotal/VAT/total), ReceiptPreviewPage (copy + save .txt via path_provider — no
   printer stack in M4), SalesHistoryPage, SaleDetailPage. Router /pos /pos/success /sales +
   receipt/detail param routes; home tab 0 = POS; logout resets cart/checkout/history.
   posBranchIdProvider fetches first branch via GET /branches (WorkspaceDto has no BranchId).
   User-approved design decision: shelf prices are tax-inclusive server-side; tax calculation
   is deferred to a future addon (no tax-rules read API), so the cart shows Jumla only with
   hint "Bei zinajumuisha kodi." and the exact Subtotal/VAT split appears solely on the
   success screen/receipt from server truth (when tax addon is enabled).
   flutter analyze clean; 77/77 tests green. Real-API E2E (/tmp/opencode/m4_e2e.sh) verified
   the full journey incl. oversell → 400 whole-sale reject, same-key replay returns ORIGINAL
   sale with exactly one DB row, API restart + fresh login persistence, stock 50→48 stable.
   Debt: no void/refund UI; receipt unit prices omit TSh symbol; offline POS deferred to M8.

- **Mx Unverified-login UX fix (backend + Flutter), done 2026-08-29:** logging in with an
  unverified account no longer shows the misleading "Hauna ruhusa ya kitendo hiki" (403)
  banner; it now routes back to the verify-email screen. Backend `LoginCommand.cs` attaches the
  account `email` to the `AccountNotVerified` error (via `with { Details }` — `Error` is a
  readonly record struct, so object-initializer syntax is invalid); `ResultExtensions.cs`
  serializes `error.Details` into ProblemDetails `Extensions` for the non-validation path.
  Flutter `error_mapper.dart` maps a 403 with `code == 'AccountNotVerified'` to
  `AccountNotVerifiedException(message, email:)` (non-`AccountNotVerified` 403 still →
  `ForbiddenException`); `auth_controller.dart` `login()` catches it, recovers the email
  (error email else `_emailFromIdentifier`), and sets `AuthNeedsVerification(email)` so the
  router's `journeyRedirect` sends the user to `/verify-email` (fallback rethrown only when the
  email is unresolvable). Tests: 3 new journey tests (routes back w/ email, phone→email
  recovery, unresolvable rethrows) + 2 new repository tests (typed mapping w/ email, plain 403
  still Forbidden) in `auth_controller_journey_test.dart`/`auth_repository_test.dart`
  (`FakeAuthRepository` gained a scriptable `login` override). Backend
  `Login_BeforeVerification_Returns403AccountNotVerified` integration test now asserts the
  `email` property. Verified: `flutter analyze` clean (only 3 pre-existing warnings), auth tests
  17/17 green, backend builds `--warnaserror` clean, integration test passes, `dotnet format`
  (pre-existing-only violations, none in changed files).

- **Mx Products-page endless spinner bugfix, done 2026-08-29:** `ProductsPage` was a
  `ConsumerStatefulWidget` but never triggered the initial `load()` in `initState`, so the
  Bidhaa tab stayed in `ProductsLoading` forever (endless spinner) for a fresh MVP user.
  Added `initState` + `Future.microtask(() => ref.read(productsControllerProvider.notifier).load())`,
  matching the existing `StockPage` pattern. Mauzo/Stock/Reports empties were correct
  (no-products state); only the products list never loaded. `flutter analyze` clean; 16/16
  products tests green.
- **Mx Add-product form endless spinner bugfix, done 2026-08-29:** the `ProductFormPage`
  (`/products/new`) `ref.watch`es `catalogControllerProvider` but nothing triggered
  `CatalogController.load()` outside business setup — so a user landing on the form later
  stayed in `CatalogLoading` forever. Added `initState` + `Future.microtask` that calls
  `load()` only while the catalog is still `CatalogLoading` (guards against unnecessary
  reloads on the edit path). `flutter analyze` clean; 16/16 products tests green.

## coding.md — see `docs/CodingStandards.md`## accounting_plan.md — Slice 9 (IMPLEMENTED)

- **Spec:** `specs/accounting.md` · **Tasks:** `tasks/accounting/TASKS.md` (26 tasks, all done).
- **Key architectural decisions:**
  1. **No hardcoded accounts** — Event consumers resolve accounts via `IAccountMappingService`.
  2. **Idempotency** — Every event consumer checks `(TenantId, SourceType, SourceId)`.
  3. **Reversing entries** — Voiding a Posted JE creates a NEW mirroring JE (flipped debits/credits).
  4. **CurrentBalance** — Updated synchronously on JE post via account mapping service.
- **Status:** Implemented. 14 unit tests passing. Integration tests blocked on Postgres.

## jolinx_vision.md — see `docs/Jolinx-Vision.md`

- Jolinx is a **Business Operating System**, not just a POS.
- Core identity: "Every sale creates a trace. Every shilling has a story."
- Priority: Cash & Money Accountability → Credit → Owner Mode → Stock Story → AI
- See `docs/Jolinx-Vision.md` for full roadmap, feature status, and architectural principles.

## api.md — see `docs/APIStandards.md`

## database.md — see `docs/TechStack.md` + ADR-0002/0008

- Local: podman postgres:17, db `businessos`, user `businessos`, password from `DATABASE_URL`
  env var (trailing period is part of the password), port 5432. Redis `localhost:6379`, MinIO
  `localhost:9000/9001`. Test DB: `businessos_test`.

## ux.md — product principles

- Mobile-first, one-hand usable, works on cheap Android, offline-first.
- Swahili + English localization first-class. Large tap targets for POS.
- Guided onboarding < 10 min. Every screen earns its place.
- **Progressive complexity:** the system becomes more powerful as the business grows,
  without becoming more complicated for the person using it. Small shops see
  Sell/Stock/Money/Customers/Reports. Larger businesses unlock Warehouses/Transfers/Staff.
  Same platform, different cognitive load.
- **Hide complexity, not capability.** Users never need to understand how the system works
  internally to accomplish a business task. No database language in UI (no "Stock Movement",
  "Adjustment Transaction", "Correlation ID", "Idempotency"). Use business actions: "Add stock",
  "Fix stock", "Stock history".
- **Do vs Manage separation.** Everyday workers see Do (Sell, Add stock, Record expense).
  Owners/manager see Manage (Products, Prices, Warehouses, Staff, Reports, Settings).
- **Smart defaults.** The system remembers how the business operates. Default warehouse,
  default price, default unit, default payment method. The user confirms, not configures.
- **One question at a time.** Don't present giant forms. Ask "What are you adding?" then
  "How many?" then "Where?". Advanced details (supplier, batch, expiry) are opt-in.
- **Inform, don't block.** Negative stock shows "Stock is now -4. You can correct later."
  Never "Insufficient stock" / "Sale blocked". Sales always succeed; stock is advisory.
- **Dashboard answers questions.** "How is the business doing?" → revenue, low stock, credit.
  "What needs my attention?" → out-of-stock, overdue credit. Not raw data dumps.
- **Purchase vs Expense — strict distinction.** Two different business events, never blurred:
  - **Purchase** = "Nimenunua bidhaa" — acquiring inventory from a supplier. Impacts:
    Stock ↑, Money ↓ / Payable ↑, Supplier balance. Affects inventory cost.
    Flow: Supplier → Purchase Order → Products + quantities → Receive → Stock increases.
  - **Expense** = "Nimetumia pesa" — money spent to operate the business. Impacts:
    Money ↓ only. Does NOT increase stock. Examples: rent, transport, internet, airtime,
    staff lunch, government fees, office supplies.
  - User enters through the correct business action immediately. No generic "Money Out"
    button that forces a secondary choice.
  - Edge case (later): transport to bring stock can be an additional cost on the Purchase;
    don't force separate Expense + Purchase. Deferred — MVP keeps them separate.
- **Product cost price enforcement.** Every physical product (goods) must have a cost price
  set at creation. The cost price is snapshot onto each SaleLine at sale time. COGS is
  calculated as `SUM(SaleLine.UnitCost × Quantity)`. Services cannot have a cost price.
- **Guided stock increases.** Every stock increase (adjustment or opening) requires a reason
  type: Purchase, Return, Opening Stock, Adjustment, Transfer, Production. Cost per unit
  can optionally be provided at stock entry time.
- **Expense category enforcement.** Every expense must have a category. Default categories
  (Rent, Utilities, Transport, Salaries, Supplies, Marketing, Maintenance, Insurance,
  Taxes, Other) are seeded per tenant.
- **Reports philosophy: dashboard, not PDF list.** The owner should open Reports and understand
  what happened in the business in 10–20 seconds. Reports home is a dashboard with KPIs
  (Sales, Gross Profit, Expenses, Cash/Money), trend charts, and business snapshot (top
  products, money movement). Not a list of report names.
- **Global filter system.** One filter bar at the top: Period (Today/Yesterday/This Week/
  This Month/Last Month/Custom), Location, Staff, Category, Payment Method. Report updates
  automatically. Small shops select "This Month" and they're done. Larger businesses can
  drill "This Month → Branch: Kariakoo → Staff: John."
- **Drill-down architecture: Dashboard → Metric → Category → Transaction → Source.** Every
  number is clickable. Sales TZS 845,000 → tap → Cash/Mobile/Credit breakdown → tap M-Pesa
  → individual transactions → tap receipt → actual sale. This is what makes it feel
  professional vs basic POS.
- **Reports named by business question, not accounting term.** "Sales Performance" not
  "Revenue Recognition Analysis." "Stock Overview" not "Inventory Position Report."
  "Expenses" not "Operating Expenditure Analysis." Sophisticated calculations happen
  underneath; user sees business language.
- **Reports tell a story.** Not just numbers. "Sales ↑ 14.2% compared with February.
  Best day: Saturday — TZS 2,140,000. Best category: Building Materials."
- **Charts vs Tables.** Charts for trends/comparisons/proportions. Tables for transactions/
  stock/customers/detailed movements. Don't force everything into colorful graphs.
  Stock report = professional table with Opening/Purchased/Sold/Adjusted/Closing columns.
- **"Where did my money go?" report.** Starting Balance → Money In (Sales, Customer Payments)
  → Money Out (Purchases, Expenses, Supplier Payments) → Current Balance. Every number
  clickable. Business memory represented visually.
- **Progressive complexity for reports.** Small business: Sales/Stock/Money/Expenses/Purchases.
  Medium: +Branch/Staff/Customers/Suppliers/Categories/Profit. Large: +Branch Comparison/
  Staff Performance/Inventory Valuation/Receivables Aging/Payables Aging/Profitability/
  Consolidated Reports. Same system, different depth.
- **Export is secondary.** PDF/Excel/CSV/Print available but report itself is useful inside
  Jolinx. User shouldn't need to export to understand their business.
- **Future: AI "Explain this report."** "Your sales increased 14% but gross profit only 5%.
  Main reason: average product margin decreased. Cement contributed most sales increase but
  has lower margins." AI interprets business memory, doesn't replace the report.
- **Reports foundation MVP (6 reports):** 1) Business Overview ⭐, 2) Sales, 3) Stock,
  4) Money, 5) Purchases, 6) Expenses. All share global date/location/filter + drill-down.
  Foundation supports future: customers, suppliers, profit, branches, AI, exports.
- **Underlying data model.** All reports derive from same business events:
  Sale → stock ↓ + money ↑ + customer balance.
  Purchase → stock ↑ + supplier balance/money ↓.
  Expense → money ↓.
  Payment → money movement + balance update.

## branding.md

- Product name: **Business OS**. Flutter package: `jolinx_app`.
- Goal tone: trustworthy, simple, local. (Full brand guide deferred.)

## tech_stack.md — FINAL (locked 2026-08-31)

**Architecture decision: One Flutter codebase, everywhere.**

- **Backend:** .NET 10 (ASP.NET Core, modular monolith)
- **Database:** PostgreSQL
- **Client:** Flutter / Dart
- **Targets:** Web + Desktop (Windows/Linux/macOS) + Mobile (Android/iOS)
- **Languages:** Dart + C# only

**Dropped:**
- React (separate web frontend)
- Tauri (separate desktop frontend)

**Rationale:**
Solo developer optimizing for maintenance complexity, not "best technology per platform."
One codebase = shared auth, API client, models, state management, validation, localization,
theme, components, navigation, error handling, permissions, business workflows, offline
storage, synchronization, testing utilities.

**Build order:**
1. Stage 1 — Core (backend + Flutter architecture + auth)
2. Stage 2 — Primary client (Desktop + Android — POS/offline nature)
3. Stage 3 — Web (management/browser experience)
4. Stage 4 — iOS (another target, not another project)

**Platform adaptation:**
One codebase ≠ one UI. Each platform adapts to its device:
- Desktop POS: keyboard, barcode scanner, mouse, receipt printer
- Mobile: touch, camera, mobile money, small screen
- Web: information density, management workflows

**Offline-first:**
Local-first where workflow requires it + cloud synchronization.
Backend doesn't care what device the tenant prefers.

**Documentation updated:**
- `memory/project.md` — tech_stack.md section
- `MASTER_ARCHITECTURE.md` — repository layout (section 4) + client architecture (section 19)
- `docs/ArchitectureRules.md` — client architecture rule
- `docs/TechStack.md` — languages section + rationale

## known_issues.md

- System Postgres 17 `postgres` password unknown → we use our own container DB (ADR-0009).
- Redis/minio binaries not installed → containers.
- Integration tests need real Postgres on `localhost:5432` → CI runs unit tests only.
- Success `Result<T>` endpoints return **200**, not 201 (platform `ToApiResult` convention) —
  documented in the Organizations & Branches spec.

## M10.2 — End-to-End Business Flow Validation (done 2026-09-02)

**Backend integration suite added:** `backend/tests/BusinessOS.Tests/Integration/BusinessLifecycleEndToEndTests.cs`
(6 `[Fact]` scenarios, all passing): `Sale_ShouldReduceInventory_AndBeIdempotent`,
`CreditSale_ShouldTrackOutstandingBalance`, `Expense_AndAccountExpense_ShouldBehaveCorrectly`,
`CashSession_ShouldOpenAndCloseCorrectly`, `Reports_ShouldReflectSale_AndDashboardInventory`,
`Tenant_ShouldNotAccessAnotherTenantsData`. Flutter side: added
`test/features/finance/money_account_repository_test.dart` (4 regression tests) and a minimal
`getCurrentSession()` fix in `lib/features/finance/data/money_account_repository.dart`
(200 + empty body → null = "no session"; backend returns 200-empty, not 404). Finance tests: 22 pass;
`flutter analyze` 0 issues.

**Genuine production defects found and fixed minimally (both had broken/regressed existing tests):**
1. Credit auto-create 500: `SetCreditLimitCommandHandler`/`RecordCreditSaleCommandHandler` called
   `AddAsync` then `UpdateAsync` on a newly created `CustomerCredit`, producing a
   `DbUpdateConcurrencyException` ("expected 1 row, affected 0"). Fix: skip the redundant
   `UpdateAsync` for a freshly created aggregate (the Added entity is INSERTed with its walked
   values). Before this fix, `Credit_FullLifecycle` etc. 500'd; after, they reach stale-string
   assertions (see below).
2. `GET /reports/top-products` returned 400: `GetTopProductsAsync` used `[AsParameters] int limit`,
   which never binds a scalar from the query string (`limit` stayed 0 → validator `InclusiveBetween(1,100)`
   rejected it). Fix: removed `[AsParameters]` so `?limit` binds. `SalesTrendAsync [AsParameters] int days`
   has the same latent flaw but is out of M10.2 scope — unpatched.

**Recorded as findings, not fixed (architectural, per M10.2 scope):**
- A completed sale records `SalePayment` templates but does NOT auto-post to `MoneyAccount`.
- Ledger `POST /expenses` does NOT auto-post to `MoneyAccount`; only `POST /money-accounts/expense` does.
- Opening a cash session with a float does NOT credit the money account; `openingCash` is an attribute only.
- Dashboard Summary exposes only Catalog/Inventory/Pricing/Organization — no sales/expense/credit/cash.
- Cross-tenant reads that are aggregate-scoped by (tenant) row rather than id return **200-empty**, not 404
  (e.g. credit GET, stock list by foreign warehouse id). Isolation is preserved (0 rows), status differs.
- `Tenant_ShouldNotAccessAnotherTenantsData` covers cross-tenant writes: customer/expense PUT → 404; B
  posting into A's warehouse → 404; credit limit/payment from B never mutates A's balance (B creates only
  B-local rows keyed by (B, A's customerId) — orphan reference possible but no cross-tenant read/write leak).

**Pre-existing test brittleness exposed by the credit fix (NOT regressions; completed-module tests left
unchanged per AGENTS.md):** `CreditEndpointsTests` assert money as raw strings (`"250"`) and enum as
`"Sale"`, but serialization now yields `"250.00"` (decimal(18,2)) and numeric enum `"0"`. These 3 tests
were already failing (500) pre-fix; they now fail only on these stale assertions. The un-verifiable full
suite run totals are unavailable because the integration suite exceeds ~19 min in this environment
(slow real-Postgres tests); targeted regression batches all pass:
Sales/Expense/Inventory/E2E = 28 ✓; Customer/Money/Cash/Finance = 7 ✓.

## M10.3 — FINAL PRODUCTION HARDENING (COMPLETE)

Task outcome: **READY FOR M11.** No features added. All backend (597) + Flutter (261) tests pass;
0 analysis/build warnings. Full report = `M10.3 FINAL PRODUCTION READINESS REPORT` (delivered to user).

- **T1/T2 API correctness:** 3 stale credit assertions fixed (numeric money `GetDecimal()`, raw-array
  `.GetArrayLength()`, numeric enum). Cross-tenant read semantics: 3 resource-identifying GETs
  (`credit`, `feature-flag`, `tenant-account-mapping`) changed 200-empty→404 via `Error.NotFound`.
  `GET /cash-sessions/current` stays 200-empty (Category A state query; Flutter depends on it).
- **T3 latent bug:** `GET /reports/sales-trend` `[AsParameters] int days` removed (binding bug);
  regression test `Reports_SalesTrend_BindsDays`.
- **T4 tenant isolation audit:** 12/12 PASS, no leak; 2 LOW non-leaking findings (stored supplier ids).
- **T5 finance findings:** all 4 ACCEPT FOR V1 (auto-posting needs future ledger/journal per roadmap).
- **T6 backend:** full suite 597 = 415 unit + 182 integration, all pass, 0 warnings (Release
  `-warnaserror` clean).
- **T7 Flutter:** 261 tests pass + `flutter analyze` 0 issues. Fixed stale test setups/fakes:
  `late`-variable tearDown (3 controller files), customers/suppliers total fixture, dashboard
  salesTrend `label` field, reports loading test, profile 400→ValidationException, role permission
  content-type, POS/sales provider bootstrap (localDatabase/posBranchId/sessionContext overrides),
  removed 1 stale idempotency test (offline_checkout_test covers the real guarantee).
- **T8 production builds:** backend Release 0 warnings. Android release APK built (70.5 MB). Fixed
  Android main manifest: removed `package="com.example.business_app"`, set label "Jolinx", and moved
  `usesCleartextTraffic=true` to debug-only (was leaking cleartext to release). No localhost/dev/secrets
  in production config (base secrets empty, env-driven). Kotlin-Gradle-Plugin warning = future-Flutter note.
- **T9 security:** verified JWT validation (issuer/audience/signing/lifetime/1-min skew), refresh rotation
  + reuse detection (family revoke), login lockout, rate limiting (429), CORS off-by-default, security
  headers (HSTS/X-Frame/nosniff/no-referrer). **Added:** `Jwt:Secret` startup validation
  (>=32 bytes / HMAC-SHA256) in `Program.cs`. FINDINGS: dev DB password committed only in
  appsettings.Development.json (LOW/dev-only); android/`build.gradle.kts` release signed with debug key
  (LAUNCH requirement). No secrets logged.
- **Instrumented Production defects fixed in this milestone:** Android manifest package+cleartext,
  `setRolePermissions` sent `List.toString()` instead of JSON array (fixed via Content-Type in
  ApiClient.put), SettingsController.updateOrganization unhandled transport error (now Failure state),
  JWT secret not validated at startup.

## M11 — Anti-Bureaucracy POS (COMPLETE)

Plan/spec: `docs/AntiBureaucracyBlueprint.md`. Six steps; S1–S6 all done.

- **S1 Cash Change (done):** `Sale.Reconcile` allows `amountPaid >= total` +
  `expectedChange` with `Math.Max(0, …)`; `CreateSaleCommand` overpayment walked through;
  mobile threads `paymentAmount` (sale.dart/checkout/payment_sheet/receipt/sale_detail).
- **S2 Quick Quantity (done):** decimal-capable `CartController.setQuantity`; cart_sheet
  rewritten; PosPage long-press quantity dialog; ARB keys.
- **S3 Quick Sale (done):** hidden per-tenant "Bila Jina" Service product (SKU `QS-BILA-JINA`,
  auto "Mara" UoM) via `EnsureQuickSaleProductCommand` + `POST /products/quick-sale`;
  line-level `unitPrice` override short-circuits server price resolution; quick lines get unique
  `quick-<micros>` keys; mobile `addQuickSale`, offline payload carries `unitPriceOverride`,
  quick lines skip the stock guard. Backend integration test
  `CreateSale_QuickSaleLine_UsesClientFixedPrice_NoStockTouched` (fix: index JSON array via
  `[0]` instead of `GetProperty`). Mobile tests in `sale_repository_test`,
  `cart_and_receipt_test`, `local_database_test`, `offline_checkout_test`.
- **S4 Credit at POS (done):** Credit = method `Credit` allowing `amountPaid < total`;
  `Sale.Reconcile`/`SalePayment.Create` accept it; `CreateSaleCommand` gains
  `CustomerId` (required when credit present); handler auto-posts balance to customer ledger
  via `ICustomerCreditRepository` (get-or-create + `RecordSale` + `AddTransactionAsync`)
  inside the sale transaction. Endpoint + validators + DTO updated. Mobile: payment sheet credit
  tab (customer picker sheet, initial payment, outstanding row); `isElectronic` treats credit as
  non-electronic; offline recorder carries `customerId`. Tests: backend unit
  (3 credit handler + 3 validator), integration
  `CreateSale_CreditTenderUnderpays_PostsTheBalanceToTheCustomerLedger`; Flutter
  `cart_and_receipt`, `checkout_controller`, `local_database`. ARB keys `posCredit*`; run
  `flutter gen-l10n` after ARB edits.
- **S4 unblocked the build:** pre-existing unfinished Expenses/Credit/CRM/MoneyAccount/
  CashSession work referenced DbSets that were never wired into `BusinessDbContext`.
  Added minimal `OnModelCreating` mappings + `DbSet`s (Expenses, Customers, CustomerCredits,
  CreditTransactions, MoneyAccounts, MoneyAccountTransactions, CashSessions) and
  `Tables.Finance` constants, matching `BusinessDbContextModelSnapshot` exactly so no new
  migration is needed. Backend: 422 unit + 27 integration (sales ∅) tests green.
- **S5 Void Sale (done):** Backend pre-existing: `Sale.Void()` domain method, `VoidSaleCommand`
  handler with stock reversal (`SaleVoid` movements), `POST /sales/{id}/void` endpoint
  (`PermissionNames.SalesDelete`), `VoidSaleCommandValidator` (reason required, max 500),
  `SaleVoidedEvent` via outbox. Mobile: `sale_repository.voidSale()` method;
  `sale_detail_page.dart` void button with `ref.watch(authControllerProvider)` permission guard,
  voided banner, `_VoidReasonDialog` (reason input + confirm/cancel), `_confirmVoid()` method.
  ARB keys `saleVoid*`. Tests: repository contract test (`sale_detail_page_test.dart`);
  backend `VoidSaleTests.cs` integration tests; 269 Flutter tests pass (6 pre-existing
  failures in locale/routing). `flutter analyze` clean.
- **S6 Polish (done):** ARB consistency: fixed Swahili translations for `posCash` (→ Fedha),
  `posMobileMoney` (→ Pesa ya Simu), `posChange` (→ Baki); added 16 new ARB keys for
  hardcoded strings in `sale_detail_page.dart`, `receipt_preview_page.dart`, `sale_success_page.dart`.
  Hardcoded Swahili/English strings replaced with `context.loc.*` calls. "Shiriki" (Share) button
  fixed: was navigating to sale detail page, now uses `share_plus` `SharePlus.instance.share()`
  with receipt text. Added share button to receipt preview page. `SaleSuccessPage` upgraded to
  `ConsumerWidget` for workspace controller access. 269 tests pass; `flutter analyze` clean.

## Mx Reports feature improvement (done 2026-09-08)

Mobile `/reports` rewritten to match mainstream POS conventions (Square/Loyverse/Kopo Kopo):
- **Period presets** `ReportPeriod {today, thisWeek, thisMonth, lastMonth}` + pure
  `reportDateRange()` (local start-of-day → end-of-day, repository UTC-converts) + ChoiceChip
  selector. Default = **Today-first** (was hardcoded 30-day).
- **Latent bug fixed:** `SalesSummary` misread the API — `totalSales` (an int count) was
  displayed as money and `saleCount` (a key the backend never sends) always rendered 0.
  Model now parses `totalSales`/`totalRevenue`/`averageSale` per `SalesSummaryDto`.
- **Summary card:** Revenue / Average sale / Sales count (tax row removed, consistent with
  hidden tax). **New 7-day sales-trend bar chart** via the existing `/reports/sales-trend`
  endpoint (`SalesTrendPoint.label` = `yyyy-MM-dd`, rendered as `MMM d`).
- **Fixed broken "See all":** added `/reports/top-products` GoRoute +
  `TopProductsPage` (own `TopProductsController`, limit 25, period via `?period=` query) —
  previously the button 404'd. Localized `reportsPeriod*`, `reportsRevenue`,
  `reportsAverageSale`, `reportsTrendLast7Days`, `reportsSoldLabel` ARB keys (en+sw);
  removed unused `reportsTotal`/`reportsTax`. `flutter gen-l10n` regenerated.
- Tests: `report_repository_test` (parses new fields, sends exact range, salesTrend contract),
  `reports_controller_test` (reportDateRange/parseReportPeriod units, period delegation,
  trend in state, reset), new `top_products_controller_test`. **Verification pending — user
  runs `flutter analyze && flutter test`.** Not done (next): CSV export button (backend
  `POST /reports/export/*` + `SalesReportsExport` permission exist), sales-trend for other
  windows, ~350 remaining hardcoded strings.

## Mx "Old receipts" — Sales History date navigation + receipt search (done 2026-09-09)

Benchmarked against Square/Loyverse/Kopo Kopo; approved plan implemented on the Flutter
Sales History page only (no backend change needed — server search already matches receipt
`Number` OR `CustomerName`):
- `SalesHistoryController.load({DateTime? day, String? search})`: local midnight →
  next-midnight range, `pageSize 100`, trimmed search term forwarded; `SalesHistoryLoaded`
  gains `searchActive`; `loadToday()` kept as a thin wrapper (still used by
  `payment_sheet.dart`). 8 controller tests added.
- `sales_history_page.dart` rewritten: **Leo/Jana ChoiceChips + calendar picker**
  (`showDatePicker`, 365-day lookback) + **debounced (300 ms) receipt-number search field**
  with clear button; empty states differ ("no sales this day" vs "no matches"); custom-date
  caption `d MMM yyyy`; sale tile shows time · payment · customer name. Old receipt →
  existing `SaleDetailPage` → reprint unchanged.
- ARB (en+sw): added `salesHistory*` keys + `commonClear`; `flutter gen-l10n` regenerated.
- **Verification pending — user runs `flutter analyze && flutter test`.**

## Mx Expenses improvement — full sprint (WIP 2026-09-09)

Benchmarked against Loyverse/HowMuch/ZYNO (expense categories mandatory, seeded defaults,
create-on-the-fly, date-range reporting). Approved "Full sprint". Backend + Flutter work done,
**unverified (user runs `dotnet build/test` + `flutter analyze/test`).**

Backend (T1–T3):
- **T1 delete bug fixed:** `DeleteExpenseCommandHandler` called `UpdateAsync` (no-op —
  deleting an expense did nothing). Now `RemoveAsync` + `IExpenseRepository.RemoveAsync` +
  EF impl (`_db.Expenses.Remove`); DELETE → GET returns 404 (integration test).
- **T2 ExpenseCategory aggregate** (`Domain/Accounting/ExpenseCategory.cs`): name ≤ 50 chars,
  unique per tenant (`HasIndex(TenantId, Name).IsUnique()`), `OnDelete Restrict` FK from
  Expenses; DbSet + mapping in `BusinessDbContext`; `TableNames.Accounting.ExpenseCategories`;
  hand-written migration `20260909090000_AddExpenseCategories` + Full Designer
  (`BuildTargetModel` embedded — an attribute-only Designer set the latest migration's
  `TargetModel` to null and crashed tests with EF9 `PendingModelChangesWarning`;
  post-August migrations all carry full model Desigers, so full was the right pattern)
  + `BusinessDbContextModelSnapshot` updated with the ExpenseCategory entity
  AND the Expenses→ExpenseCategories FK.
- **Onboarding seeding:** `CompleteOnboardingCommandHandler.EnsureDefaultExpenseCategoriesAsync`
  seeds Utilities/Transport/Rent/Supplies/Petty Cash/Other (idempotent by name); persisted by
  `TransactionBehavior` (handlers never SaveChanges). New tests in
  `OnboardingDefaultsTests` + `CompleteOnboarding_RepeatedRun` now asserts 6 categories.
- **Endpoints:** `GET/POST /api/v1/expenses/categories` (View/Create) + `GET
  /api/v1/expenses/summary` (View, `fromDate/toDate`, default = current UTC month). Category
  reference guard in Create/Update expense handlers; `ExpenseDto.CategoryName` enriched on
  list/get/create/update.
- **T3 summary DTOs:** `ExpenseSummaryDto(Total, ByCategory)` + `ExpenseCategoryTotalDto`;
  EF `GetSummaryAsync` (inclusive `>= from && <= to`, groups by CategoryId, resolves names).
  Integration test covers totals (350), byCategory, null-category bucket, out-of-range excluded,
  and invalid range → 400.

Flutter (T4):
- `expense_repository.dart`: `ExpenseCategory`, `ExpenseCategoryTotal`, `ExpenseSummary` models
  + `listCategories()` / `createCategory(name)` / `getSummary({fromDate,toDate})`.
- `expenses_controller.dart`: `load({search, fromDate, toDate})` now also loads the summary for
  the active range; `loadMore()` pagination (`hasMore`); keeps `create/update/delete/reset`.
  `expenseCategoriesProvider` FutureProvider added.
- `expenses_page.dart` rewritten: **Leo / Jana / Huu Mwezi / Miezi Yote ChoiceChips + custom
  range picker** (default = this month), debounced (300 ms) search with clear button, **monthly
  spending-summary card** (total + top-3 category breakdown), load-more footer, empty states for
  "no expenses" vs "no search matches", date · category tile subtitle. All localized.
- `expense_form_page.dart`: **category dropdown with inline "Add category"** (dialog →
  `createCategory` → invalidates provider), delete button in app bar (confirm dialog), localized.
- ARB (en+sw): `expense*` keys + reuse of `commonRetry/Clear/Search/Cancel/Save/Delete`;
  `flutter gen-l10n` regenerated.
- Tests: `test/features/finance/expenses_controller_test.dart` (16 assertions: load, range
  bounds passed to repo, pagination, search, create/delete reload, failure, reset, UTC bounds).

## Mx Stock MVP — Advisory Stock + "Ongeza stock" (done 2026-09-12)

Stock is advisory, never blocks sales (African retail reality). Backend + Flutter, backend
tests + Flutter analyze/test all pending user verification.

Backend changes:
- **Non-blocking debit:** `SaleStockDebitService` locks row, creates balance if missing, always
  debits (negative allowed). `StockBalance.Apply` no longer throws on negative.
- **Idempotent adjustments:** `AdjustStockCommand` accepts `IdempotencyKey` (from
  `Idempotency-Key` header or body `ClientAdjustmentId`); replays return current balance
  without double-applying. Key stored on `StockMovement.CorrelationId` (pre-existing column,
  `BusinessDbContext.cs:370`). `FindAdjustmentByKeyAsync` on `IStockRepository` + EF impl.
- **Permission fix:** Staff role now includes `InventoryManage` + `WarehousesView`
  (`PermissionNames.cs:114`). Cashiers can top up stock.
- **Tests:** `StockLedgerTests` updated for negative-allowed; +3 adjustment idempotency tests;
  `SaleStockDebitServiceTests` rewritten (oversell-to-negative, missing-balance creates);
  `CreateSaleCommandTests` insufficient-stock now expects success with negative;
  `SalesEndpointsTests` integration rewritten for oversell; Purchasing stub
  `FindAdjustmentByKeyAsync` added.

Flutter changes:
- **AddStockSheet** (`add_stock_sheet.dart`): takes `productId`/`productName`, fully localized,
  draws Uuid `Idempotency-Key` kept across retries, cleared on success.
- **ProductRepository.adjustStock** sends `Idempotency-Key` header when key provided.
- **ProductDetailPage**: stock-aware image badge, "Ongeza stock" button on stock card, reloads
  after success. Localized stock card (productsStockHub/TotalStock/LowStockCount/ZeroStockCount).
- **ProductsPage**: reverted tile button to chevron; tile opens `/products/:id` (detail).
- **defaultWarehouse**: prefers code `MAINSTORE` over `.first` (multi-warehouse safe).
- **ARB keys** (en+sw): `productsAddStock`, `addStockTitle/Product/Quantity/Warehouse/Save`,
  `addStockInvalidQuantity/Unavailable`, `productsStockLabel`, `productsStockHub/TotalStock/
  LowStockCount/ZeroStockCount`, `productsDetailsTitle/NotFound/RetailPrice/WholesalePrice/
  Type/Category/Brand/Unit`.
- **Tests**: StockController test rewritten (`stock_controller_test.dart`: `StockRow.status` +
  `StockReady.visible` filtering).

Verified: `dotnet build` clean; `flutter analyze` pending `flutter gen-l10n`.

## Mx Reports Module — Full Implementation (WIP 2026-09-12)

Comprehensive reports module implementing the full reporting vision: dashboard-first,
global filter, drill-down architecture, business-question naming, charts+tables.

Backend (17 new queries/endpoints):
- **BusinessOverviewQuery** — KPIs (Sales, Gross Profit, Expenses, Money Balance) with
  period-over-period comparison, sales trend, top products. Endpoint: `/reports/business-overview`
- **MoneyMovementQuery** — Starting Balance → Money In (Sales) → Money Out (Purchases,
  Expenses) → Current Balance. Endpoint: `/reports/money-movement`
- **PurchasesSummaryQuery** — Total Purchased, Supplier Count, Items Received, Top Supplier,
  Pending/Received counts. Endpoint: `/reports/purchases-summary`
- **SalesByPaymentMethodQuery** — breakdown by Cash/Mobile Money/Credit/etc.
  Endpoint: `/reports/sales-by-payment`
- **SalesByCategoryQuery** — breakdown by product category.
  Endpoint: `/reports/sales-by-category`
- **SalesByStaffQuery** — breakdown by staff member.
  Endpoint: `/reports/sales-by-staff`
- **SalesByCustomerQuery** — top customers by revenue.
  Endpoint: `/reports/sales-by-customer`
- **StockSummaryQuery** — per-product: Opening/Purchased/Sold/Adjusted/Closing.
  Endpoint: `/reports/stock-summary`
- **StockMovementSummaryQuery** — movement counts by type per period.
  Endpoint: `/reports/stock-movements`
- **LowStockReportQuery** — products below threshold by warehouse.
  Endpoint: `/reports/low-stock`
- **StockVelocityQuery** — products ranked by velocity (units/day).
  Endpoint: `/reports/stock-velocity`
- **ExpenseTrendQuery** — daily expense trend.
  Endpoint: `/reports/expense-trend`
- **ExpenseByPaymentMethodQuery** — breakdown by payment method.
  Endpoint: `/reports/expense-by-payment`
- **PurchasesBySupplierQuery** — breakdown by supplier.
  Endpoint: `/reports/purchases-by-supplier`
- **ExportSalesByPaymentMethodCommand**, **ExportStockSummaryCommand**,
  **ExportExpenseSummaryCommand** — CSV export for new reports.
- New domain records: `SalesByPaymentMethodRow`, `SalesByCategoryRow`, `SalesByStaffRow`,
  `SalesByCustomerRow`, `StockSummaryRow`, `StockMovementSummaryRow`, `LowStockReportItem`,
  `StockVelocityRow`, `ExpenseTrendPoint`, `ExpenseByPaymentMethodRow`.
- Repository methods added to `IReportRepository`, `IStockRepository`, `IExpenseRepository`.
- EF implementations in `PlatformRepositories.cs` and `ReportRepository.cs`.
- FluentValidation validators for all new queries (15 validators added).
- `IPurchasingRepository` replaced with MediatR `ListPurchaseOrdersQuery` dispatch.

Flutter (14 new files + 4 updated):
- **ReportFilter** model (`report_filter.dart`): `ReportPeriod` enum (today/yesterday/
  thisWeek/thisMonth/lastMonth/custom), filter state with `dateRange` and `toQueryParams`.
- **ReportFilterBar** widget: period chips + custom date range picker, reusable across
  all report pages.
- **ReportKpiCard** widget: icon + title + value + optional trend arrow/percentage.
- **ReportTrendChart** widget: line chart using `fl_chart` with gradient fill.
- **ReportDataTable** widget: sortable table with headers, rows, tap handling.
- **ReportPieChart** widget: donut chart with percentage labels and legend.
- **MoneyFlowCard** widget: starting balance → money in → money out → current balance.
- **BusinessOverviewPage** (`business_overview_page.dart`): KPI cards, sales trend chart,
  top products list.
- **SalesReportPage** (`sales_report_page.dart`): summary KPIs, trend chart, pie charts
  by payment method and category.
- **StockReportPage** (`stock_report_page.dart`): stock summary table, movement summary,
  velocity table.
- **MoneyReportPage** (`money_report_page.dart`): money flow card with in/out breakdowns.
- **PurchasesReportPage** (`purchases_report_page.dart`): summary KPIs, supplier pie chart,
  supplier table.
- **ExpensesReportPage** (`expenses_report_page.dart`): total expenses, category pie chart,
  trend chart, payment method table.
- **ReportsPage** restructured as hub: grid of 6 report cards (Overview, Sales, Stock,
  Money, Purchases, Expenses) + Top Products.
- **Routes** added: `/reports/overview`, `/reports/sales`, `/reports/stock`, `/reports/money`,
  `/reports/purchases`, `/reports/expenses`.
- **ReportRepository** extended with 12 new methods + 14 new model classes.
- **Report providers** extended with 14 new `FutureProvider.family` providers.
- **ARB keys** (en+sw): 75 new keys for all report UI text.

Verified: `dotnet build` clean; `flutter analyze` pending `flutter gen-l10n`.

## M9.2 — Offline-invisible login + trusted-device unlock + device lock (2026-09-22)

Goal: users must never see "offline" messaging on the login screen and must not
re-enter their password on every open. Approved plan implemented entirely client-side
(M9.2 backend existed before).

- **Unified "Ingia" button, offline-invisible:** `AuthController.login` tries the backend;
  on `NetworkException`/`TimeoutException`/`ServerException` it silently falls back to local
  password verification (`_silentOfflineFallback`) — ONLY when the typed identifier matches
  the cached account, so a wrong-account attempt cannot unlock someone else's offline data.
  Wrong password surfaces the same neutral "Nenosiri si sahihi." message. No "Mtandao
  haupatikani?" hint, no "Ingia Nje ya Mtandao" button (removed from `login_page.dart`).
- **Trusted-device fast unlock (7-day sliding window):** the quick-unlock HMAC token
  (`offline_credential_store.dart`) now refreshes its expiry after every successful
  biometric or PIN unlock; logout disables it. Trusted window covers no-biometric devices
  too.
- **Device unlock PIN (4–6 digits, PBKDF2, shared exponential lockout):** `setUnlockPin`,
  `verifyUnlockPin`, `hasUnlockPin`, `clearUnlockPin`. Used via:
  - cold start: `AuthController.loginWithPin` / `setupPin` → `AuthRepository.unlockWithPin` /
    `setupPinAndUnlock` (both gated on a valid quick-unlock token);
  - device lock: `AuthController.unlockWithPin` (no token needed — session already trusted).
- **Idle/background auto-lock (`AuthLocked` state):** new sealed state
  `AuthLocked(session, isOffline)` — non-destructive. `AppLockPolicy`
  (`core/session/app_lock.dart`, testable, configurable via `appLockPolicyProvider`):
  5-min idle timeout + 45s background grace. `_BusinessOsAppState` is now a
  `WidgetsBindingObserver`: `didChangeAppLifecycleState` locks on long backgrounding; a
  `Listener` (`onPointerDown`) resets the idle timer. Router: `AuthLocked` → `/lock`;
  `workspaceJourneyBindingProvider` keeps all controllers live during a lock so cart/forms
  resume exactly. `LockPage` unlocks with a fresh biometric or the PIN; no fast factor →
  logout to login. Idle/background lock never touches the cold-start morning restore.
- **iOS Keychain device-bound across ALL secure stores:** every `FlutterSecureStorage`
  now `KeychainAccessibility.firstUnlockThisDeviceOnly` (tokens, DB key, branch cache,
  device identity, theme, printer, locale, offline store) so secrets never migrate via
  iCloud restore (stolen-device mitigation). Existing iOS installs must re-login once when
  accessibility changes.
- **Tests:** journey tests for silent fallback (matching/mismatched identifier, wrong
  password), lock/unlock/pin-unlock/setup transitions (scriptable fake gate + store);
  repository tests for quick-unlock gating of `unlockWithPin`/`setupPinAndUnlock`; store
  tests for PIN policy + lockout + quick-unlock renewal (`offline_credential_store_test.dart`);
  `app_lock_test.dart`; router tests for `AuthLocked` → `/lock` and unlocked-on-`/lock`.
- **Recorded debt:** no remote "revoke my devices" / new-device alert (recommend
  least-privilege cashier accounts and `firstUnlockThisDeviceOnly` until then); in-app
  POS "offline" badges are functional sync indicators, intentionally out of scope.

## M9.2b — M-Pesa-style direct security prompt on login/lock (2026-09-22)

Refines M9.2's UX: a trusted device opens straight into the security challenge —
fingerprint or an inline PIN pad — exactly like M-Pesa, instead of showing the
username/password form with quick-unlock buttons bolted underneath. No "offline"
wording anywhere.

- **New `PinPad` widget** (`widgets/pin_pad.dart`): 6-dot indicator row + numeric
  keypad (1–9, 0, backspace, check). Confirm is only enabled with 4–6 digits
  entered (no auto-submit at 4, so 5–6-digit PINs stay possible); the pad clears
  after every submit attempt so a rejection starts fresh.
- **New `FastUnlockPanel` widget** (`widgets/fast_unlock_panel.dart`): shared
  M-Pesa-style prompt — large fingerprint hero button (+ "au ingiza PIN yako"
  separator when appropriate) and/or inline `PinPad`, plus inline error text and a
  busy state. Reused by `LoginPage` and `LockPage`.
- **`LoginPage`** now has two modes: **fast** (default when `hasValidQuickUnlock()`)
  with a "Habari, {firstName}!" greeting + `FastUnlockPanel`, and a muted
  "Mtu mwingine? Ingia kwa akaunti yako" link that reveals the classic email/password
  form (which offers a "Tumia Kidole au PIN" back-link only when still trusted).
  Trusted + no biometric + no PIN → the setup sheet auto-opens once so a PIN can be
  chosen (M-Pesa behavior); cancelling drops to the password form. Fast failures
  render inline via `_runFastAction` (compares pre/post auth-state messages to avoid
  echoing a stale logout message).
- **`LockPage`** refactored: same `FastUnlockPanel` inline (fingerprint and/or PIN
  pad); the PIN sheet is gone from the lock screen (`pin_unlock_sheet.dart` now only
  serves first-time PIN setup). No fast factor → unchanged "Ingia kwa nenosiri"
  logout button.
- **Tests** (`fast_unlock_widget_test.dart`, net-new): login fast-biometric mode
  (greeting/prompt visible, form hidden; tap releases session), PIN-pad-only mode,
  valid-4-digit submit records the PIN, rejected PIN shows the inline error, and the
  classic form on an untrusted device; lock screen wrong-PIN inline error stays
  locked (`unlockWithPin` throws → controller still `AuthLocked`) and correct PIN
  unlocks (`AuthAuthenticated`). Fakes: `FakeAuthRepository` (scriptable
  `restore/loginWithBiometric/unlockWithPin/loginOffline` + real `ApiClient` shell),
  `FakeOfflineCredentialStore` (trusted/hasPin/verifyPin), `_FakeBiometricGate`.

## M9.3 — Sale→receipt speed: bulk price resolve + checkout deadline (2026-09-22)

Addresses the complaint that sales take too long to reach the receipt on
low-bandwidth networks. Approved as "Option A + B".

- **Root cause**: checkout re-resolved every cart line with one
  `GET /pricing/resolve` per line (N round trips), then `POST /api/v1/sales`;
  after success `payment_sheet.dart` fired **6 backend reloads** in one burst
  (salesHistory, dashboard, reports, stock, products, posCatalog). With Dio
  timeouts of 15/30s, weak links made users stare at the spinner for 30s.
- **A — client-side deadline + burst trim**:
  - `CheckoutController.submit` now wraps the whole online attempt (bulk resolve
    + create) in `online.timeout(4s)`. On timeout it only falls back to the local
    pending queue (`_recordOffline`, same `_clientSaleId`) when the offline window
    is actually open (`sessionJournal.offlineWindowOpen()`); with a closed window
    it keeps waiting for the authoritative result instead of refusing. `online`
    is `.ignore()`-d so a late success/error from an abandoned attempt never
    surfaces as an unhandled async error — a late server accept stays harmless via
    M5.7 idempotent replay. Uses `import 'dart:async' as async` to disambiguate
    `async.TimeoutException` (from `Future.timeout`) from the app's
    `app_exception.TimeoutException` (create a timeout → existing transport
    fallback).
  - `payment_sheet.dart` post-success reload trimmed to only `stock` +
    `posCatalog` (the data the next sale needs); sales history, dashboard,
    reports and products all reload when their pages are opened.
- **B — bulk pricing endpoint (backend + client)**:
  - `POST /api/v1/pricing/resolve-many` (`PricingEndpoints.cs`, `PricingView`
    permission): body `{ lines:[{productId, quantity}], branchId, priceType }`,
    response is a bare JSON array of
    `{ productId, variantId, price, currency, errorMessage }` — `price` is null
    for unresolvable lines so clients keep the cart price.
  - New `ResolvePricesQuery`+handler (`Application/Features/Pricing/Queries/`)
    reuses the single-resolution logic by injecting
    `IRequestHandler<ResolvePriceQuery, ...>` and looping each line — no logic
    duplication. `ResolvedLineDto`/`ResolvePriceLineDto` added to `PricingDtos.cs`;
    `ResolvePricesQueryValidator` guards empty/oversized batches (≤100 lines,
    per-line `productId` non-empty, `quantity ≥ 1`).
  - Client `SaleRepository.resolvePrices(...)` makes the one call;
    `CheckoutController._refreshPrices` uses it (fallback: any `AppException` →
    cart prices as before).
- **Tests**: `sale_repository_test.dart` resolve-many (one POST, right body,
  unresolvable line absent); `checkout_controller_test.dart` fake now implements
  `resolvePrices` and asserts `resolveManyCalls`; the cart-price fallback test now
  uses `resolveMultiError`; `offline_checkout_test.dart` adds a **deadline case**
  (stalled `create` → after 4s falls back to the local queue, key preserved,
  `pendingLocally` true). Backend `PricingEndpointsTests.cs`: bulk resolve with two
  lines (one priced, one unresolvable) + empty-batch 400.
- Pending: user runs `flutter analyze` + `flutter test` for the M9.2 + M9.2b +
  M9.3 batch, and the backend `dotnet test` run for the resolve-many endpoint +
  the whole backend suite.

## M13 — Subscription foundation backend (WRITTEN 2026-09-22, NOT YET BUILT/VERIFIED)

Code-only milestone written under a no-commands directive; build/format/tests
must run on the next permitted session. Freemium monetization for the free-host
launch: everyone starts on a 14-day Pro trial; whatever runs out falls back to
the Free plan (POS + inventory backstop) instead of hard-locking the terminal.

- **Domain** (`Domain/Billing/`): `SubscriptionAccessEvaluator` derives status
  purely from dates — `{ Trial, Active, Debt }`, `AccessLevel { Full,
  PosAndInventory }`, `NextDueUtc` à la paidUntil; `FeatureKeys` (Full vs
  PosAndInventory sets); `Plan` (Pro = TZS 25,000/mo; quotas branches 3 / users 5
  / products 3000 / maxBranches etc.; Free backstop), `Subscription`
  (`StartTrial`, `Paid(to)/Lapse/settle invariants`, `PaidUntilUtc` advisory +
  one stored helper `Status`, transition tracking via status history), `Voucher`
  (CSPRNG `XXXX-XXXX-XXXX`, alphabet excludes 0/O/1/I, 1–365 days, single-use,
  `RecordBatchIssued` raises `VouchersIssuedEvent` on the batch end — uses the
  protected `AddDomainEvent`), `Invoice` (numbering via
  `NumberSequenceRepository.AllocateAsync(scope "Invoice")`, status Open/Paid/
  Cancelled, period start/end). `Domain/Events/BillingEvents.cs`.
- **Migration** `20260922000000_AddPlansSubscriptionsVouchersInvoices`
  (hand-written Up/Down; 4 additive tables Plans/Subscriptions/Vouchers/Invoices;
  unique indexes Code/Number, IX_Subscriptions_TenantId). Designer partial
  delegates `BuildTargetModel` to `BusinessDbContextModelSnapshot.BuildModel`
  via reflection (attribute-only Designer + delegation variant) — stays in sync
  when a future `dotnet ef migrations add` regenerates the snapshot; `migrations
  add/remove/script/update` all diff against TargetModel, so nothing breaks.
  Snapshot `.cs` updated with the 4 Billing entity blocks (alphabetized).
- **Application** (`Features/Billing/`): DTOs + mappers, `SubscriptionEntitlement`
  record + `ISubscriptionEntitlementService` (evaluator + plan lookup + open
  invoice debt detection), commands/queries (`RedeemVoucher`,
  `EvaluateSubscription` — idempotent self-heal that auto-issues the renewal
  invoice once at trial lapse, `IssueVouchers`, `MarkInvoicePaid` — owner desk
  manual M-Pesa settlement that extends PaidUntil by the payable window,
  `GetSubscription`/`ListPlans`/`ListInvoices`/`GetInvoice`/`ListBillingDebts`),
  FluentValidators. Tenant-scoped commands carry `IRequiresTenantAdvisoryLock`;
  owner/admin commands don't. Registered `ISubscriptionEntitlementService`.
- **Hooks**: `RegisterUserCommand` and `ProvisionTenantCommand` grant the trial
  (`Subscription.StartTrial`) at tenant creation; `DatabaseSeeder` seeds
  Free/Pro idempotently and backfills a 14-day trial for legacy tenants without
  one. **Legacy cost**: tenant-scoped reads that hit
  `SubscriptionEntitlementService` do 1 extra query (plan) — acceptable.
- **Enforcement** (`API/Middleware/SubscriptionAccessMiddleware.cs`,
  registered after `TenantActiveMiddleware`): GETs always pass; non-GET
  premium-write prefixes (purchase-orders/supplier-bills/suppliers, accounts/
  journal-entries/account-mappings/accounting-reports, expenses, price-lists/
  pricing, credit incl. nested `/customers/{id}/credit` via `Contains("/credit")`,
  money-accounts/cash-sessions) return 402 when entitlement is Debt. Entitlement
  cached 30s (`IMemoryCache`, key `billing:entitlement:{tenantId}`) so the
  mid-flight 402 doesn't add a DB hit per request.
- **Endpoints** (`API/Endpoints/BillingEndpoints.cs`, wired in Program.cs);
  Billing.View on tenant routes, Billing.Manage on `/admin/billing/*`. Enums
  serialize as numbers (no JsonStringEnumConverter anywhere) — Flutter maps raw
  ints.
- **Tests written (unrun)**: unit — evaluator date matrix, subscription state
  machine, voucher code format/unambiguity, invoice period math; integration
  `BillingEndpointsTests` — auth guard, register→Pro-trial full access,
  plans catalog, trial lapse→Debt + invoice issued exactly once, 402 premium
  write while stock backstop + reads pass, redeem voucher extends + settles open
  invoice (via `/admin/billing/vouchers/issue`), unknown/bad voucher rejected.
- **Deferred (next task)**: Flutter billing page + client feature gating; the
  M-Pesa manual voucher is the first monetization channel (Flutterwave later).
- **Pricing note**: legacy `BusinessProposal`/`BusinessPlan` docs still quote USD
  Starter/Growth/Pro — the MVP product is a single Pro plan at TZS 25,000/mo.

## M13.1 — Entitlement enforcement + Flutter billing client (WRITTEN 2026-09-25, NOT YET BUILT/VERIFIED)

Second code-only pass under the same no-commands directive. No schema change (no
new migration); the entitlement cache, middleware and Flutter client now line up
with the M13 domain.

- **Backend fixes**:
  - `GET /api/v1/billing/subscription` is permission-free (the only unmapped
    billing read); plans/invoices/evaluate/redeem keep `Billing.View`; owner desk
    stays on `/api/v1/admin/billing/*` behind `Billing.Manage`.
  - Debt: reads never blocked, POS + inventory writes allowed, other premium
    writes → `402 BillingRequired`; a disabled module on a write → `403
    ModuleDisabled` (extensions: `code`, `featureKey`). GET/HEAD/OPTIONS
    short-circuit **before** entitlement access, so reads never populate the cache.
  - `ModuleRouteMap` also maps `price-lists` + `pricing`; quota guards on branch,
    user and product creation; those three commands now implement
    `IRequiresTenantAdvisoryLock` so the count check can't race.
  - `SetFeatureFlagCommandHandler` only called `flag.Enable(config)` when
    `IsEnabled && Config is not null` — a config payload with `IsEnabled=false`
    used to enable the flag.
  - **Feature-flag cache invalidation**: new `FeatureFlagChangedEvent`
    (`Domain/Events/FeatureFlagEvents.cs`) raised by `FeatureFlag.Create(enabled)`,
    `Enable`, `Disable`; handled by `SubscriptionEntitlementCacheInvalidationHandler`
    (registered in `Application/DependencyInjection.cs`). Dispatch is post-commit via
    `TransactionBehavior`, so toggling a flag can no longer leave a 30s stale
    entitlement. The seeder writes flags with plain `_db.SaveChangesAsync`, so
    seeding adds no outbox noise.
  - **Self-heal in one round trip** (evaluate/redeem with no subscription row):
    `SubscriptionRepository.GetForTenantAsync` checks `_db.Subscriptions.Local`
    first; `InvoiceRepository.GetOpenAsync` returns a pending local open invoice
    and otherwise excludes tracked local invoice ids from the DB query — the
    just-marked-paid invoice can't surface as open before the save.
- **Flutter client**: `features/billing/` (domain, repository, providers,
  controller, billing page, invoice PDF share via `pdf` + `share_plus`),
  `/billing` route + home tile (permission-checked), debt lock on premium tiles,
  mutation redirects, entitlement-aware product price fields, EN/SW strings.
  `ApiClient` maps `402` → `PaymentRequiredException` and fires a **single-flight**
  `onPaymentRequired` callback (providers wiring refreshes the entitlement, which
  re-evaluates route redirects). Finance routes gate on `finance.enabled`
  (`BillingFeatureKeys.finance` + `financeFeatureAccessProvider`); price editing
  uses `AccessLevel.Full` (`fullBillingAccessProvider`) — there is no client
  `pricing.enabled` key. `ProductFormPage` catches `PaymentRequiredException` to
  show the localized lock message and refreshes the entitlement.
  `router.dart` now exposes the pure `premiumRouteRedirect` (same pattern as
  `journeyRedirect`) for unit tests.
- **Tests written (unrun)**: backend integration — trial self-heal via evaluate,
  paid self-heal via redeem, finance flag toggle invalidates the entitlement cache
  (403 → allowed); unit — `SubscriptionEntitlementGuard` at-limit/above-limit/null
  quota boundaries. Flutter — `billing_domain_test`, `billing_repository_test`,
  `billing_controller_test` (single-flight load/refresh, provider fallback),
  `api_client_test` 402 mapping + single-flight notification,
  `app_router_test` premium redirect matrix.
- **Known edge (not fixed)**: product metadata and product prices are two
  requests; a `402` on the price write (entitlement dropped mid-save) leaves the
  metadata saved. Closing it needs one transactional backend endpoint — deferred.
- **Pending verification** (user-run): `dotnet build`, `dotnet test
  backend/tests/BusinessOS.Tests`, `flutter gen-l10n`, `dart format --set-exit-if-changed`,
  `flutter analyze`, `flutter test`.

## M7 — Receipt redesign: one ticket for screen, text, PDF and thermal (2026-09-25, CODE WRITTEN — PENDING USER-VERIFIED COMMANDS)

Approved plan: `docs/plans/2026-09-25-receipt-redesign-plan.md`. Spec: `specs/receipts.md`
(new — the receipts module shipped without one). Written under a no-commands directive, so
nothing was built, formatted, analyzed or tested by the assistant; the user runs the
commands. Key decisions:

- **Architecture:** `lib/features/receipts/domain/receipt_renderer.dart`
  (`Thermal80mmRenderer`) is the single source of truth for receipt layout. Every emitted
  line is padded/truncated to exactly **42 columns** (`_fit`), so `buildEscPosBytes` prints
  text **verbatim left-aligned** and adds only bold + the QR raster — any ESC/POS center
  command would double-shift a header the renderer already centered (and printer
  trailing-space handling is untrustworthy). Deviations from the plan, deliberate:
  `isReceiptLabel`/`isTotal`/`isFooter` centering dropped; footer left-aligned; bold rules
  = watermarks, business name (first content line), `---` **and** `===` separators, item
  header (`Qty`/`Kiasi`), `GRAND TOTAL`/`TOTAL`/`JUMLA`.
- **Shared formatting:** new `lib/features/receipts/domain/receipt_format.dart`
  (`receiptMoney`, `receiptMoneyNegative`, `receiptMoneyBare`, `receiptQuantity`,
  `receiptDate` = `dd-MMM-yyyy hh:mm a`, `receiptDiscountPercent`, `receiptTaxPercent`,
  `receiptCurrency`, `receiptWholeAmount`, `receiptLineWidth` = 42) is imported by the
  renderer, the QR builder and the on-screen widget — no duplicated business formatting.
- **Currency:** the tenant ISO code prints as-is (`TZS 23.75`) with 2 decimals always; the
  `currencySymbol` TSh-mapping helper was **removed** from `money.dart` (now
  `formatMoney(..., alwaysDecimals:)`); the QR payload keeps a whole-number total.
- **Backend (`ReceiptPreviewDto` extension):** `Email`, `BranchName`, `CashierName`,
  `CustomerName`, `Currency` + `ReceiptPaymentDto.Reference`, projected by
  `GetReceiptPreviewQuery` (also injects `IUserRepository`/`IBranchRepository`);
  `BuildQrPayload` now takes `currency` and formats the date/total with
  `CultureInfo.InvariantCulture`. No migration, no new permissions, no domain changes.
- **Widget:** `lib/features/receipts/presentation/widgets/receipt_ticket_card.dart` —
  stateless, provider-free UI twin of the renderer, now used by `ReceiptPreviewPage` and
  `SaleSuccessPage` (which also stops printing the placeholder `businessName: 'Business'`).
  `pubspec.yaml` finally registers **RobotoMono** (assets existed; it was silently falling
  back and misaligning every column).
- **Localization:** `ReceiptLabels` (EN/SW) + `receiptLanguageForCode`;
  `thermalRendererProvider` and `receiptPrinterServiceProvider` both watch the locale.
- **Reprint + audit (was dead code):** pages render `*** REPRINT ***` from
  `printCount > 0` plus a same-session counter, and fire-and-forget
  `ReceiptRepository.recordPrint` after a successful print (`Original` → `Reprint`),
  swallowing offline failures. **Deviation:** `SaleSuccessPage` tracks its own session
  counter for audit type *and* watermark, where the plan assumed it always records
  `Original` and never watermarks — keeping the two pages identical.
- **Cleanup:** deleted `lib/features/sales/domain/receipt.dart` (legacy second builder);
  `ReceiptPrinterService.saleToReceipt` is the only `SaleDto` → ticket path (also fixes
  `isVoided` hard-coded `false`) and gained `isReprint` threading. `receipt_qr.dart`
  `currencySymbol(...)` → `receiptCurrency(...)` (compile fix after the helper removal).
- **Tests written:** `receipt_preview_test.dart` (model round-trip incl. old JSON, every
  renderer section, EN+SW, QR branches, 42-column width invariant),
  `receipt_ticket_card_test.dart` (widget incl. QR present/absent, reprint, Swahili),
  `cart_and_receipt_test.dart` legacy group → `saleToReceipt + Thermal80mmRenderer`
  (Swahili, `Kodi (VAT 18.4%)` computed from the fixture), backend
  `ReceiptEndpointsTests.cs` (identity fields + payment reference).
- **Pending verification** (user-run): `flutter analyze`, `flutter test`,
  `dart format`, then `cd backend && dotnet build --warnaserror && dotnet format
  --verify-no-changes && dotnet test --filter "FullyQualifiedName~Receipt"`.

## M13.2 — Module packages, capabilities client & customer invoicing (2026-09-25, CODE WRITTEN — PARTIALLY VERIFIED)

Spec: `specs/module-packages.md` (new). Tasks: `tasks/module-packages/TASKS.md` (new).
Delivers the first add-on package end to end on top of the M13/M13.1 entitlement base.

- **Package model**: `Plan.IsPackage` + `Plan.InvoiceManagerCode = "invoice-manager"`,
  seeded by `DatabaseSeeder.EnsureBillingCatalogAsync` (Free 0 TZS / backstop keys,
  Pro with 3/5/3000 quotas, `invoice-manager` with `invoicing.enabled`). A package is
  stored as a `SubscriptionItem` and never replaces `Subscription.PlanId`, so
  `invoicing.enabled` cannot leak into Free or Pro.
- **Entitlement formula**: `(base plan keys ∪ active SubscriptionItem plan keys) ∩ enabled
  tenant feature flags` — a package can never widen the tenant past its provisioned flags.
- **403 vs 402 is a product decision**: healthy plan + missing key → 403 `ModuleDisabled`
  ("upgrade"); debt + missing key on a non-backstop module → 402 `BillingRequired` ("pay").
  Collapsing them into one code was explicitly rejected. `ModuleRouteMap` maps route
  segments to modules (including the `/customers/{id}/credit/*` special case);
  `SubscriptionAccessMiddleware` enforces it and writes a `module` ProblemDetails
  extension; `SubscriptionEntitlementGuard` covers sub-features and quotas the route map
  cannot express. Quotas are nulled under degraded access so a debt tenant is never blocked
  on a module it still owns.
- **Capabilities API**: `GET /api/v1/capabilities` → `CapabilitiesDto` incl.
  `PlanFeatureKeys`, `Packages`, and `validOfflineUntil = min(nextDue + 7d, now + 30d)`.
  Package activate/remove: `POST|DELETE /api/v1/billing/packages/{planCode}` behind
  `Billing.Manage`, both returning the recalculated code list. The client is strictly
  `200`-based — `Result<T>.ToApiResult()` maps success to 200, never 201.
- **Customer invoicing** (separate from subscription billing): `CustomerInvoice` aggregate
  with `CustomerInvoiceLine` and status `Unpaid → PartiallyPaid → Paid` + terminal `Void`,
  partial payments, overpayment rejection, derived `BalanceDue`, server-recomputed totals,
  tenant advisory lock for exactly-once numbering. Permissions `Invoices.View/Create/Manage`.
  Migration `20260925001000_AddCustomerInvoices` creates `CustomerInvoices` before
  `CustomerInvoiceLines` (parent before FK target).
- **Deliberate list/detail asymmetry**: the list returns
  `PagedResult<CustomerInvoiceSummaryDto>` (no `Lines`, `Subtotal`, `TaxAmount`, payment or
  void fields) while detail/create/payment/void return the full `CustomerInvoiceDto`. Hence
  two Dart models, `CustomerInvoiceSummary` and `CustomerInvoice`. Do not "fix" this in the
  client. `CustomerInvoiceStatus` serializes as an **integer** (no
  `JsonStringEnumConverter` is registered), so the client sends `status.code` in query
  strings for the same reason.
- **Flutter capabilities**: `features/capabilities/` (domain `WorkspaceModule`, DAO in the
  existing `MetaEntries` table — **no migration** — repository, controller,
  `enabledModulesProvider`). Cached copies are honoured only until `validOfflineUntil` and
  this check is deliberately **not** skipped for full-access tenants; on expiry the app
  falls back to the backstop set rather than either everything (unpaid modules) or nothing
  (locked-out cashier). `CapabilitiesState.source` drives the stale banner.
- **Navigation**: `More` entries are per-module gated; primary tabs now too — `_NavDest`
  carries an optional `WorkspaceModule`, locked tabs show a lock badge, tapping routes to
  billing (if `Billing.Manage`) or `/module-locked`, and a locked tab renders a placeholder
  instead of the real page because `IndexedStack` builds children eagerly. Tab **indices are
  stable** (never filter the list) because `Routes.pos` and `_MoreTab.onNavigateToTab` use
  raw indices. Of the primary tabs only Reports can be locked; Products/POS are backstops.
- **Duplicate fetch removed**: login used to call both `/billing/subscription` and
  `/capabilities`, which write the same `SubscriptionEntitlement`. `/capabilities` is a
  strict superset, so it is now the single login fetch and the subscription endpoint is only
  a fallback when capabilities yields nothing. `setEntitlement` bumps the controller
  revision, so a late subscription response cannot clobber newer capability state.
- **Errors + sync**: `ModuleDisabledException` (carries `module`) and
  `QuotaExceededException` added; `error_mapper` recognises `ModuleDisabled`,
  `BillingRequired`, `QuotaExceeded`, `AccountNotVerified` and parses the `module`
  extension. A queued op refused with `ModuleDisabled` fails terminally as
  `MODULE_DISABLED`; one refused with `BillingRequired` is **released unattempted** (no
  attempt burned) so it retries after payment; `QuotaExceeded` fails as `QUOTA`.
  `SyncOutcome` exposes `moduleDisabled` / `billingRequired`.
- **POS is deliberately not capability-gated.** The M5 `offlineWindowOpen()` session-journal
  control is an authentication/security window, not an entitlement check, and stays
  untouched — a cashier must never be locked out of taking money.
- **Localization blocker found and fixed**: the committed generated localizations were
  badly stale (363 ARB keys missing, 295 of them referenced from `lib/`, e.g.
  `suppliersTitle`, `userFormTitleAdd`, `billingBackstopMessage`) — the app could not
  compile without regeneration. Pre-existing since commit `5f6db83`, not caused by this
  slice. Resolved with `flutter gen-l10n`; ARB is the source of truth, so edit
  `app_en.arb` / `app_sw.arb` and regenerate rather than hand-patching
  `lib/l10n/generated/`.
- **Tests written (unrun)**: backend — `ModuleRouteMapTests`, `CustomerInvoiceTests`,
  `ModulePackagesTests`; Flutter — billing controller test fake now implements
  `activatePackage` / `removePackage`.
- **Pending verification (user-run)**: `dotnet build`, `dotnet test
  backend/tests/BusinessOS.Tests`, the `AddCustomerInvoices` migration against Postgres,
  `dart format`, `flutter analyze`, `flutter test`. Everything above was reviewed by
  static reading; the only command run in this slice was `flutter gen-l10n`.

## Mx Catch-up commit pass (done 2026-10-05)

~5 weeks of uncommitted work (M9.2→M13.2, 400+ paths) committed as 4 thematic
commits: `b448cb8` repo hygiene, `7507e24` backend, `28d766c` Flutter client,
`e5217ac` docs. **Real defects found by the first-ever build/analyze of the
code-only milestones:** missing `auth_controller.dart` import in
`two_factor_page.dart` (`AuthNeedsTwoFactor` undefined — analyze error);
`.AsTask()` on an already-`Task` `AddRangeAsync` (PlatformRepositories);
`BinaryPrimitives.WriteInt64BigEndian` void assigned to `var` (TotpService);
two test stubs missing `IRefreshTokenRepository.ListActiveByUserAsync`.
All fixed minimally. **Verified:** `dotnet build --warnaserror` clean
(0/0), `flutter analyze` 0 issues, dart format applied, gen-l10n in sync.
**NOT run (user decision):** `dotnet test` (unit + integration), `flutter test`.
Running both suites is the immediate next task — M13/M13.1/M13.2 logic has
never been executed by any test.

## Mx First-ever full verification of M9.2→M13.2 (done 2026-10-05)

First complete test pass over the code-only milestones. Flutter: 31 failures →
**493/493 green**. Backend: 161 failures → targeted batches green (receipt+TOTP
25/25); full-suite re-run in progress at push time.

**Real production bugs found (the suites earned their keep):**
1. **`RegisterUserCommand` never seeded `FeatureFlag` rows** — every self-registered
   tenant got an empty entitlement intersection, so ALL module-gated writes
   (products/sales/inventory…) 403'd even during the full-access trial. Masked for
   weeks because integration tests failed earlier at the login parse. Fixed by
   mirroring `TenantProvisioningCommands`' flag seeding (`FeatureKeys.All`, enabled).
2. **`BusinessIdentitySnapshot` not deserializable** — private ctor invisible to the
   source-gen `JsonContext` → receipt reprints 500. Now `internal` + `[JsonConstructor]`.
3. **`SeedDefaultLayout` returned a bare JSON string**; client+tests expect `{ value }`
   → now returns `SeedDefaultLayoutResult`.
4. **Branch-cache secure-storage read could hang checkout forever** (wedged keystore;
   in tests the plugin never answers). Now best-effort: 2s timeout + API fallthrough.
5. **Expenses `hasMore` used page size vs total** → infinite pagination. Now offset-based.

**Test-side drift:** login envelope (`tokens.*`) updated across 14 backend test
files (`LoginResponse` replaced flat `AuthResponse` at login; refresh stays flat);
Flutter — stale quick-sale payloads (decimal qty + `productName`, matches backend),
locale default now device-locale w/ Swahili fallback (`resolveDeviceLocale` seam),
router onboarding-complete gate coverage, UI-drift assertions (Jumla ×2, Fedha,
wifi_off indicator, price ×3), missing fakes (`_FakeBranchCache`,
`_FakeAuthController`, `_FakeStockController`), theme extension in widget host,
billing fixture omit-switch, TOTP test missing `$` interpolation, inverted
`isReprint` expectation (preview semantic = printCount > 0). Load-flake candidates
(register 500s, Npgsql timeouts) noted on the 2h40m run — watch on re-runs.

## technical_debt.md

- Flutter app: SharedPreferences + in-memory mocks still drive auth/products/sales; Drift DB
  (11 tables) is built but disconnected from the running app.
- Swagger UI shows no Authorize button: the top-level OpenAPI `security` requirement
  serializes as `{}` (Bearer scheme IS declared; runtime 401/403 enforcement proven). Do not
  redesign platform-wide Swagger config unless asked — recorded in Task 006 report.
- Dev DB `businessos` may contain smoke-test users; `businessos_test` is recreated per run.
- Roadmap checkboxes marked `[x]` for Phase 0 are aspirational — many are now real (see
  "architecture.md" above).
