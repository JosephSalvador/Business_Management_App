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
  implemented & verified; 3d (final docs + release checkpoint, task 029) pending.

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
