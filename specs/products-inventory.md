# Feature Spec — Product & Inventory Foundation (Slice 3)

> Phase 1, fourth slice. Approval required before coding. Tasks in
> `tasks/products-inventory/TASKS.md`. Design-first: no Product/Inventory code until this spec
> and the task plan are approved.
>
> **Sub-slices:** 3a Product Catalog → 3b Inventory Foundation → 3c Pricing Engine → 3d Docs &
> verification. Built before Sales/POS so a sale always resolves a real product, price, tax,
> branch and stock.
>
> **Sub-slice status (3a Product Catalog): implemented & verified 2026-08-13** (tasks 001–009);
> 3b Inventory Foundation and 3c Pricing Engine are pending.

## Feature

Product Catalog, Inventory and Business Pricing — the commercial core every later module
(Sales/POS, Purchasing, Accounting) consumes. Answers: what do we sell, at what price per
branch, and how much do we have where.

## Purpose

Roadmap item #4 (Product & Inventory Foundation). The identity/admin layer (Slices 1–2a) and
the `Branch` hierarchy now exist; this slice puts the **merchandise and stock model** on top so
a sale can resolve: product → SKU/barcode → unit → price → branch → warehouse → stock. Per the
roadmap, products come **before** Sales/POS: a POS built on a weak product/inventory model would
have to be rebuilt.

Follows the established slice pattern (Domain → Application `Features/*` → Infrastructure
repositories → minimal-API endpoints under `/api/v1`), identical to Slices 1 and 2a. The
`Modules/*` project stays the documented future home if the monolith ever modularizes; this
slice does not invent new architecture.

## Business rules

### Product Catalog

- A **product** belongs to exactly one tenant. `ProductType` = `Product` (stocked) or
  `Service` (never stocked).
- `ProductStatus` = `Draft` | `Active` | `Inactive`. Only `Active` products are sellable and
  can carry stock.
- Optional `Sku` and `Barcode` are **globally unique per tenant** (partial unique index on
  non-null). Duplicate → `Conflict`.
- A **unit of measure (UoM)**, **category** and **brand** belong to one tenant; category and
  UoM names are unique per tenant. Category supports an optional `ParentId` (same tenant, no
  self-parent, no ancestor cycle).
- **Variants:** a product either sells itself (no variants) or via its variants (has variants).
  If a product has variants, product-level `Sku`/`Barcode` must be null (variants carry them);
  variant `Sku`/`Barcode` are unique per tenant.
- Product/variant updates are audited automatically; products are **deactivated, never
  hard-deleted** (`DELETE` = `Inactive`), consistent with branches and users.

### Inventory

- A **warehouse** belongs to one tenant and one branch (branch must belong to the tenant).
  `Code` normalized uppercase, unique per tenant.
- A warehouse owns **stock locations** (managed through the warehouse aggregate, like
  `UserBranch`). Creation auto-creates a default `Main` location. Location codes unique per
  warehouse.
- **Stock balances** are keyed by `(warehouse, location, product, variant?)`. A stocked product
  with variants holds stock per variant; without variants, on the product itself.
- The **stock ledger** (`StockMovement`) is immutable and append-only. Every balance change is
  a movement. `MovementType` = `Opening | Adjustment | TransferIn | TransferOut` (Sale/Purchase/
  Count join later from their own slices).
- Balances **never go negative**. Opening stock may only be recorded for a unit with no prior
  movements. Adjustments may be positive or negative but never take the balance below zero.
- A **transfer** debits the source and credits the destination (different warehouse or location)
  in one transaction; source quantity must be available.
- Concurrent movements on the same unit+location are serialized with `SELECT ... FOR UPDATE` on
  the balance row inside the mutation transaction (pattern: `TransactionBehavior` +
  `IRequiresTenantAdvisoryLock` from Slice 2a, extended with a row-lock on `StockBalance`).

### Pricing

- A **price list** belongs to one tenant, carries a currency (default = tenant currency), and
  may be `IsDefault` (at most one default per tenant, partial unique index). Name unique per
  tenant. Optional `EffectiveFrom`/`EffectiveTo` window.
