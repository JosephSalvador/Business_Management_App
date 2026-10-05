# Stock Management — Concrete Implementation Plan (small → big)

> State: **APPROVED — in implementation (decisions locked 2026-09-11).**
> One feature, one codebase, adaptive to tenant size — a kiosk and a distribution business
> share the same screens; complexity is revealed by data, never configured.
>
> **Navigation benchmarked against Square / Lightspeed / Loyverse** (retail-POS convention):
> Inventory is a **first-class section**; the hub is a **Stock Overview** (on-hand per item),
> multi-store gets a top **store/location selector**, search by **name / SKU / barcode**,
> **color-coded status** (in = green, low = yellow, out = red), sort options, and per-item
> actions (manage stock / transfer / history).

---

## 1. Diagnosis — why it feels like "nothing works"

The backend stock engine is **fully built and wired**: warehouses + locations + opening stock
(Slice 3b), adjustments/transfers/counts/batches (Slice 7), sales debit/void + low-stock KPIs
(Slices 5–6). The product gap is entirely on the client:

1. **`StockPage` is orphaned.** No route, tab, or menu reaches it (`router.dart`, `home_page.dart`).
   The bottom nav is Dashboard / Products / POS / Reports / More. The "Stock" tab from early
   milestones is gone.
2. **The controller destroys warehouses.** `stock_controller.dart:71-88` sums balances across
   warehouses into one number and labels every row "Main Store". A multi-shop owner cannot see
   what's where.
3. **No history, no transfers, no per-shop view** in the app at all.
4. **Stock entry is hard-coded** to the default warehouse (`add_stock_sheet.dart`,
   `opening_stock_sheet.dart`).
5. **Backend DTO gaps for a real UI:** `StockBalanceDto` has ids only (no names);
   `StockMovementDto` has no product/warehouse ids or names; `TransferLineDto.ProductName` is
   always `""` (`WarehouseMappers.cs:63`).

---

## 2. Market reality — who we are building for

| Segment | Reality | What matters most |
|---|---|---|
| **Kiosk / single shop** (Tanzania, Kenya, UG) | 1 shop, 1 warehouse ("Duka"), phone, often offline/low-bandwidth | See what's left, add stock, prove a sale/loss to an auditor. Never see "warehouse picker", "transfer", "count". |
| **Small retail, 2–5 shops** | few warehouses + a storeroom | Stock per shop, *move* stock from storeroom to a shop, low-stock per shop. |
| **Wholesale / distribution** | many warehouses + locations, staff, big catalog | Transfers, movement ledger for audit, per-location balances, staff with view-only roles, (phase 2) counts, batch expiry. |

**Design stance:** the backend already models all of this. The UI must *adapt*:
- **Single warehouse tenant → hide warehouse controls entirely.** Hub becomes a plain product
  list with on-hand qty. No pickers, no transfers, no locations.
- **Multi-warehouse tenant → reveal** the warehouse filter, per-warehouse rows, transfers.
- **Manager permission (`Inventory.Manage`) → reveal** add/adjust actions; **viewers
  (`Inventory.View`)** get read-only hub + history.

This is **progressive disclosure by data** — zero configuration, works for every customer.

**Adaptivity engine (pure function, no settings):**
```
scaleOf(warehouses) =
  single      if warehouses.length == 1        → hide: warehouse filter, transfers, locations
  multi       otherwise                         → show: warehouse filter, transfers, per-shop rows
canManage(permissions) = permissions.contains('Inventory.Manage')
```

---

## 3. Feature tiers

| | Tier 1 — Everyone | Tier 2 — Multi-warehouse | Tier 3 — Big ops (phase 2) |
|---|---|---|---|
| **Stock hub** | search, qty, low-stock highlight | warehouse filter, per-shop rows | + location + batch columns |
| **Product stock detail** | total + "add stock" | per-warehouse breakdown | + per-location + batch/expiry |
| **Movement history** | per product, type badge, reason, date | + warehouse filter | + date-range filter, export |
| **Transfers** | hidden | create → pending → complete/cancel, history | + multi-line, refs, batches |
| **Adjustments UI** | `add_stock_sheet` (positive only) | positive + negative with reason | + counts (draft→complete reconcile) |
| **Receiving** | existing `opening_stock_sheet` | + warehouse/location picker | + GRN-linked receiving |

Tier 2 items appear **only when the tenant has >1 warehouse**. Tier 3 is a documented later
phase (batches/counts already have backend + endpoints, no new backend work needed later).

---

## 4. Screens & flows (concrete)

### 4.1 Stock hub — `Routes.stock` (`/stock`)
Replaces the orphaned `StockPage`. Cache-first like the POS catalog:
- **Load:** read Drift `CachedStock` instantly (offline OK), then refresh from
  `GET /inventory/stock` in the background and swap fresher data (mirror
  `PosCatalogController.load()` — the same proven cache-first pattern).
- **Filtering:** search box (name/SKU/barcode → backend search); warehouse chips only when
  `scaleOf == multi`.
