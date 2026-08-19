# TASKS — Reporting + Tax (Slice 10)

> Spec: `specs/reporting-tax.md`. Implement one task at a time; run analyzers and tests after each;
> update this file as you go. Commit style: `feat(reports): ...`, `test(reports): ...`.

## Status legend

`[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked (note why)

## 10a — Infrastructure + Queries

- [x] 001 **Application — TaxSummaryQuery**: `TaxSummaryQuery` handler. Groups `SaleLines` by
       `TaxCode` within date range, sums `BaseAmount`/`TaxAmount`/`LineTotal`, counts sales.
       Supports optional `branchId` filter. Returns `TaxSummaryDto` with `TaxSummaryLineDto`
       list. FluentValidation (from ≤ to). Unit tests.
- [x] 002 **Application — SalesSummaryQuery**: `SalesSummaryQuery` handler. Aggregates `Sales`
       within date range: total sales count, revenue, tax, discount, average sale. Optional
       `branchId` filter. Groups by branch. Returns `SalesSummaryDto`. Unit tests.
- [x] 003 **Application — TopProductsQuery**: `TopProductsQuery` handler. Joins `SaleLines` with
       `Products` within date range, aggregates by `ProductId` (quantity, revenue, tax), ranks
       by revenue descending. Supports `limit` (1..100, default 10) and optional `branchId`.
       Returns `TopProductsDto`. Unit tests.
- [x] 004 **Application — DashboardTaxKpisQuery**: `DashboardTaxKpisQuery` handler. Extends
       existing dashboard with tax-aware KPIs: total revenue, VAT collected by code, top 5
       products by revenue. Returns `DashboardTaxKpisDto`. Unit tests.

## 10b — CSV Export

- [x] 005 **Application — ICsvExportService**: Interface in `Application/Ports`. Method:
       `byte[] Export<T>(IReadOnlyList<T> rows, string[] headers, Func<T, object[]> map)`.
       Returns UTF-8 BOM CSV bytes.
- [x] 006 **Infrastructure — CsvExportService**: Implementation using `System.Text` (no
       third-party library). Handles commas, quotes, newlines in values. DI registration.
- [x] 007 **Application — ExportTaxSummaryHandler**: `ExportTaxSummaryCommand` handler. Calls
       `TaxSummaryQuery`, maps to CSV rows, returns `ExportResultDto` (bytes + content type +
       filename). Unit tests.
- [x] 008 **Application — ExportSalesSummaryHandler**: Same pattern for sales summary. Unit tests.
- [x] 009 **Application — ExportTopProductsHandler**: Same pattern for top products. Unit tests.

## 10c — API Endpoints

- [x] 010 **API — Report endpoints**: `GET /api/v1/reports/tax-summary`,
       `GET /api/v1/reports/sales-summary`, `GET /api/v1/reports/top-products`,
       `GET /api/v1/reports/{reportType}/export`. Permission-gated per report type.
       `Program.cs` registration.
- [x] 011 **API — Dashboard tax KPIs**: Extend `GET /api/v1/dashboard/summary` response with
       tax KPIs (revenue, VAT by code, top products). Or add
       `GET /api/v1/dashboard/tax-summary` if keeping endpoints separate.

## 10d — Tests + Docs

- [x] 012 **Unit tests — full suite**: Target 25+ unit tests across all handlers, validators,
       and CSV export. Verify: date range filtering, branch filtering, top-N limiting, CSV
       encoding, edge cases (empty data, single sale, multiple tax codes).
- [ ] 013 **Docs + Commit**: Update `memory/project.md`. Mark spec implemented. Changelog
       entry. Commit.
