# Feature Spec — Sales Domain + Offline POS (backend slice)

> Phase 1, sixth slice (roadmap item 6). Approval required before coding. Tasks in
> `tasks/sales-pos/TASKS.md`. Design-first: no Sales code until this spec and the task plan
> are approved.
>
> **Sub-slices:** 6a Sales Domain + Tax Engine + Numbering → 6b Application + API + events →
> 6c Tests + docs + commit. The first **mutating** feature that consumes the entire commercial
> core (catalog, pricing, inventory) at once. Builds on Slices 3a–3c and the Dashboard slice
> (which deferred revenue/VAT/top-sellers until a Sales domain exists).
>
> **Status: implemented & verified 2026-08-16.** Backend slice done — tasks 001–016,
> 357 tests passing (14 new integration tests in 014/015), build `--warnaserror` clean.
> Void/returns (6c-void), fiscal adapters, and the Flutter offline POS are tracked
> follow-ups. Final verification in `docs/PlatformReadinessReport.md` Slice 6 checkpoint;
> changelog v0.7.0.

## Feature

Create, list and retrieve **sales** (POS transactions) against the real product/price/stock
foundation. A sale is created online or synced from an offline device, is idempotent on a
client-generated id, re-resolves price/tax/stock server-side, records line-level tax snapshots,
decrements stock, and emits a `SaleCompletedEvent` through the outbox. Core only in this slice:
**void/returns are a separate follow-up** (sub-slice 6c planned below).

## Purpose

Roadmap item 6 "Sales + Offline POS" — the commercial engine. Until now the platform has
provisioned *what you sell, at what price per branch, and how much you have where*. A sale is
where that model becomes revenue. It also unlocks the Dashboard KPIs deferred at v0.6.0
(revenue, VAT, top sellers) and is the anchor for the offline-sync feature slice:

```
POS (drift) → save Sale + items → SyncQueueItems outbox
→ worker flushes → POST /api/v1/sales → CreateSaleCommand → SaleCompletedEvent
→ outbox → audit writes log + notifications queue (receipt) → ack
```

Follows the established slice pattern (`Domain/X` aggregate + `Application/Features/X` +
`Infrastructure` repository + minimal-API endpoints under `/api/v1`), identical to Slices 1–5.
The empty `Modules/Sales` stub stays untouched — the documented future home if the monolith
ever modularizes; this slice does not invent new architecture.

## Business rules

### Sale

- A **sale** belongs to one tenant, one branch, and is recorded by one cashier (`UserId`). It
  may carry an explicit `warehouseId`; if omitted, the branch's default (first) warehouse is
  resolved server-side. Service lines never touch stock.
- `Status` = `Completed | Voided` (only `Completed` is creatable in this slice; `Voided`
  arrives with the void/returns sub-slice). `Source` = `Online | Offline` (how the request
  arrived, not a state).
- `ClientSaleId` is a client-generated `Guid` (offline-first). **Unique per tenant.** It is the
  idempotency key: replaying a sale with the same `ClientSaleId` returns the original sale and
  performs **no** new stock, tax, numbering or event work.
- The header is a **dumb aggregator** of its lines — it never computes tax itself:
  - `Subtotal` = Σ (line.UnitPrice × line.Quantity)
  - `DiscountAmount` = Σ line.DiscountAmount
  - `TaxAmount` = Σ line.TaxAmount
  - `TotalAmount` = Σ line.LineTotal = Subtotal − DiscountAmount
  - `AmountPaid` = Σ payments; `Change` = AmountPaid − TotalAmount (≥ 0 for cash)
- Sale creation must reconcile exactly; a mismatched totals/money invariant is a programmer
  error in tests, not a user path (the server computes all money from resolved lines).
- Sale stores an immutable `number` (receipt sequence) issued by the server (see Numbering);
  `null` is never returned to the client for a completed sale.

### SaleLine (line-level tax snapshot)