- A **product price** resolves `(price list, product, variant?, branch?, price type)` →
  amount + currency + `MinQuantity`. `PriceType` = `Retail | Wholesale`.
  `BranchId = null` is the all-branch base price; a branch-specific price **overrides** the base
  for that branch only. Effective-dated rows are allowed; the resolver honours the window.
- **Price resolution** is a pure function: match active list → exact branch before all-branch →
  price type → rows whose `MinQuantity ≤ quantity` (highest `MinQuantity` wins) → latest
  `EffectiveFrom` as tie-break. No price → no price (sale cannot resolve a price).
- Customer-specific pricing, discount rules and multi-UoM conversions are **deferred** (need
  Customers and the Sales slice).

## Screens (Flutter)

None in this slice (API-first, like Slices 1–2a). Catalog/inventory/POS screens are later
phases; `GET /api/v1/products` and `/api/v1/inventory/stock` are the future offline sync
sources.

## API (backend)

All authenticated (`Bearer`), versioned `/api/v1`, rate-limited by the `global` policy, tenant-
scoped. Failures: RFC 7807 `ProblemDetails` with stable `code` (`Validation`, `NotFound`,
`Conflict`, `Unauthorized`, `Forbidden`). Mutations return `200` (platform `ToApiResult`
convention); `DELETE` → `204`.

### Products

| Method | Route | Permission | Body / Query | Success |
|---|---|---|---|---|
| GET | `/api/v1/products` | `Products.View` | `?page&pageSize&search&categoryId&brandId&status&type` | 200 `PagedResult<ProductDto>` |
| GET | `/api/v1/products/{id}` | `Products.View` | — | 200 `ProductDto` |
| POST | `/api/v1/products` | `Products.Create` | `CreateProductRequest` | 200 `ProductDto` |
| PUT | `/api/v1/products/{id}` | `Products.Update` | `UpdateProductRequest` | 200 `ProductDto` |
| PATCH | `/api/v1/products/{id}/status` | `Products.Update` | `{ status }` | 200 `ProductDto` |
| DELETE | `/api/v1/products/{id}` | `Products.Delete` | — | 204 |
| GET | `/api/v1/products/{id}/variants` | `Products.View` | — | 200 `List<ProductVariantDto>` |
| PUT | `/api/v1/products/{id}/variants` | `Products.Update` | `{ variants[] }` | 200 `List<ProductVariantDto>` |

`ProductDto` = id, tenantId, name, description, sku, barcode, categoryId, brandId, unitOfMeasureId,
productType, status, variants, createdAt, updatedAt. Sellable = status `Active`.

### Catalog reference data

| Method | Route | Permission | Success |
|---|---|---|---|
| GET/POST | `/api/v1/categories` · GET/PUT | `/api/v1/categories/{id}` | `Categories.View/Manage` | 200 |
| GET/POST | `/api/v1/brands` · GET/PUT | `/api/v1/brands/{id}` | `Brands.View/Manage` | 200 |
| GET/POST | `/api/v1/units` · GET/PUT | `/api/v1/units/{id}` | `Units.View/Manage` | 200 |

### Warehouses & stock

