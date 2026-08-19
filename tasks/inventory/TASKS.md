# TASKS — Inventory Operations (Slice 7)

> Spec: `specs/inventory.md`. Implement one task at a time; run analyzers and tests after each;
> update this file as you go. No code until the spec and this plan are approved.
>
> Sub-slices: 7a Stock Adjustments → 7b Stock Transfers → 7c Stock Counts → 7d Batch/Lot
> Tracking → 7e Tests + docs + commit. Commit style: `feat(inventory): ...`, `test(inventory): ...`,
> `docs(inventory): ...`.

## Status legend

`[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked (note why)

## 7a — Stock Adjustments

- [x] 001 **Domain**: `StockMovementType.Adjustment` enum value (+ `TransferIn`, `TransferOut`,
      `Count`); `StockMovement.Record()` validation for all new types. Unit tests (15 passing).
- [x] 002 **Domain event**: `StockAdjustedEvent`, `StockTransferredEvent`,
      `StockCountCompletedEvent`, `StockBatchCreatedEvent` records in `Domain/Events`.
      `StockAdjustedEvent` raised from `StockMovement.Record()` for `Adjustment` type.
      Unit test (event verified in adjustment test).
- [x] 003 **Application — command**: `AdjustStockCommand` + handler (resolve warehouse/location/
      product, validate product type + variant, lock balance, verify non-negative result, write
      `Adjustment` movement, apply delta, persist, raise event) +
      `AdjustStockCommandValidator` (quantityDelta ≠ 0, reason required ≤ 500, effectiveAt ≤
      UtcNow+5min). Unit tests (8 passing): positive/negative adjust, below-zero rejection,
      no-balance positive creates, no-balance negative rejects, warehouse/product not found,
      service product rejection.
- [x] 004 **API**: `POST /api/v1/inventory/stock/adjustments` endpoint in `InventoryEndpoints`
      (permission `Inventory.Manage`). API project builds clean.
- [x] 005 **Integration tests**: adjustment happy path (balance changes, movement written, audit
      row, event); insufficient stock → 400, zero movements, zero balance change; tenant
      isolation; 403 for viewer.

## 7b — Stock Transfers

- [x] 006 **Domain entities**: `Transfer` aggregate + `TransferLine` entity + `TransferStatus`
      enum (`Pending | Completed | Cancelled`). Factory `Transfer.Create(...)` with invariants
      (source ≠ destination, lines non-empty, each quantity > 0). 11 unit tests passing.
- [x] 007 **Domain — StockMovementType additions**: `TransferIn = 4`, `TransferOut = 5` enum
      values (added in Task 001). Validation included. Covered by existing 15 tests.
- [x] 008 **Domain event**: `StockTransferredEvent` record in `Domain/Events` (added in Task 002).
- [x] 009 **Infrastructure — migration**: `AddInventoryOperations` migration (Transfers,
      TransferLines, StockCounts, StockBatches tables + BatchId FKs on StockBalances/
      StockMovements + indexes). Written manually (no Postgres for dotnet ef).
- [x] 010 **Infrastructure — repository**: `ITransferRepository`, `IStockCountRepository`,
      `IStockBatchRepository` ports + EF implementations + DI registration.
- [x] 011 **Application — create transfer**: `CreateTransferCommand` + handler (validate source/
      dest warehouse, product type, variants, persist transfer) + validator. Builds clean.
- [x] 012 **Application — complete transfer**: `CompleteTransferCommand` + handler (verify
      Pending, validate source stock, write TransferOut + TransferIn movements, debit/credit
      balances) + validator. Builds clean.
- [x] 013 **Application — cancel transfer**: `CancelTransferCommand` + handler + validator.
      Builds clean.
- [x] 014 **API**: `POST /api/v1/inventory/transfers`, `GET /{id}`, `GET /` (paged list),
      `POST /{id}/complete`, `POST /{id}/cancel` endpoints. Builds clean.
- [ ] 015 **Integration tests**: transfer happy path (source −N, destination +N, two movements,
      both balances); insufficient source → 400, zero movements; source = destination → 400;
      complete already completed → Conflict; cancel pending → ok; cancel completed → Conflict;
      tenant isolation; 403 for viewer.

## 7c — Stock Counts

- [x] 016 **Domain entities**: `StockCount` entity + `CountStatus` enum (`Draft | Completed |
      Cancelled`). Factory `StockCount.Create(...)` with invariants. `Complete()` method
      snapshots system quantity, computes difference. 11 unit tests passing.
- [x] 017 **Domain — StockMovementType addition**: `Count = 6` enum value (added in Task 001).
      Covered by existing tests.
- [x] 018 **Domain event**: `StockCountCompletedEvent` record in `Domain/Events` (added in Task 002).
- [x] 019 **Infrastructure — StockCounts table**: included in `AddInventoryOperations` migration.
- [x] 020 **Infrastructure — repository**: `IStockCountRepository` port + EF implementation
      + DI registration.
- [x] 021 **Application — create count**: `CreateStockCountCommand` + handler + validator.
      Builds clean.
- [x] 022 **Application — complete count**: `CompleteStockCountCommand` + handler (snapshot
      balance, compute difference, write Count movement if ≠ 0) + validator. Builds clean.
- [x] 023 **Application — cancel count**: `CancelStockCountCommand` + handler + validator.
      Builds clean.
- [x] 024 **API**: `POST /api/v1/inventory/counts`, `GET /{id}`, `GET /` (paged list),
      `POST /{id}/complete`, `POST /{id}/cancel` endpoints. Builds clean.
- [ ] 025 **Integration tests**: count draft → complete (difference > 0) → adjustment movement;
      count draft → complete (difference = 0) → no movement; complete already completed →
      Conflict; cancel non-draft → Conflict; tenant isolation; 403 for viewer.

## 7d — Batch/Lot Tracking

- [x] 026 **Domain entity**: `StockBatch` entity with factory invariants (batchNumber required,
      expiryDate in future). 6 unit tests passing.
- [x] 027 **Infrastructure — StockBatches table + alterations**: included in `AddInventoryOperations`
      migration; `StockMovements` gains nullable `BatchId` FK; `StockBalances` gains nullable
      `BatchId` FK.
- [x] 028 **Infrastructure — repository**: `IStockBatchRepository` port + EF implementation
      + DI registration.
- [x] 029 **Application — create batch**: `CreateStockBatchCommand` + handler + validator.
      Builds clean.
- [x] 030 **Application — batch status toggle**: `SetStockBatchStatusCommand` + handler + validator.
      Builds clean.
- [x] 031 **Application — batch on existing commands**: `RecordOpeningStockCommand` and
      `AdjustStockCommand` accept optional `BatchId` passed through to `StockMovement.Record()`.
      API request DTOs updated. Builds clean, 58 unit tests passing.
- [x] 032 **API**: `POST /api/v1/inventory/batches`, `GET /{id}`, `GET /` (paged list),
      `PATCH /{id}/status` endpoints. Builds clean.
- [ ] 033 **Integration tests**: batch creation → balance with batch → movement with batch;
      duplicate batch number → Conflict; past expiry → Validation; tenant isolation; 403 for
      viewer.

## 7e — Tests + docs + commit

- [ ] 034 **Full integration suite**: end-to-end scenarios spanning adjustments + transfers +
      counts + batches. Verify all movement types visible in `GET /inventory/movements`.
      Verify Dashboard KPIs still correct after adjustments/transfers. Target: full suite
      passing (≥ 400).
- [ ] 035 **Docs + commit**: build `--warnaserror` clean; `dotnet format` clean; spec marked
      implemented & verified; changelog entry; `memory/project.md` updated; roadmap item 7
      `[x] backend slice`; completion report; pause for review.
