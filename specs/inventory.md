# Feature Spec — Inventory Operations (Slice 7)

> Phase 1, seventh slice (roadmap item 7). Builds on the Inventory Foundation (Slice 3b):
> warehouses, stock locations, opening stock, and the immutable ledger already exist. This slice
> adds the operational workflows that real shops need daily: adjustments, transfers, and physical
> stock counts.
>
> **Sub-slices:** 7a Stock Adjustments → 7b Stock Transfers → 7c Stock Counts → 7d Batch/Lot
> Tracking → 7e Tests + docs + commit.
>
> **Status: not started.**

## Feature

Stock **adjustments** (correcting discrepancies), **transfers** (moving stock between
warehouses/locations), **physical counts** (cycle counting and reconciliation), and **batch/lot
tracking** (traceability by production batch). These are the day-to-day inventory operations that
real shops, warehouses, and distribution centers perform constantly.

## Purpose

Roadmap item #7 "Inventory" — extending the foundation built in Slice 3b. Until now the only
ways to change stock are opening stock (one-time) and sales (decrement). Real businesses need to:

- **Adjust** stock when they find discrepancies (damaged goods, shrinkage, miscounts)
- **Transfer** stock between warehouses or locations (branch-to-branch, backroom-to-shelf)
- **Count** stock physically and reconcile with the system (cycle counts, annual inventory)
- **Track batches** for expiry-sensitive goods (pharmaceuticals, food, agriculture)

Follows the established slice pattern. The `Modules/` project stays untouched.

## Business rules

### Stock Adjustments

- An **adjustment** corrects the stock balance for a specific product/variant at a specific
  location. It may be positive (found extra stock) or negative (damaged/shrinkage/lost).
- An adjustment **must not** drive the balance below zero. Negative adjustments that would
  exceed the current quantity are rejected (`Validation`, HTTP 400).
- Every adjustment is recorded as a `StockMovement` with type `Adjustment` and a `Reason`
  (required, max 500 chars). The `Quantity` is signed: positive = increase, negative = decrease.
- Adjustments are **never retroactive** — they take effect at the `EffectiveAt` timestamp
  provided (must be ≤ UtcNow + 5 min skew window).
- Adjustments are auditable (who, when, what changed) and create an outbox domain event
  (`StockAdjustedEvent`).
- Adjustments are a **single-location operation** — one product/variant at one
  warehouse/location per command. Batch adjustments (multiple lines) are a future improvement.

### Stock Transfers

- A **transfer** moves stock from one warehouse/location (source) to another (destination).
  Source and destination may be in the same warehouse (inter-location) or different warehouses
  (inter-warehouse).
- Transfer **source ≠ destination** (same warehouse+location is a no-op → `Validation`).
- The source balance must have **sufficient quantity** for every transferred line. If any line
  is insufficient, the whole transfer is rejected with zero movements written (atomic
  all-or-nothing, same pattern as sales).
- A transfer creates **two** `StockMovement` rows in one transaction: `TransferOut` (negative
  quantity at source) and `TransferIn` (positive quantity at destination). Both reference the
  same `TransferId` via `ReferenceType = "Transfer"` and `ReferenceId`.
- Transfers may carry multiple lines (different products/variants in one transfer request).
- Transfers are **pending** until confirmed. `TransferStatus` = `Pending | Completed | Cancelled`.
  - `Pending`: stock is **not yet moved** (no movements written). The transfer is a planned
    intent.
  - `Completed`: source debited, destination credited, two movements written, balances updated.
  - `Cancelled`: no-op (if pending) or compensating movements (if already completed — deferred
    to a future slice; cancel only works on `Pending` transfers in this slice).
- A transfer may optionally reference a `PurchaseOrderId` or `SaleId` for traceability.
- Transfers are auditable and create `StockTransferredEvent` on completion.

### Stock Counts (Physical / Cycle Counts)

- A **stock count** records the physical quantity observed for a product/variant at a specific
  location. It compares the counted quantity against the system quantity and generates an
  adjustment if they differ.
- A count is a **single-location operation** — one product/variant at one warehouse/location.
- `CountStatus` = `Draft | Completed | Cancelled`.
  - `Draft`: the count is recorded but **no movement is written**. The operator can review
    before committing.
  - `Completed`: the difference (counted − system) is applied as an `Adjustment` movement
    (positive or negative). If the difference is zero, no movement is written.
  - `Cancelled`: the count is discarded with no side effects.
- The system quantity at count time is a **snapshot** — it is the balance at the moment
  `CompleteAsync` is called, not the balance at draft creation. This prevents drift between
  draft and completion.