- One line per (product, variant) sold; `Quantity > 0`.
- `UnitPrice` is **server-resolved** via the PriceResolver — the client may not set it. If a
  product has variants, the line must name a variant of that product.
- A line is **VAT-inclusive-or-exclusive per the sale's `IsPriceTaxInclusive` flag** (default
  `true`, i.e. prices carry the shelf rate's embedded tax — matches the existing price lists
  and the client POS). The TaxEngine normalizes to an immutable snapshot:
  - `TaxCode` (EFD band, e.g. `A`/`B`/`C`), `AppliedRate` (e.g. `0.18`), `AppliedRuleId`
  - `BaseAmount` (tax-exclusive), `TaxAmount`, `LineTotal` (base + tax)
  - plus product/variant/unit snapshot (`ProductId`, `VariantId?`, `ProductName`, `Sku`,
    `Barcode`, `UnitOfMeasureId/Name`), `Quantity`, `UnitPrice`, `DiscountAmount`
- The snapshot severs the line from live tax rules — a 2024 invoice reprinted in 2027 keeps the
  2024 rate, code and rule id. EFD payloads read `BaseAmount` + `TaxAmount` + `TaxCode` per line
  directly (no reverse-engineering, no rounding drift).

### Payments

- A sale has 1..N `SalePayment` rows. `PaymentMethod` = `Cash | MobileMoney | Card |
  BankTransfer | Credit | Other`. MobileMoney rows may carry `Provider`, `PhoneNumber`,
  `Reference`.
- **Full payment required**: Σ payments == TotalAmount at creation. Partial payment / credit /
  receivables are deferred (no Customers module yet; Dashboard "receivables" KPI stays future).
- Payments are **data only** — this slice makes no gateway calls. M-Pesa/Airtel Daraja
  adapters are a future Payments engine slice.

### Tax Engine (platform capability, data-driven)

The engine is a stateless platform service (`BusinessOS.Application.Tax`). Modules pass *what*
is being transacted (per-line tax category), *where* (regime resolved from the tenant's
country), *when* (transaction date), and the engine returns line-level snapshots.

- **`TaxCategory`** — abstract product classification assigned to Products/Services (seeded:
  `VAT_STANDARD`, `VAT_REDUCED`, `VAT_ZERO`, `EXEMPT`). Products reference a category via a new
  nullable `Product.TaxCategoryId`; `null` → the regime's default (standard). Modules only ever
  touch categories, never country rates.
- **`TaxRegime`** — a country/authority pack (seeded: `TZ_TRA`; KE/UG packs ship later). The
  tenant's `CountryCode` (new, required, default `TZ`) resolves the regime. Branch-level regime
  override is a future option.
- **`TaxRule`** — versioned mapping `TaxRegime + TaxCategory → code/rate/strategy`, with
  `EffectiveFrom`/`EffectiveTo?`. Temporal matching:
  `RegimeId == ctx.RegimeId AND CategoryId == line.CategoryId AND EffectiveFrom <= ctx.Date AND
  (EffectiveTo IS NULL OR EffectiveTo >= ctx.Date)`.
- **`TaxExemption`** — tenant-scoped override (by customer, transaction type, or category;
  e.g. exports/diplomatic). The engine applies overrides before snapshotting. Customer-level
  exemptions are deferred (no Customers); the table + engine hook ship now, exercised via the
  `EXEMPT` category.
- **Strategies:** a `TaxRule` may name a `CalculationStrategyKey`. Default = simple percentage.
  The TZ pack seeds `TZ_DUAL_VAT` — the effective rate is **selected by payment context**
  (exactly the proven Flutter logic, server-side):
  - cash → 18% `A`
  - electronic + no TIN → 16% `B`
  - electronic + TIN + VAT-registered → 18% `A`
  - electronic + TIN + not VAT-registered → 16% `B`
  For **inclusive** prices the engine extracts the embedded shelf-rate VAT first, then applies
  the selected rule (per line). Compound taxes (excise-then-VAT, fuel levies) plug in later as
  new strategy keys — never new module code.