| Method | Route | Permission | Body / Query | Success |
|---|---|---|---|---|
| GET | `/api/v1/warehouses` | `Warehouses.View` | `?page&pageSize&branchId` | 200 `PagedResult<WarehouseDto>` |
| GET | `/api/v1/warehouses/{id}` | `Warehouses.View` | — | 200 `WarehouseDto` |
| POST | `/api/v1/warehouses` | `Warehouses.Create` | `CreateWarehouseRequest` | 200 `WarehouseDto` |
| PUT | `/api/v1/warehouses/{id}` | `Warehouses.Update` | `UpdateWarehouseRequest` | 200 `WarehouseDto` |
| PATCH | `/api/v1/warehouses/{id}/status` | `Warehouses.Update` | `{ isActive }` | 200 `WarehouseDto` |
| DELETE | `/api/v1/warehouses/{id}` | `Warehouses.Delete` | — | 204 |
| GET | `/api/v1/inventory/stock` | `Inventory.View` | `?page&pageSize&warehouseId&productId&search` | 200 `PagedResult<StockBalanceDto>` |
| GET | `/api/v1/inventory/movements` | `Inventory.View` | `?page&pageSize&warehouseId&productId&type` | 200 `PagedResult<StockMovementDto>` |
| POST | `/api/v1/inventory/stock/opening` | `Inventory.Manage` | `{ warehouseId, locationId?, productId, variantId?, quantity, effectiveAt }` | 200 `StockBalanceDto` |
| POST | `/api/v1/inventory/stock/adjustments` | `Inventory.Manage` | `{ warehouseId, locationId?, productId, variantId?, quantityDelta, reason, effectiveAt }` | 200 `StockBalanceDto` |
| POST | `/api/v1/inventory/stock/transfers` | `Inventory.Manage` | `{ fromWarehouseId, fromLocationId?, toWarehouseId, toLocationId?, productId, variantId?, quantity, reference }` | 200 |

`WarehouseDto` = id, tenantId, branchId, branchName, name, code, isActive, locations, createdAt.
`StockBalanceDto` = warehouseId, locationId, productId, variantId?, quantity. `StockMovementDto`
= id, type, quantityDelta, reason, effectiveAt, createdBy, createdAt.

### Pricing

| Method | Route | Permission | Body / Query | Success |
|---|---|---|---|---|
| GET | `/api/v1/price-lists` | `Pricing.View` | — | 200 `List<PriceListDto>` |
| POST | `/api/v1/price-lists` | `Pricing.Manage` | `CreatePriceListRequest` | 200 `PriceListDto` |
| GET | `/api/v1/price-lists/{id}` | `Pricing.View` | — | 200 `PriceListDto` |
| PUT | `/api/v1/price-lists/{id}` | `Pricing.Manage` | `UpdatePriceListRequest` | 200 `PriceListDto` |
| GET | `/api/v1/price-lists/{id}/prices` | `Pricing.View` | `?productId&branchId&priceType` | 200 `List<ProductPriceDto>` |
| PUT | `/api/v1/price-lists/{id}/prices` | `Pricing.Manage` | `{ prices[] }` bulk upsert | 200 `List<ProductPriceDto>` |
| GET | `/api/v1/pricing/resolve` | `Pricing.View` | `?productId&variantId&branchId&priceType&quantity&onDate` | 200 `ResolvedPriceDto` |

`PriceListDto` = id, tenantId, name, currency, isDefault, isActive, effectiveFrom, effectiveTo.
`ProductPriceDto` = priceListId, productId, variantId?, branchId?, priceType, price, currency,
minQuantity, effectiveFrom, effectiveTo, isActive. `ResolvedPriceDto` = price, currency,
priceListId, priceType, minQuantity.

## Database

New bounded contexts in the `TableNames` catalog (`Schemas` stay `public`):

- **Catalog:** `ProductCategories`, `Brands`, `UnitsOfMeasure`, `Products`,
  `ProductVariants`. `Products.Sku`/`Barcode` partial unique (per tenant, non-null);
  `ProductVariants` partial unique on tenant+sku/barcode; FK to tenant-scoped references.
- **Inventory:** `Warehouses` (unique `(TenantId, Code)`), `StockLocations` (unique
  `(WarehouseId, Code)`), `StockBalances`, `StockMovements`. `StockBalances` unique
  `(TenantId, WarehouseId, LocationId, ProductId, COALESCE(VariantId, '<empty>'))` functional
  unique index; `StockMovements` index on `(TenantId, ProductId, CreatedAt)`.
- **Pricing:** `PriceLists` (unique `(TenantId, Name)` + partial unique on default),
  `ProductPrices` (unique `(PriceListId, ProductId, COALESCE(VariantId), COALESCE(BranchId),
  PriceType)`).