- Counts are auditable and create `StockCountCompletedEvent` (with `systemQuantity`,
  `countedQuantity`, `difference`).

### Batch / Lot Tracking

- A **batch** (lot) groups stock units by production batch, expiry date, or supplier lot.
  Batches are optional — products without batch tracking work exactly as before.
- `StockMovement` gains nullable `BatchId?` and `BatchNumber?` fields. When batch tracking is
  enabled for a product, every movement **must** reference a batch.
- A **`StockBatch`** entity belongs to one tenant and tracks:
  - `BatchNumber` (unique per product per tenant — e.g. `"EXP-2026-001"`)
  - `ProductId`, `VariantId?`
  - `ManufacturerDate?`, `ExpiryDate?`
  - `SupplierId?` (forward reference to Purchasing)
  - `Notes?`
  - `IsActive` (default true — exhausted batches are deactivated, never deleted)
- Stock balances gain an optional `BatchId?` — when batch tracking is enabled, balances are
  keyed by `(warehouse, location, product, variant?, batch?)`. Without batch tracking, `BatchId`
  is null (backward compatible).
- `StockBalance` uniqueness is extended: the functional unique index adds `COALESCE(BatchId,
  '<empty>')` to the key.
- **Expiry validation:** when creating a batch with an `ExpiryDate`, the date must be in the
  future. Deactivating an expired batch is allowed (it may still have residual stock from
  earlier movements).
- Batches are **never hard-deleted** — deactivated batches remain for historical traceability.

### StockMovementType enum additions

```csharp
public enum StockMovementType
{
    OpeningStock = 0,
    Sale = 1,
    SaleVoid = 2,
    Adjustment = 3,      // 7a
    TransferIn = 4,      // 7b
    TransferOut = 5,     // 7b
    Count = 6,           // 7c (only when difference ≠ 0)
}
```

### Existing rules preserved

- Balances **never go negative** (enforced by `StockBalance.Apply()`).
- The ledger is **immutable** — append-only, no edits, no deletes.
- Concurrent movements on the same unit+location are serialized via `SELECT ... FOR UPDATE`
  on the balance row.
- `StockMovement.Record()` validates quantity direction per type.

## Screens (Flutter)

None in this slice (API-first). Follow-up: adjustment/transfer/count screens in the inventory
management section of the Flutter app.

## API (backend)

All authenticated (`Bearer`), versioned `/api/v1`, rate-limited by the `global` policy,
tenant-scoped. Failures: RFC 7807 `ProblemDetails` with stable `code` (`Validation`,
`NotFound`, `Conflict`, `Unauthorized`, `Forbidden`). Mutations return `200` (platform
`ToApiResult` convention).

### Stock Adjustments

| Method | Route | Permission | Body / Query | Success |
|---|---|---|---|---|
| POST | `/api/v1/inventory/stock/adjustments` | `Inventory.Manage` | `AdjustStockRequest` | 200 `StockBalanceDto` |

`AdjustStockRequest` = `{ warehouseId, locationId?, productId, variantId?, quantityDelta,
reason, effectiveAt }`.

- `quantityDelta`: signed decimal. Positive = increase, negative = decrease. Must not drive
  balance below zero.
- `reason`: required, max 500 chars.
- `effectiveAt`: must be ≤ UtcNow + 5 min.

### Stock Transfers

| Method | Route | Permission | Body / Query | Success |
|---|---|---|---|---|
| POST | `/api/v1/inventory/transfers` | `Inventory.Manage` | `CreateTransferRequest` | 200 `TransferDto` |
| GET | `/api/v1/inventory/transfers/{id}` | `Inventory.View` | — | 200 `TransferDto` |
| GET | `/api/v1/inventory/transfers` | `Inventory.View` | `?page&pageSize&status&warehouseId&from&to` | 200 `PagedResult<TransferDto>` |
| POST | `/api/v1/inventory/transfers/{id}/complete` | `Inventory.Manage` | — | 200 `TransferDto` |
| POST | `/api/v1/inventory/transfers/{id}/cancel` | `Inventory.Manage` | — | 200 `TransferDto` |

`CreateTransferRequest` = `{ sourceWarehouseId, sourceLocationId?, destinationWarehouseId,
destinationLocationId?, lines [{ productId, variantId?, quantity, batchId? }],
referenceType?, referenceId?, reason? }`.

`TransferDto` = `{ id, status, sourceWarehouseId, sourceLocationId, destinationWarehouseId,
destinationLocationId, lines [{ productId, variantId?, quantity, batchId? }], referenceType?,
referenceId?, reason?, createdBy, createdAt, completedAt?, cancelledAt? }`.