- `ITaxEngine.CalculateAsync(TaxCalculationContext)` is the only entry point. Contract (see
  tasks 001–002 for exact records):
  `TaxCalculationContext(TenantId, BranchId, TransactionDate, CustomerId?, Currency,
  IsElectronicPayment, CustomerTin?, IsVatRegistered?,
  Items: [{ ItemId, TaxCategoryCode, UnitPrice, Quantity, IsPriceTaxInclusive }])`
  → `TaxCalculationResult(TotalBaseAmount, TotalTaxAmount, Lines: [TaxLineSnapshot])`.
  `TaxLineSnapshot = (ItemId, TaxCode, AppliedRate, BaseAmount, TaxAmount, LineTotal,
  AppliedRuleId)` — the exact shape persisted onto `SaleLine`. The payment/taxpayer fields
  feed context-selected strategies such as `TZ_DUAL_VAT`.
- **Money:** decimal(19,4) internally; money rounded to 2 dp **per line** at calculation time
  (receipt-safe, no drift).

### Localization strategy (Odoo-style `l10n_*`)

Country-specific behavior is a plug-in in `backend/src/Localizations/<Country>/`, never core
logic:

- Core (agnostic): `Application/Tax/ITaxEngine.cs`, `Application/Tax/Strategies/
  ITaxCalculationStrategy.cs`, `Application/Tax/Strategies/DefaultPercentageTaxStrategy.cs`
  (works for most jurisdictions; core fallback key `Simple`).
- Localization modules: `Localizations/Tanzania/Tax/TzDualVatTaxStrategy.cs` (`TZ_DUAL_VAT`),
  future `Localizations/Tanzania/Fiscal/TraVfdOutboxWorker.cs` (async TRA VFD consumer of
  `SaleCompletedEvent`), future `Localizations/Kenya/Tax/KeTimsTaxStrategy.cs`.
- Selection is data-driven: the `CalculationStrategyKey` on the regime's `TaxRule` rows tells
  the core which strategy to resolve from DI. No `if (country == "TZ")` switches.
- Rules (locked): **no core changes** for a new country (implement the strategy contract or
  consume standard domain events — never alter the `Sale` aggregate for a country);
  **no blocking checkout** (fiscal integrations are asynchronous, opt-in per tenant, never
  reject/delay a sale); **rely on the snapshot** (read `TaxLineSnapshot` and the `Sale` fiscal
  placeholders — never recompute totals).

### Stock

- Stocked lines debit the balance at `(warehouse, default location, product, variant?)` inside
  the sale transaction under a **row lock** (`GetBalanceWithLockAsync` — existing pattern).
  `StockMovement` type `Sale` (negative delta, reference = sale id) is written alongside the
  balance change (append-only ledger — corrections are compensating movements, never edits).
- Balance may **never go negative**: insufficient stock rejects the whole sale (`Validation`,
  HTTP 400) with a full rollback — no movement rows, no balance change, no receipt number, no
  events. This is the offline-sync availability strategy: server re-checks at sync time; soft
  per-device reservations are a future improvement.
- The existing `StockMovementType` enum gains a `Sale` value (its doc comment already reserves
  "sale out").

### Pricing

- Price is re-resolved server-side per line with the existing `PriceResolver` (default price
  list → exact branch before all-branch → price type `Retail` default → highest qualifying
  min-quantity → latest effective-from). **No price → the whole sale is rejected** (400) —
  "no price → no price" is an invariant, never a silent zero.
- Currency = price-list currency (default tenant currency). The `PriceListId` is snapshotted on
  the sale.

### Numbering

- Receipt numbers are **server-authoritative** and sequential per tenant: a `NumberSequence`
  row (`Scope = "Sale"`, current value, prefix/pattern, e.g. `S-2026-000123`) is incremented
  under the per-tenant advisory lock + `SELECT ... FOR UPDATE` in the sale transaction.