- **Rows (mobile `Card` / desktop `DataTable`):** product (name + UoM), on-hand qty, low-stock
  badge when qty ≤ threshold (reuse `/dashboard/low-stock` semantics), warehouse when multi.
- **Actions:** tap → product stock detail; row menu → History / Transfer (multi only) /
  Add stock (manager only).
- **Header stat chips:** total products, total on-hand units, low-stock count.

### 4.2 Product stock detail — `Routes.stockProduct` (`/stock/:productId`)
- Card: per warehouse/location lines (ids + names from enriched DTO). Single tenant → one row.
- Tabs: **History** (movements for this product) + **Stock**.
- Actions: Add stock (existing `add_stock_sheet`, manager), Transfer (multi, manager).

### 4.3 Transfer wizard — `Routes.stockTransfer` (`/stock/transfer`)
- Step 1 — **Source**: warehouse + location (active only). Step 2 — **Destination**: another
  warehouse/location (backend enforces source ≠ dest). Step 3 — **Lines**: product picker +
  qty per line, available-qty hint at source, add/remove lines. Step 4 — **Confirm → creates
  Pending transfer** (`POST /inventory/transfers`); success screen shows "Complete" +
  "Cancel" buttons → `POST /transfers/{id}/complete|cancel`. On complete, refresh hub.
- **Transfer history list** (`GET /transfers`): source → destination, status chip,
  line count, created date; complete/cancel actions on pending (manager only).

### 4.4 Movement history — `Routes.stockMovements` (`/stock/movements?product=&warehouse=`)
- `GET /inventory/movements` (paged, load-more).
- Row: type badge (Mwanzo/Opening, Sale, Void, Adjustment ±, Transfer in/out, Count), signed
  qty (green + / red −), reason, effective date, product + warehouse names (from enrichment).
- Filters: type, warehouse (multi), product. Online-only surface (history is ledger truth;
  offline shows cached stock, history needs network — graceful error + retry).

---

## 5. Backend additions (additive; no new tables/endpoints/permissions)

Do all enrichment at the **query/repository read-model level**; never touch the immutable
ledger or balance aggregates.

1. **`StockBalanceDto` + names.** Add `ProductName`, `UnitOfMeasureName`, `WarehouseName`,
   `StockLocationName`. Implement via a join read in the Infrastructure repo
   (`IStockRepository` gains a balanced-list projection joined to Products/Warehouses/
   StockLocations/UoMs — single query, no N+1) or Application-side dictionary join over the
   existing paged ids. Choose the repo-projection (fastest, no N+1).
2. **`StockMovementDto` + names.** Add `ProductId`, `ProductName`, `WarehouseId`,
   `WarehouseName`, `StockLocationId`, `StockLocationName`. Same approach: repo projection
   joining `StockMovements` → Products/Warehouses/Locations. `ListStockMovementsQueryHandler`
   already passes `WarehouseId`/`ProductId`/`Type` filters — keep them.
3. **`TransferLineDto.ProductName`.** Fill in `WarehouseMappers.ToTransferDto` call sites and
   `GetTransferQueryHandler` by resolving product names via `IProductRepository` (batched per
   transfer — few lines).
4. Leave `/dashboard/low-stock` as the hub's low-stock source of truth.

**Contract note:** all three are purely additive fields — the existing Flutter parsers keep
working; old clients ignore new fields.

---

## 6. Offline & sync

- **Hub + product detail:** cache-first on Drift `CachedStock`. Schema already has
  `warehouseId` on the table (`tables.dart:65-74`) but the POS refresher writes one aggregated
  row with `warehouseId='*'` (`pos_catalog_controller.dart:168-177`). **Change the POS refresh
  to write per-warehouse rows** (id from each `StockBalanceDto.WarehouseId`) so the hub can
  filter offline and the POS still sums per product via the existing `projectedQuantity()`.
  This makes offline per-shop stock work with a **one-line schema-compatible change** (same
  columns, more rows).
- **Transfers + history:** server-required (ledger truth, outbox/events). Graceful
  `NetworkException` handling + retry. Offline transfer queueing = documented phase 2.
- **Sync correctness:** after a transfer `complete` or an `add stock`, call
  `PosCatalogController.refresh()` (backend is truth → re-fetch → rehydrate cache → hub + POS
  both update). No double-write, no local mutation of balances.
- **Permissions:** actions hidden without `Inventory.Manage`; read views available to
  `Inventory.View` (matches backend endpoint gating).

---

## 7. Flutter structure (matches existing conventions)

```
lib/features/inventory/
  domain/        stock_balance.dart, stock_movement.dart, transfer.dart, warehouse_view.dart
  data/          inventory_repository.dart, inventory_providers.dart
  application/   stock_controller.dart (rework -> per-warehouse, cache-first)
                 transfer_controller.dart, movements_controller.dart
  presentation/  pages/stock_page.dart (hub), product_stock_page.dart,
                 transfer_wizard_page.dart, transfer_history_page.dart, movements_page.dart
```