- `POST /complete`: validates sufficient stock at source, writes `TransferOut` + `TransferIn`
  movements, debits source balances, credits destination balances, sets status = `Completed`.
- `POST /cancel`: only allowed on `Pending` transfers (no-op). Returns `Conflict` if
  `Completed`.

### Stock Counts

| Method | Route | Permission | Body / Query | Success |
|---|---|---|---|---|
| POST | `/api/v1/inventory/counts` | `Inventory.Manage` | `CreateCountRequest` | 200 `StockCountDto` |
| GET | `/api/v1/inventory/counts/{id}` | `Inventory.View` | — | 200 `StockCountDto` |
| GET | `/api/v1/inventory/counts` | `Inventory.View` | `?page&pageSize&status&warehouseId` | 200 `PagedResult<StockCountDto>` |
| POST | `/api/v1/inventory/counts/{id}/complete` | `Inventory.Manage` | — | 200 `StockCountDto` |
| POST | `/api/v1/inventory/counts/{id}/cancel` | `Inventory.Manage` | — | 200 `StockCountDto` |

`CreateCountRequest` = `{ warehouseId, locationId?, productId, variantId?, countedQuantity,
notes? }`.

`StockCountDto` = `{ id, status, warehouseId, locationId, productId, variantId?,
systemQuantity, countedQuantity, difference, notes, createdBy, createdAt, completedAt?,
cancelledAt? }`.

- `POST /complete`: snapshots the current system balance, computes `difference = counted −
  system`. If difference ≠ 0, writes an `Adjustment` movement. Sets status = `Completed`.
- `POST /cancel`: only allowed on `Draft` counts. Returns `Conflict` if `Completed`.

### Batch/Lot Tracking

| Method | Route | Permission | Body / Query | Success |
|---|---|---|---|---|
| POST | `/api/v1/inventory/batches` | `Inventory.Manage` | `CreateBatchRequest` | 200 `StockBatchDto` |
| GET | `/api/v1/inventory/batches/{id}` | `Inventory.View` | — | 200 `StockBatchDto` |
| GET | `/api/v1/inventory/batches` | `Inventory.View` | `?page&pageSize&productId&isActive` | 200 `PagedResult<StockBatchDto>` |
| PATCH | `/api/v1/inventory/batches/{id}/status` | `Inventory.Manage` | `{ isActive }` | 200 `StockBatchDto` |

`CreateBatchRequest` = `{ batchNumber, productId, variantId?, manufacturerDate?,
expiryDate?, supplierId?, notes? }`.

`StockBatchDto` = `{ id, batchNumber, productId, variantId?, manufacturerDate?, expiryDate?,
supplierId?, notes, isActive, createdAt, updatedAt? }`.

- `batchNumber` unique per (tenant, product, variant?) → `Conflict` if duplicate.
- `expiryDate` must be in the future (at creation time).
- `PATCH /status` activates or deactivates (soft toggle).

### Existing endpoints (unchanged)

All existing warehouse, stock balance, stock movement, and opening stock endpoints from Slice
3b remain unchanged and are not re-listed here. See `specs/products-inventory.md`.

## Database

New tables (public schema, `TableNames` constants added):

- **`Transfers`**: tenant, `source_warehouse_id`, `source_location_id?`,
  `destination_warehouse_id`, `destination_location_id?`, `status` (enum int), `reference_type?`,
  `reference_id?`, `reason?`, `created_by`, `completed_at?`, `cancelled_at?`, audit columns.
- **`TransferLines`**: FK transfer (cascade), product_id, variant_id?, quantity (decimal > 0),
  batch_id?, audit columns.
- **`StockCounts`**: tenant, warehouse_id, location_id?, product_id, variant_id?,
  `counted_quantity` (decimal ≥ 0), `system_quantity` (decimal, snapshot at completion),
  `difference` (decimal, computed at completion), `status` (enum int), `notes?`, `created_by`,
  `completed_at?`, `cancelled_at?`, audit columns.
- **`StockBatches`**: tenant, product_id, variant_id?, `batch_number`, `manufacturer_date?`,
  `expiry_date?`, `supplier_id?` (nullable FK, forward reference), `notes?`, `is_active`
  (default true), audit columns. Unique `(TenantId, ProductId, COALESCE(VariantId), BatchNumber)`.

Altered tables:

- **`StockMovements`**: gains nullable `batch_id?` (FK `StockBatches`, `Restrict`).
- **`StockBalances`**: gains nullable `batch_id?` (FK `StockBatches`, `Restrict`). Functional
  unique index updated to include `COALESCE(BatchId, '<empty>')`.

