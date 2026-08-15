# Feature Spec — Operational Dashboard (backend slice)

> Phase 1, fifth slice. Approval required before coding. Tasks in `tasks/dashboard/TASKS.md`.
> Design-first: no Dashboard code until this spec and the task plan are approved.
>
> **Scope:** the roadmap's item 5 "Dashboard — real aggregates from events (revenue, VAT, top
> products, receivables)" depends on a Sales domain that does not exist yet (`Modules.Sales` is
> an empty reference stub). This slice therefore ships the **Operational Dashboard** — real
> aggregates over the data that exists today (catalog, inventory, pricing, organization).
> Revenue/VAT/top-sellers/receivables are added when the Sales slice lands (future improvement).
>
> **Status: implemented & verified 2026-08-15** — all 5 tasks complete: ports + repository,
> application queries, API endpoints, unit + integration tests (full suite 236/236), docs &
> release checkpoint (changelog v0.6.0). Read-only slice; no migration, no events, no audit writes.

## Feature

One read-only `GET /api/v1/dashboard/*` surface returning the operational KPIs a shop owner
needs from the modules built so far — catalog health, stock position, pricing coverage and
organization size — plus a recent-activity feed and a low/zero-stock list. Pure read-model:
it queries existing tables, adds no domain logic, no mutations and no migration.

## Purpose

Give the Flutter app a real dashboard immediately after login (instead of hardcoded stats) by
answering: *how many products do I sell, which are active, what is my stock position, how many
products can actually be priced, and what happened recently*. Every number is computed server-side
per tenant from the source of truth, never cached-stale.

## Business rules

- Dashboard is **read-only**; it never mutates data, raises events, or writes audit rows.
- All KPIs are **tenant-scoped** (`TenantId = current tenant`); cross-tenant data is invisible.
- Every KPI is derived from existing aggregates/tables:
  - Catalog: `Products` by status (`Draft`/`Active`/`Inactive`) and type (`Product`/`Service`),
    total variants, categories, brands, units of measure.
  - Inventory: warehouses, stock-balance lines, `SUM(Quantity)` on hand, distinct stocked
    products, zero-stock lines, movement count.
  - Pricing: price lists (total + default name), distinct products with an active price in the
    default price list, distinct products with a branch override in the default price list.
  - Organization: branches, users, active users, roles.
- "Stocked product" = a product with `SUM(Quantity) > 0` across its balances; "zero-stock
  line" = a `StockBalance` row with `Quantity <= 0`.
- "Active price" = a `ProductPrice` row with `IsActive = true`, effective window covering
  today, in the tenant's default price list.
- Recent activity = the last N `AuditLog` rows for the tenant (mutation feed), newest first,
  joined to `Users` for the actor's email where available.
- Low stock = products ordered ascending by total on-hand quantity, with an optional
  `maxQuantity` threshold (default `0`, i.e. zero stock).
- Permissions: everything is gated with the existing `Dashboard.View` permission (already in
  `PermissionNames.All` and auto-granted to system admin roles by the seeder).

## Screens (Flutter)

Deferred to the Flutter follow-up (dashboards route already exists in the app). Not part of
this backend slice.

## API (backend)

All routes under `/api/v1/dashboard`, `RequirePermission(PermissionNames.DashboardView)`:

- `GET /api/v1/dashboard/summary` → `DashboardSummaryDto`
  - `catalog`: `totalProducts`, `activeProducts`, `draftProducts`, `inactiveProducts`,
    `serviceProducts`, `totalVariants`, `totalCategories`
  - `inventory`: `totalWarehouses`, `totalStockLines`, `totalOnHandUnits`, `stockedProducts`,
    `zeroStockLines`, `totalMovements`
  - `pricing`: `totalPriceLists`, `defaultPriceListName` (nullable), `activePriceProducts`,
    `branchOverrideProducts`
  - `organization`: `totalBranches`, `totalUsers`, `activeUsers`, `totalRoles`
  - `generatedAt`
- `GET /api/v1/dashboard/low-stock?maxQuantity=0&limit=20` → `DashboardLowStockDto`
  (`items: [{ productId, productName, sku, onHand }]`, sorted by `onHand` ascending)
- `GET /api/v1/dashboard/recent-activity?limit=20` → `DashboardActivityDto`
  (`items: [{ action, entityType, entityId, actorUserId, actorEmail, occurredAt }]`)

## Database

- **No migration.** Read-only queries over existing tables (`Products`, `ProductVariants`,
  `ProductCategories`, `Brands`, `UnitsOfMeasure`, `Warehouses`, `StockBalances`,
  `StockMovements`, `PriceLists`, `ProductPrices`, `Branches`, `Users`, `Roles`, `AuditLogs`).
- Queries are tenant-filtered; aggregation is done server-side (GROUP BY / SUM).

## Validation

- `maxQuantity` must be `>= 0`; `limit` must be `1..100` (defaults `0` / `20`).
- No other request payloads exist (GET only).

## Permissions

- `PermissionNames.DashboardView` (`"Dashboard.View"`) — already defined and seeded; used to
  gate all three endpoints.

## Events

- None consumed or raised (read-model slice). No notification/activity-feed handler needed.

## Reports

- This is the seed of the future Reports/Report-Builder engine; the summary snapshot is the
  reusable aggregation shape.

## Tests

- **Unit:** mapper/DTO projection tests (summary, low-stock, activity) — pure, no DB.
- **Integration** (real Postgres `businessos_test`):
  - Seed catalog (draft/active/service products + variants), opening stock, a default price
    list with prices (incl. one branch override + one inactive) → `summary` KPIs match.
  - `low-stock` returns the zero/low items ordered correctly; `maxQuantity` filter works.
  - `recent-activity` returns the tenant's mutation audit rows (newest first) with actor email.
  - 403 for a `Dashboard.View`-less role; tenant isolation (tenant B data never leaks).
  - No audit rows are written by dashboard reads (read-only).

## Offline & sync

- The Flutter dashboard will cache the last summary snapshot locally (follow-up); the backend
  endpoint is idempotent GET, no outbox entries.

## Future improvements

- Revenue, VAT, top sellers, receivables KPIs — when the Sales domain ships.
- Event-projected per-tenant activity-feed table (the outbox activity-feed handlers today only
  log; a materialized feed would be the source for recent-activity instead of AuditLogs).
- Stock value in currency (needs a cost/landed-cost field — not modelled yet).
- Time-series KPI history (snapshot per day) for trend charts.
