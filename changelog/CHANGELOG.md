# Changelog

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

### Docs
- Spec `specs/products-inventory.md` sub-slice 3a implemented & verified; tasks
  `tasks/products-inventory/TASKS.md` 001–009 ticked. Sub-slice 3b implemented & verified; tasks
  010–020 ticked. Sub-slice 3c (Pricing Engine) implemented & verified; tasks 021–028 ticked;
  `memory/project.md` updated. 3d (final docs & release checkpoint, task 029) remains.

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