New enums:

- `TransferStatus` { `Pending = 0`, `Completed = 1`, `Cancelled = 2` }
- `CountStatus` { `Draft = 0`, `Completed = 1`, `Cancelled = 2` }

All new tables carry UUID PK + `CreatedAt`/`CreatedBy` + `UpdatedAt`/`UpdatedBy`.

Migration: `AddInventoryOperations` (one migration for all sub-slices, applied once at the
end).

## Validation

- Adjustment: `quantityDelta ≠ 0`; `reason` required ≤ 500; `effectiveAt` ≤ UtcNow + 5 min;
  product must be `Active` type `Product`; variant belongs to product; sellable-unit key
  consistency; resulting balance ≥ 0.
- Transfer: source ≠ destination (warehouse+location); each line quantity > 0; product must be
  `Active` type `Product`; variant belongs to product; sellable-unit key consistency; source
  stock sufficient at completion time.
- Count: `countedQuantity ≥ 0`; product must be `Active` type `Product`; variant belongs to
  product; sellable-unit key consistency.
- Batch: `batchNumber` required ≤ 100; `productId` required; `expiryDate` must be in the
  future (at creation); batch number unique per (tenant, product, variant) → `Conflict`.

## Permissions

No new permissions. All operations use existing `Inventory.View` / `Inventory.Manage` from
Slice 3b. The seeder already grants these to admin roles.

## Events

Outbox-backed, consumed by `InventoryActivityFeedHandler`:

- **`StockAdjustedEvent`** (7a): `{ EventId, OccurredAt, StockMovementId, TenantId, BranchId,
  WarehouseId, ProductId, VariantId?, QuantityDelta, Reason, CreatedBy }`.
- **`StockTransferredEvent`** (7b): `{ EventId, OccurredAt, TransferId, TenantId,
  SourceWarehouseId, DestinationWarehouseId, Lines [{ ProductId, VariantId?, Quantity }],
  CreatedBy }`.
- **`StockCountCompletedEvent`** (7c): `{ EventId, OccurredAt, CountId, TenantId, WarehouseId,
  ProductId, VariantId?, SystemQuantity, CountedQuantity, Difference, CreatedBy }`.
- **`StockBatchCreatedEvent`** (7d): `{ EventId, OccurredAt, BatchId, TenantId, ProductId,
  VariantId?, BatchNumber, ExpiryDate?, CreatedBy }`.

## Reports

- Dashboard gains low-stock alerting from stock balances (already exists in Slice 5).
- Future: stock valuation report (quantity × cost), batch expiry report, transfer history
  report. Deferred to the Reporting slice.

## Tests

- **Unit:**
  - Adjustment: positive/negative delta, no-negative-balance guard, reason required.
  - Transfer: source ≠ destination, sufficient stock, atomic all-or-nothing, multi-line.
  - Count: draft → complete with positive/zero/negative difference, cancel draft, conflict on
    complete-already-completed.
  - Batch: unique batch number per product, expiry validation, deactivation, batch on balance
    key.
  - `StockMovement.Record()` validation for new types (`Adjustment` sign, `TransferIn`
    positive, `TransferOut` negative).
- **Integration** (WebApplicationFactory vs `businessos_test`):
  - Adjustment happy path: adjust → balance changes, movement written, audit row, event.
  - Adjustment insufficient stock → 400, zero movements, zero balance change.
  - Transfer happy path: source −5, destination +5, two movements, both balances updated.
  - Transfer insufficient stock → 400, zero movements, zero balance change.
  - Count draft → complete (difference > 0) → adjustment movement, balance updated.
  - Count draft → complete (difference = 0) → no movement, balance unchanged.
  - Count complete already → Conflict; cancel non-draft → Conflict.
  - Batch creation → balance with batch → movement with batch.
  - Tenant isolation (404); 403 for `Inventory.View`-only role.

## Offline & sync

Adjustments, transfers, and counts are **server-only** operations in this slice (no offline
queue). The Flutter app will send these commands over the network. Future: offline count
capture with sync-flush pattern (same as sales).

## Future improvements

- Batch adjustments (multiple lines in one command).
- Transfer cancellation after completion (compensating movements).
- Stock reservations (allow offline sell-now, reconcile-later).
- Reorder points / min-max alerts per product per warehouse.
- Multi-UoM conversions (1 Carton = 24 Pieces).
- Stock valuation report (weighted average / FIFO / moving average cost).
- Expiry alerts dashboard (batches expiring within N days).
- Barcode scanning for counts (scan product → enter quantity).