- Offline, the client shows a temporary local number; the authoritative number is returned by
  the POST and stored back into Drift on sync. Never two tenants, never two sales share a
  number.

### Idempotency & offline

- `POST /api/v1/sales` accepts an `Idempotency-Key` header; `ClientSaleId` also serves as the
  key. A replay for the same tenant returns the original `SaleDto` (200) with no side effects.
- Server re-resolution (price/tax/stock/numbering) applies on the **first** arrival only.

## Screens (Flutter)

None added by this backend slice (API-first). Follow-up phase: wire the existing POS
(`new_sale_page`, VAT dialog, mobile-provider service, TRA receipt, Bluetooth printer) to these
endpoints; create Drift `sales`/`sale_items` tables + `SyncQueueItems` flush worker. The client
keeps computing display VAT for offline UX, but the **server response is authoritative** and is
written back to the device.

## API (backend)

All authenticated (`Bearer`), versioned `/api/v1`, rate-limited by the `global` policy,
tenant-scoped. Failures: RFC 7807 `ProblemDetails` with stable `code` (`Validation`,
`NotFound`, `Conflict`, `Unauthorized`, `Forbidden`). Mutations return `200` (platform
`ToApiResult` convention).

### Sales

| Method | Route | Permission | Body / Query | Success |
|---|---|---|---|---|
| POST | `/api/v1/sales` | `Sales.Create` | `CreateSaleRequest` + `Idempotency-Key` | 200 `SaleDto` |
| GET | `/api/v1/sales/{id}` | `Sales.View` | — | 200 `SaleDto` |
| GET | `/api/v1/sales` | `Sales.View` | `?page&pageSize&branchId&from&to&status&search` | 200 `PagedResult<SaleDto>` |

`CreateSaleRequest` = `branchId`, `warehouseId?`, `priceListId?`, `clientSaleId`, `source`
(`Online|Offline`), `effectiveAt`, `isElectronicPayment`, `isVatRegistered?`,
`customer { name?, phone?, tin? }`, `lines [{ productId, variantId?, quantity, discountAmount?
}]`, `payments [{ method, amount, provider?, phoneNumber?, reference? }]`.

`SaleDto` = id, tenantId, branchId, warehouseId, cashierId, number, clientSaleId, source,
status, saleDate, effectiveAt, currency, isElectronicPayment, customer { … }, totals
(subtotal/discount/tax/total/amountPaid/change), lines (full snapshot incl. taxCode/rate/
baseAmount/taxAmount/lineTotal/appliedRuleId), payments, timestamps.

### Catalog/organization (small extensions for the TaxEngine)

| Method | Route | Change |
|---|---|---|
| PUT | `/api/v1/products/{id}` | `UpdateProductRequest` gains optional `taxCategoryId` |
| PUT | `/api/v1/organization` | tenant profile gains optional `countryCode` (default `TZ`) |

## Database

One migration `AddSalesAndTax` (public schema; Sales/Tax stay in `public` until stable — the
bounded contexts move to their own schema only when Sales/Inventory/Accounting stabilise, per
`docs/ArchitectureRules.md`).

