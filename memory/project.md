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
  `tasks/sales-pos/TASKS.md`. **Localization strategy (locked):** core never references a
  country; selection is data-driven via `TaxRule.CalculationStrategyKey` (`Simple` fallback in
  `DefaultPercentageTaxStrategy`; `TZ_DUAL_VAT` in `Localizations/Tanzania/Tax/TzDualVatTaxStrategy`).
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

## coding.md — see `docs/CodingStandards.md`

## api.md — see `docs/APIStandards.md`

## database.md — see `docs/TechStack.md` + ADR-0002/0008

- Local: podman postgres:17, db `businessos`, user `businessos`, password `Joseph662.`
  (trailing period is part of the password), port 5432. Redis `localhost:6379`, MinIO
  `localhost:9000/9001`. Test DB: `businessos_test`.

## ux.md — product principles

- Mobile-first, one-hand usable, works on cheap Android, offline-first.
- Swahili + English localization first-class. Large tap targets for POS.
- Guided onboarding < 10 min. Every screen earns its place.

## branding.md

- Product name: **Business OS**. Flutter package: `business_management_system`.
- Goal tone: trustworthy, simple, local. (Full brand guide deferred.)

## known_issues.md

- System Postgres 17 `postgres` password unknown → we use our own container DB (ADR-0009).
- Redis/minio binaries not installed → containers.
- Integration tests need real Postgres on `localhost:5432` → CI runs unit tests only.
- Success `Result<T>` endpoints return **200**, not 201 (platform `ToApiResult` convention) —
  documented in the Organizations & Branches spec.

## technical_debt.md

- Flutter app: SharedPreferences + in-memory mocks still drive auth/products/sales; Drift DB
  (11 tables) is built but disconnected from the running app.
- Swagger UI shows no Authorize button: the top-level OpenAPI `security` requirement
  serializes as `{}` (Bearer scheme IS declared; runtime 401/403 enforcement proven). Do not
  redesign platform-wide Swagger config unless asked — recorded in Task 006 report.
- Dev DB `businessos` may contain smoke-test users; `businessos_test` is recreated per run.
- Roadmap checkboxes marked `[x]` for Phase 0 are aspirational — many are now real (see
  "architecture.md" above).
