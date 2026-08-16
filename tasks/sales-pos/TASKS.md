# TASKS — Sales Domain + Offline POS (Slice 6)

> Spec: `specs/sales-pos.md`. Implement one task at a time; run analyzers and tests after each;
> update this file as you go. No code until the spec and this plan are approved.
>
> Sub-slices: 6a Sales Domain + Tax Engine + Numbering → 6b Application + API + events →
> 6c Tests + docs + commit. Void/returns are a planned follow-up (6c), not part of the core.
> Commit style: `feat(sales): ...`, `test(sales): ...`, `docs(sales): ...`.
>
> Localization strategy (locked): country behavior is a plug-in under
> `backend/src/Localizations/<Country>/`, never core logic. Core fallback =
> `DefaultPercentageTaxStrategy` (`Simple`); Tanzania ships `TzDualVatTaxStrategy`
> (`TZ_DUAL_VAT`) in `Localizations/Tanzania/Tax/`. Selection is data-driven via the
> `CalculationStrategyKey` on regime `TaxRule`s; the core never references a country by name.
> Rules: no core changes for a new country · no blocking checkout (fiscal = async outbox
> consumer) · rely on the `TaxLineSnapshot` + `Sale` fiscal placeholders. See
> `docs/ArchitectureRules.md` + spec "Localization strategy".

## Status legend