- **Repository:** `InventoryRepository` (balances/movements/warehouses/transfers) — move
  warehouse fetching out of `ProductRepository` or keep + reuse; keeps one owner.
- **Controllers:** Riverpod `Notifier`s + sealed states (same pattern as
  `PosCatalogController`/`SalesHistoryController`).
- **Navigation:** add routes + `Routes.stock*` constants; More-menu tile
  ("Hifadhi/Stock") + Products-tab stock icon; desktop rail optionally grows a Stock
  destination (decision below). Reset stock controllers on logout (`app/providers.dart:47`
  pattern).
- **l10n:** new en+sw ARB keys; run `flutter gen-l10n`.
- Reuse `add_stock_sheet.dart`/`opening_stock_sheet.dart`; pass warehouse from the hub when
  multi instead of forced default warehouse.

---

## 8. Tasks (one small step at a time; analyzers after each)

**Backend (contracts / read models):**
1. `StockBalanceDto` enrichment + repo join projection + mapper + affected handler.
2. `StockMovementDto` enrichment + repo join projection + mapper + handler.
3. `TransferLineDto.ProductName` fill in transfer queries; build `--warnaserror` clean.

**Flutter data + domain:**
4. Domain models + parsers for enriched DTOs (back-compatible).
5. `InventoryRepository` + providers; warehouse fetch consolidation.
6. POS cache refresh writes per-warehouse rows (`CachedStock.warehouseId` real ids).

**Hub (Tier 1):**
7. `StockController` rework — cache-first, per-warehouse, search, low-stock, adaptivity.
8. `StockPage` hub — mobile cards / desktop table, stat chips, warehouse chips (multi only).

**History (Tier 1):**
9. `MovementsController` + `MovementsPage` (types, signed qty, filters).

**Transfers (Tier 2):**
10. `TransferController` + repository methods + `TransferWizardPage` + `TransferHistoryPage`.
11. Refresh hub + POS cache after complete/add-stock.

**Navigation + polish:**
12. Routes, More-menu tile, Products-tab entry, desktop rail decision, controller reset on
    logout, l10n en/sw, `gen-l10n`.

**Verify:**
13. `flutter analyze` clean; targeted controller/widget tests; manual checklist (kiosk single
    warehouse vs multi-warehouse); backend build clean; docs + changelog updated.

---

## 9. Definition of Done (this iteration)

- `/stock` reachable; shows per-product **and** per-warehouse quantities with names; works
  offline from cache for single & multi warehouse.
- Transfer: create → pending → complete moves stock (movements visible); cancel works.
- Movement history renders product/warehouse names, type badges, signed quantities, reasons.
- Single-warehouse tenant sees no warehouse/transfer/complexity; multi-warehouse sees them.
- Viewers read-only; managers see actions. Mobile + desktop layouts render.
- `flutter analyze` clean; no analyzer warnings; Swahili + English; docs + changelog updated.

---

## 10. Decisions (locked 2026-09-11)

1. **Desktop nav: dedicated first-class destination.** Matches Square/Lightspeed/Loyverse:
   desktop + tablet NavigationRail grows a **Stock** destination (rail currently has 5;
   becomes 6) landing directly on the Stock Overview hub. Mobile keeps 5-tab bottom nav;
   Stock is reachable via the **More menu quick-access tile** + a stock icon on the Products
   tab (Square mobile puts Inventory in the hamburger/More menu — same pattern).
2. **Offline per-shop stock: in MVP.** POS refresh writes per-warehouse rows (real ids instead
   of `'*'`); hub filters offline. Schema-compatible — same columns, more rows.
3. **This iteration scope:** view (hub + per-product) + history + transfers. Counts/batches
   stay phase 2 (backend ready).
4. **`warehouseId='*'` rows in existing local DBs:** replaced wholesale on first refresh
   (replaceCatalog deletes then inserts) — no migration needed.

## 11. Hub UX — Stock Overview (matches retail convention)

- **Landing:** `/stock` opens Stock Overview (Square naming). Default sort = lowest stock
  first; sort options (lowest / highest / alphabetical) as chips; optional "low/out only"
  filter — compact and matches Square's default "Lowest stock first".
- **Status chip per row:** in stock (green, qty), **low stock** (yellow/amber, below
  threshold), **out of stock** (red/gray, 0) — Loyverse color language.
- **Search:** name / SKU / barcode (backend search). **Store selector:** chips top-left only
  when multi-warehouse.
- **Per-item actions** (Square-style `...` menu): History, Transfer (multi/manager), Add
  stock (manager). Tap row → product stock detail.
- **Desktop:** `DataTable` with columns Product | SKU | UoM | Store | On hand | Status |
  Actions. **Mobile:** cards with dense rows (Square Mobile Stock Overview look).
- **Header stat chips:** products, on-hand units, low-stock count (reuse `/dashboard/low-stock`).