All tables carry UUID PK + `CreatedAt`/`CreatedBy` + `UpdatedAt`/`UpdatedBy` (EF conventions),
map `ToTable(name, schema)` via `Tables`/`Schemas`, and are tenant-scoped like every existing
table. Migration: `20260813_AddProductInventoryAndPricing`.

## Validation

- Product: name required ≤ 200; category/brand/uom must exist in tenant; sku/barcode per-tenant
  unique → `Conflict`; sku/barcode null when variants present; type/status enum.
- Category: name required ≤ 100, unique per tenant → `Conflict`; parent exists in tenant, not
  self, no ancestor cycle.
- Variants: at least one name; duplicate variant sku/barcode → `Conflict`.
- Warehouse: name required ≤ 200; code required ≤ 20, normalized uppercase, unique per tenant →
  `Conflict`; branch exists in tenant.
- Stock: product must be `Product` type and `Active`; opening only when no prior movements;
  adjustments/transfers must not drive balance below zero (`Conflict`); transfer source ≠
  destination; location/warehouse belong to the tenant.
- Prices: price > 0; currency required (ISO 4217); price list + product exist in tenant;
  variant belongs to product; branch belongs to tenant; minQuantity ≥ 1; effective window
  `from ≤ to`; duplicate price key → `Conflict`.

## Permissions

New `PermissionNames` entries (seeder re-grants them to existing system `Administrator` roles
automatically, as in Slices 1–2a):

`Products.View/Create/Update/Delete`, `Categories.View/Manage`, `Brands.View/Manage`,
`Units.View/Manage`, `Warehouses.View/Create/Update/Delete`, `Pricing.View/Manage`.
Stock read/write reuse the existing `Inventory.View` / `Inventory.Manage`.

## Events

Outbox-backed, consumed by activity-feed handlers (`CatalogActivityFeedHandler`,
`InventoryActivityFeedHandler`, `PricingActivityFeedHandler`):

- `ProductCreatedEvent`, `ProductUpdatedEvent`, `ProductStatusChangedEvent`,
  `ProductVariantsChangedEvent`
- `OpeningStockRecordedEvent`, `StockAdjustedEvent`, `StockTransferredEvent`
- `PriceListCreatedEvent`, `PriceListUpdatedEvent`, `ProductPricesChangedEvent`

Future slices listen for `StockMovementRecorded`-style events (Sales reduces stock, Purchasing
increases it) without touching this slice.

## Reports

None in this slice. Stock balances and movements are the future inventory-report source.

## Tests

- **Unit:** product invariants (sku/barcode rule, variants replace), category cycle guard,
  warehouse code normalization + default location, stock ledger math (opening/adjust/transfer,
  no negative balance), price resolver (branch override, price type, min-quantity, effective
  dates, tie-break), system rules.
- **Integration** (WebApplicationFactory vs `businessos_test`): full product/category/brand/uom
  CRUD + status; duplicate sku → Conflict; variant assignment round-trip; warehouse + location
  CRUD; opening → balance; adjustment → balance; transfer → both balances; negative balance →
  Conflict; tenant isolation (404); 403 for read-only roles; audit rows for every mutation;
  outbox dispatch of catalog/inventory/pricing events.

## Offline & sync

`GET /api/v1/products`, `GET /api/v1/inventory/stock` and `GET /api/v1/pricing/resolve` are the
future device sync sources for the offline POS (product cache, stock view, price cache). Rows
carry `UpdatedAt` for the `updatedAt` server-wins conflict strategy. No Flutter/Drift changes in
this slice.

## Future improvements

- Product images (via existing `IFileStorage`) and barcode scanning in the POS phase.
- Customer-specific prices (deferred: needs the Customers slice), discount rules, price-change
  history/audit beyond platform audit.
- Multi-UoM conversions (base unit + conversion factors), physical stock counts (`Count`
  movement), batches/serial numbers.
- Stock reservations (deferred: needs Sales), reorder points, multi-warehouse reporting.
- Warehouse → its own `Modules/Catalog`/`Modules/Inventory` split if the monolith modularizes.