`[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked (note why)

## 6a — Sales Domain + Tax Engine + Numbering

- [x] 001 **Tax entities**: `TaxCategory`, `TaxRegime`, `TaxRule` (incl. `CalculationStrategyKey`)
      and `TaxExemption` in `Domain/Sales`; `ITaxEngine` port + `TaxCalculationContext` /
      `TaxCalculationResult` / `TaxLineSnapshot` records in `Application/Tax`. Entity unit
      tests (13): normalization, rate/window/code invariants, exemption matching, seed parity.
- [x] 002 **Tax engine**: `TaxService` (temporal rule matching, category fallback to default,
      exemption overlay, strategy dispatch) + core `DefaultPercentageTaxStrategy` (`Simple`) +
      `TZ_DUAL_VAT` strategy (payment-context A/B selection + embedded-VAT extraction for
      inclusive prices, per-line 2-dp rounding). Unit tests (14): mixed cart, windows,
      exemptions, 4 A/B scenarios, inclusive/exclusive math, rounding, fallbacks, quantity guard.
- [x] 002a **Localization reorg** (locked pattern): new `BusinessOS.Localizations` project;
      `TzDualVatTaxStrategy` moved to `Localizations/Tanzania/Tax/` (namespace
      `BusinessOS.Localizations.Tanzania.Tax`); `SimplePercentageStrategy` renamed
      `DefaultPercentageTaxStrategy` (helpers `EmbeddedRate`/`LatestEffective` public for reuse);
      `AddLocalizations()` DI extension wired in `Program.cs`; strategy keys unchanged (DB
      contract). Pattern documented in `docs/ArchitectureRules.md` + spec.
- [x] 003 **Seed data + catalog migration**: `EnsureTaxCatalogAsync` get-or-create by code
      (VAT_STANDARD/REDUCED/ZERO/EXEMPT categories, TZ_TRA regime, A/B dual-VAT + C zero rules,
      effective 2021-07-01); EF config + DbSets + `Schemas/Tables.Sales`; `AddTaxCatalog`
      migration (4 tax tables) created + applied to dev DB. Verified by API boot (seed log) +
      psql: 4 categories / 6 rules / 1 regime, idempotent across reboots. `Tenant.CountryCode`
      stays with 005 (property + DTO/PUT; column in 009).
- [x] 004 **Catalog hook**: nullable `Product.TaxCategoryId` + product DTO/`UpdateProduct`/`CreateProduct`
      support (category `Restrict` FK); `ProductReferenceGuard` validates the platform tax catalog via
      `ITaxRuleRepository.GetCategoryByIdAsync` (added to the port + `TaxRuleRepository` EF impl +
      DI registration). `AddProductTaxCategory` migration created + applied; `TaxCategoryId` round-trip
      (create/update-to-null) verified via live API + psql; invalid category → 400. Tests: +3 Product,
      +1 integration (assignment + validation). `Tenant.CountryCode` domain pulled forward here (entity
      property, default `TZ`, `UpdateCountryCode`, ctor param, seeder backfill for existing tenants)
      with `AddTenantCountryCode` migration; the org DTO/PUT stays with 005.
- [x] 005 **Tenant hook**: `OrganizationDto` + `UpdateOrganizationCommand` now carry required
      `CountryCode` (FluentValidation: `.NotEmpty().Matches("^[A-Z]{2}$")`); `GET`/`PUT`
      `/api/v1/organization` round-trip verified (default `TZ`, update → `KE`, missing/lowercase
      → 400) in `OrganizationEndpoints_ReturnOwnTenantProfile`. No Flutter client calls this
      endpoint yet, so no client migration was needed.
- [x] 006 **Sale aggregate**: `Sale` + `SaleLine` + `SalePayment` with `Sale.Create` invariants
      (lines, totals reconciliation, full payment, variant consistency, line-level tax snapshot)
      and `SaleCompletedEvent`. Includes the nullable fiscal placeholders (`buyer_tin/name/
      id_type/mobile`, `fiscal_receipt_number/verification_code/z_number/daily_counter`,
      `FiscalStatus` default `NotApplicable` — see spec "Fiscalization & revenue authorities").
      Unit tests (+19 `SaleTests`: reconcile, discount, split payments, fractional quantity,
      fiscal defaults, event; build `--warnaserror` clean; full suite 288/288).
- [x] 007 **Numbering**: `NumberSequence` entity (`Scope = "Sale"`, prefix/pattern,
      `{prefix}-{year}-{sequence:000000}` → `S-2026-000123`) + monotonic `Allocate` (year rolls
      with the sale's effective date; per-tenant uniqueness guaranteed by the repo's advisory
      lock + `SELECT ... FOR UPDATE`, wired in 010). Unit tests (+14; build `--warnaserror` clean;
      full suite 302/302).
- [x] 008 **Inventory integration**: `StockMovementType.Sale` (negative-delta guard in
      `StockMovement.Record`) + `SaleStockDebitService` stock-debit path (row lock per balance,
      check-all-then-apply → insufficient stock rejects the whole sale with zero movements,
      service lines skipped via `DebitsStock`, movement references the sale id, registered in DI).
      Unit tests (+8; build `--warnaserror` clean; full suite 310/310).
- [x] 009 **Migration**: `AddSalesAndTax` (Sales, SaleLines, SalePayments, NumberSequences +
      fiscal placeholders; tax catalog shipped in 003; `Products.TaxCategoryId` in 004 and
      `Tenants.CountryCode` in 004 already migrated); applied to dev DB; build `--warnaserror` clean.
      Verified via psql: 4 tables + `(TenantId, ClientSaleId)` unique, partial `(TenantId, Number)`
      unique, `(TenantId, BranchId, SaleDate)` index, cascade FKs on lines/payments; full suite 310/310.

## 6b — Application + API + events

- [x] 010 **Repositories**: `ISaleRepository` (`Add`, `GetById`, `GetByClientSaleId`, filtered
      `List`/`Count`), `INumberSequenceRepository` (`AllocateAsync`) + EF implementations + DI
      registration. (`ITaxRuleRepository` EF impl + DI done in 004.)
- [x] 011 **CreateSaleCommand**: orchestration (resolve branch/warehouse/products → PriceResolver
      per line → TaxEngine → totals → stock debit → receipt number → persist → events) +
      validator + DTOs + mappers + **idempotent `ClientSaleId` replay**. Unit tests done here
      (+14 command, +7 validator); integration coverage lands in 014/015.
- [x] 012 **Queries**: `GetSaleQuery`, `ListSalesQuery` (branch/date-range/status/search) + `SaleDto`.
      Reuses the 011 DTOs/mappers. Unit tests done here (+6 query handler, +4 query validator:
      mapped DTO, null customer, not-found, tenant scoping, paging/total, filter passthrough,
      page/pageSize bounds, inverted date range); integration coverage lands in 014/015.
- [x] 013 **API + events**: `SalesEndpoints` (`POST/GET /api/v1/sales`, `GET /{id}`, all
      `RequirePermission(Sales.Create/View)`) + registration in `Program.cs` +
      `SalesActivityFeedHandler` consuming `SaleCompletedEvent`. POST accepts an
      `Idempotency-Key` header (authoritative `ClientSaleId` when parseable, else the body
      `clientSaleId`); `CreateSaleRequest` carries `customer { name?, phone?, tin? }` — `phone`
      maps to `Sale.BuyerMobile` (spec contract), threaded through the command/DTO/mapper.
      Endpoint integration coverage lands in 014/015.
- [x] 014 **Offline contract**: `Idempotency-Key` + `ClientSaleId` replay integration test
      (no double stock/number/event on retry).

## 6c — Tests + docs + commit

- [x] 015 **Integration suite**: happy path (stock down, number issued, audit row, outbox event),
      no-price → 400, insufficient stock → 400 with full rollback (zero movements, zero balance
      change), mixed cart + VAT A/B/C scenarios, split cash + mobile-money reconciliation,
      service line skips stock, tenant isolation (404), 403 for `Sales.View`-only role, paged
      list filters. Full suite target ≥ 260 passing. **Done 2026-08-16:** 14 integration tests
      green, full suite 357/357. Real bugs found & fixed: missing `ITaxEngine` DI registration;
      `Sale.Reconcile` `totalAmount == subtotal − discount` invariant incompatible with dual-VAT
      rate B (relaxed to header-as-aggregator); auto-selected warehouse (no `warehouseId`) loaded
      without `Include(Locations)` → `ResolveStockLocation` crash; outbox writer never stamped
      `OutboxMessage.TenantId`. Test-only fixes: opening writes a `StockMovement` (filter
      `MovementType == Sale`), `discountAmount` non-nullable (`0m` not `null`), insufficient-stock
      needs `amountPaid = 200m`, `SetPrices` replaces (mixed cart PUTs both prices), Maize needs
      opening stock. See `memory/project.md` 014/015 entry.
- [ ] 016 **Docs + commit**: build/format/tests; spec marked implemented & verified; changelog
      v0.7.0, `memory/project.md`, roadmap item 6 `[x] backend slice`, readiness report Slice 6
      checkpoint; completion report; pause for review.
- [ ] (future) **6c-void**: `VoidSaleCommand` + `StockMovementType.SaleVoid` reversal + stock
      add-back + `SaleVoidedEvent` + `POST /api/v1/sales/{id}/void` (`Sales.Delete`).