- **`Sales`**: tenant/branch/warehouse/cashier ids, `client_sale_id`, `number`, `source`,
  `status`, sale date + effective at, currency, `is_electronic_payment`, customer snapshot,
  totals, `voided_at/by/reason?` (future-proofing), **fiscal placeholders** (nullable, written
  only by the fiscal adapter — see [Fiscalization & revenue authorities](#fiscalization--revenue-authorities)):
  `buyer_tin`, `buyer_name`, `buyer_id_type?`, `buyer_mobile?`, `fiscal_receipt_number?`
  (RCTNUM = GC), `fiscal_verification_code?` (RCTVNUM, printed + QR), `fiscal_z_number?`
  (ZNUM = YYYYMMDD), `fiscal_daily_counter?` (DC), `fiscal_status` (enum, default
  `NotApplicable`). Unique `(TenantId, ClientSaleId)`, partial unique `(TenantId, Number)`,
  index `(TenantId, BranchId, SaleDate)`.
- **`SaleLines`**: FK sale (cascade); product/variant/uom + display snapshots, `quantity`,
  `unit_price`, `discount_amount`, `base_amount`, `tax_code`, `applied_rate`, `applied_rule_id`,
  `tax_amount`, `line_total`. `tax_code`/`base_amount`/`tax_amount` are the fiscal adapter's
  exact source of truth for building item + VAT-total records — no reverse math at send time.
- **`SalePayments`**: FK sale (cascade); `method`, `amount`, `provider?`, `phone_number?`,
  `reference?`, order index.
- **`TaxCategories`**: `code`, `name` (seeded: VAT_STANDARD, VAT_REDUCED, VAT_ZERO, EXEMPT).
- **`TaxRegimes`**: `code`, `name`, `country_code` (seeded: TZ_TRA).
- **`TaxRules`**: regime FK, category FK, `code` (A/B/C — **internal** selection keys, see
  [Fiscalization & revenue authorities](#fiscalization--revenue-authorities)), `rate`,
  `calculation_strategy_key?`,
  `effective_from/to?`, unique `(RegimeId, CategoryId, Code, EffectiveFrom)`.
- **`TaxExemptions`**: tenant, category FK, optional customer/transaction-type, window.
- **`NumberSequences`**: tenant, `scope`, `current_value`, `prefix`, `pattern`, unique
  `(TenantId, Scope)`.
- **Altered:** `Products` + `TaxCategoryId` (nullable FK, `Restrict`); `Tenants` +
  `CountryCode` (required, default `TZ`); `StockMovementType` gains `Sale` (enum, no DDL).

All tables keep the base `Entity` audit columns (`CreatedAt/By`, `UpdatedAt/By`) stamped by
`ApplyAuditColumns`.

## Validation

- Sale: ≥ 1 line; every line quantity > 0; variant consistency; branch/warehouse belong to
  tenant; resolved price present; stock sufficient; totals reconcile; payments sum == total;
  `clientSaleId` non-empty; `effectiveAt` not in the future beyond a small skew window.
- Tax: category code exists; rate ≥ 0; window sanity (`EffectiveTo >= EffectiveFrom`);
  exemption window sanity.
- Numbering: scope non-empty; allocation is monotonic per tenant.

## Permissions

Reuse existing `Sales.Create`, `Sales.View`, `Sales.Delete` (void sub-slice) — already present
in `PermissionNames.All` (PermissionNames.cs:63), already seeded to admin roles by
`DatabaseSeeder`. **No new permissions.** Endpoints gated with `RequirePermission(...)`.

## Events

- **`SaleCompletedEvent`** (aggregate-raised on `Sale.Create`): consumed by a new
  `SalesActivityFeedHandler` (outbox-backed, existing notification/activity pipeline). Future
  consumers: fiscal adapter (see [Fiscalization](#fiscalization--revenue-authorities)), SMS/email
  receipt, accounting journal, analytics (Dashboard revenue/VAT).
- Stock movements are written directly by the sale transaction (same pattern as opening stock),
  not event-driven.
- Void/returns later raise `SaleVoidedEvent` (sub-slice 6c).

## Reports

- Dashboard (v0.6.0) gains Sales aggregates later: revenue, VAT (by tax code), top sellers —
  new `IDashboardRepository` methods over `Sales`/`SaleLines` (future slice). The snapshot
  columns (`BaseAmount`, `TaxAmount`, `TaxCode`) are the report source.
- `GET /api/v1/sales` list is the seed of the sales history screen.

## Tests

- **Unit:** `Sale.Create` invariants (empty lines, qty ≤ 0, totals reconcile, payments == total,
  variant consistency, no price → reject); TaxEngine rule selection (temporal window, category
  fallback, exemption override); TZ dual-VAT strategy (all 4 A/B scenarios, embedded-VAT
  extraction math, inclusive vs exclusive); per-line rounding; NumberSequence allocation
  (monotonic, per-tenant); stock debit math (service skips, no-negative).
- **Integration** (real Postgres `businessos_test`):
  - happy path: create → stock down, receipt number issued, audit row, outbox `SaleCompletedEvent`.
  - no price → 400, nothing written; insufficient stock → 400 with **zero** movements and
    **zero** balance change (rollback proof).
  - `clientSaleId` replay → same sale returned, no second movement/number/event.
  - mixed cart (standard + zero/exempt) → correct line snapshots + totals.
  - VAT scenarios (cash/electronic × TIN/VAT-registration) → correct code+rate per line.
  - split cash + mobile-money payment reconciliation; change ≥ 0.
  - service line skips stock; tenant isolation (tenant B cannot read A's sale, 404); 403 for a
    `Sales.View`-only role; paged list filters (branch/date/status/search).
  - fiscal placeholders default correctly: `fiscal_status = NotApplicable`, all `fiscal_*` /
    `buyer_*` null for a standard tenant (no provider configured).
- Full suite target: ≥ 260 passing.

## Offline & sync

```
POS (drift) → save Sale + items (clientSaleId = UUID, temp local number) → SyncQueueItems
→ worker flush → POST /api/v1/sales { clientSaleId, ... }  (idempotent, Idempotency-Key)
→ server resolves price/tax/stock, issues authoritative number, decrements stock
→ 200 SaleDto → device stores remoteId + number + syncStatus=Synced → next items
```

- Replays are safe (unique `(TenantId, ClientSaleId)`); the worker can retry freely.
- Server-wins for numbers and prices; a rejected sale (stock/price changed) surfaces as a
  `Validation` ProblemDetails the POS shows and prompts the operator to re-quote.
- Flutter follow-up owns: Drift tables (`sales`, `sale_items` with `remoteId/syncStatus/
  deletedAt` — schema already modelled), `SyncQueueItems` flush worker, conflict UI.

## Fiscalization & revenue authorities

> **Architecture rule (applies to all RA integrations — TRA, KRA, URA, RRA).**
> Core sales **never depend** on a revenue authority. Creating a `Sale`, deducting stock and
> issuing the local receipt must complete instantly online or offline. All RA integrations are
> **asynchronous outbox consumers**, strictly **opt-in per tenant**. This slice ships only the
> database placeholders and the (unchanged) tax snapshots — **no HTTP clients, no RA calls**.

1. **Opt-in per tenant.** A future `Tenant.FiscalProvider` ("TRA"/"KRA"/…) plus credentials
   (TIN, VRN, device cert/serial) enables fiscalization for that tenant. Tenants without it
   stay standard offline-only POS users.
2. **The silent outbox.** `SaleCompletedEvent` always fires. A future fiscal worker reads it;
   if `FiscalProvider` is unset it marks the sale `FiscalStatus.NotApplicable` and stops — no
   errors, no delays, no API attempts. If set, it posts one receipt at a time in order.
3. **Engine is country-agnostic.** The internal `ITaxEngine` never knows "Tanzania". `TZ_DUAL_VAT`
   is a pure math calculator producing `TaxLineSnapshot`; `TaxRegime`/`TaxCategory`/`TaxRule`
   are data. Adding `KE_KRA` or `UG_URA` packs is pure seeding.
4. **Schema is RA-ready now.** The Sale header carries nullable fiscal fields (above) and each
   line already snapshots `tax_code`, `applied_rate`, `base_amount`, `tax_amount` — exactly what
   the adapter needs to build item + VAT-total records without reverse-engineering rounding.

### Internal tax codes vs. official TRA tax codes

Our `TaxRule` codes (`A`=18%, `B`=16% reduced e-payment rate, `C`=0%) are **internal selection
keys** mirroring the client POS. They are **not** the TRA TAXCODE values. TRA EFDMS/VFD codes
(official API doc, `TAXCODE`/`VATRATE`):

| Internal | Rate | Applies when (TZ) | TRA official code |
|---|---|---|---|
| `A` | 18% | cash; or e-payment w/ TIN + VAT-registered buyer | `1` (Standard) → group `A` |
| `B` | 16% | e-payment without TIN, or with TIN not VAT-registered (VAT Act 16% reduced B2C e-payment rate, in force 2025-09-01) | mapping decided by the future adapter (see note) |
| `C` | 0% | zero-rated / exempt supplies | `3` (Zero-rated) / `5` (Exempt) → groups `C`/`E` |

TRA official groups also include `2` Special rate (0%) → `B` and `4` Special relief (0%) → `D`;
those are future category mappings. **The adapter maps internal codes → official TAXCODEs and
owns any ambiguity** (e.g. how the 16% reduced rate is posted) at integration time — this slice
guarantees only that the exact rate snapshot is persisted per line.

### TRA VFD reference (for the future adapter, from the official developer doc)

- **Flow:** Registration (one-time, signed) → Token (bearer, cached until expiry) → receipt
  posting → daily Z report (before a new day's sales). Signature: SHA1-RSA over the body,
  base64; headers `Cert-Serial`, `Client`, `Routing-Key` (`vfdrct` / `vfdzreport`).
- **Receipt fields:** seller `TIN`, `REGID`, `EFDSERIAL`, buyer `CUSTIDTYPE` (1=TIN,
  2=DL, 3=Voter, 4=Passport, 5=NID, 6=NIL), `CUSTID`, `CUSTNAME`, `MOBILENUM`
  (`255712XXXXXX`/`0712XXXXXX`), `RCTNUM` (== `GC`, global, monotonic), `DC` (daily counter,
  resets at midnight), `ZNUM` (YYYYMMDD == RCT_DATE), `RCTVNUM` (RECEIPTCODE + GC), item
  records (`ID`, `DESC`, `QTY`, `TAXCODE`, `AMT` inclusive), totals (`TOTALTAXEXCL`,
  `TOTALTAXINCL`, `DISCOUNT`), `VATTOTALS` (per group: `NETTAMOUNT`, `TAXAMOUNT`), `PAYMENTS`
  (`PMTTYPE`: CASH/CHEQUE/CCARD/EMONEY/INVOICE; `PMTAMOUNT`).
- **Acknowledgment:** `ACKCODE 0` = success. Retries must resubmit the **original** payload
  (original `ZNUM`, `RCT_DATE`, `RCT_TIME`), one transaction at a time, in order. Offline:
  keep selling, mark each transaction `Pending`, resend automatically when connectivity
  returns. QR: verification page over `RCTVNUM`.

## Future improvements

- **Fiscal adapter (sub-slice after 6c):** `Tenant.FiscalProvider` + credentials; outbox
  consumer posting `SaleCompletedEvent` → TRA VFD (XML, signed) with the mappings above,
  updating `fiscal_*` placeholders and `FiscalStatus`; Z-report job; KRA TIMS / URA EFRIS /
  RRA adapters share the same slot.
- **Void/returns (sub-slice 6c):** `POST /api/v1/sales/{id}/void` (`Sales.Delete`), reversal
  `StockMovementType.SaleVoid` + stock add-back, `SaleVoidedEvent`, refund payment records.
- Customers aggregate (customer-specific pricing, exemptions, receivables/credit sales).
- Mobile-money gateway adapters (M-Pesa Daraja, Airtel Money, Tigo Pesa, Mixx, HaloPesa) and
  payment status/settlement.
- Discount rules engine (manager-approval flows, promotions, loyalty).
- Soft stock reservations per device (allow offline sell-now, reconcile-later).
- KE/UG tax packs; compound-tax strategy keys (excise, fuel levies); branch-level regimes.
- Sales aggregates in the Dashboard slice (revenue, VAT by code, top sellers).
