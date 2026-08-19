# Feature Spec — Reporting + Tax

## Feature

`Reporting + Tax — Sales tax reports, dashboard KPIs, and CSV/Excel export infrastructure`

## Purpose

Businesses need to file VAT returns and understand their tax liability. The tax engine already
calculates per-line snapshots (`TaxCode`, `AppliedRate`, `BaseAmount`, `TaxAmount`) on every
`SaleLine`, but no queries aggregate this data. This slice adds tax summary reports, dashboard
KPIs, and a CSV/Excel export pipeline so operators can download reports for accountants and
tax authorities.

## Business rules

- Tax data is immutable once a Sale is completed — reports read from `SaleLines` snapshots.
- Reports are tenant-scoped — no cross-tenant data leakage.
- Tax summary groups by `TaxCode` (e.g., `VAT_A`, `VAT_B`, `EXEMPT`).
- Date filters default to current fiscal month if not provided.
- CSV export uses UTF-8 BOM for Excel compatibility.
- No PDF generation in this slice (deferred to Phase 2).
- Dashboard KPIs: total revenue, VAT collected by code, top-selling products by revenue.
- Tax configuration (categories, rules, regimes) is read-only — no tenant CRUD in this slice.

## Screens (Flutter)

- `ReportsPage` — list of available reports (Sales Summary, Tax Summary, Top Products)
- `TaxSummaryPage` — date range filter, table of tax codes with base/tax/total, download CSV
- `SalesSummaryPage` — date range filter, aggregated sales data, download CSV
- `TopProductsPage` — date range, top N products by revenue/quantity, download CSV

## API (backend)

### Tax Summary Report

```
GET /api/v1/reports/tax-summary?from=&to=&branchId=
Authorization: Bearer JWT
Permission: Accounting.View

Response 200:
{
  "from": "2026-08-01T00:00:00Z",
  "to": "2026-08-31T23:59:59Z",
  "lines": [
    {
      "taxCode": "VAT_A",
      "appliedRate": 18.0,
      "totalBaseAmount": 150000.00,
      "totalTaxAmount": 27000.00,
      "totalLineTotal": 177000.00,
      "saleCount": 42
    }
  ],
  "totalBaseAmount": 150000.00,
  "totalTaxAmount": 27000.00,
  "totalLineTotal": 177000.00
}
```

### Sales Summary Report

```
GET /api/v1/reports/sales-summary?from=&to=&branchId=
Authorization: Bearer JWT
Permission: Sales.View

Response 200:
{
  "from": "...",
  "to": "...",
  "totalSales": 42,
  "totalRevenue": 500000.00,
  "totalTax": 85000.00,
  "totalDiscount": 12000.00,
  "averageSale": 11904.76,
  "byBranch": [
    { "branchId": "...", "branchName": "HQ", "totalSales": 30, "totalRevenue": 350000.00 }
  ]
}
```

### Top Products Report

```
GET /api/v1/reports/top-products?from=&to=&limit=10&branchId=
Authorization: Bearer JWT
Permission: Products.View

Response 200:
{
  "from": "...",
  "to": "...",
  "products": [
    {
      "productId": "...",
      "productName": "Maize Flour 2kg",
      "sku": "MF-2KG",
      "totalQuantity": 150,
      "totalRevenue": 75000.00,
      "totalTax": 11250.00,
      "rank": 1
    }
  ]
}
```

### CSV Export

```
GET /api/v1/reports/{reportType}/export?from=&to=&branchId=
Authorization: Bearer JWT
Permission: Accounting.View (tax-summary), Sales.View (sales-summary), Products.View (top-products)

Response 200: text/csv (UTF-8 BOM)
```

`reportType` values: `tax-summary`, `sales-summary`, `top-products`

## Database

No new tables. All reports query existing `Sales`, `SaleLines`, and `SalePayments` tables.

The `SaleLine` snapshot columns (`TaxCode`, `AppliedRate`, `BaseAmount`, `TaxAmount`) are the
report source. No new migration needed.

## Validation

- `from` must be ≤ `to`.
- `limit` (top-products) must be 1..100, default 10.
- `branchId` is optional — when omitted, reports cover all branches.

## Permissions

- `Accounting.View` — tax summary reports
- `Sales.View` — sales summary reports
- `Products.View` — top products reports
- No new permissions needed.

## Events

No new domain events. Reports are read-only queries over existing data.

## Reports

- **Tax Summary** — grouped by TaxCode, summed BaseAmount/TaxAmount/LineTotal, sale count
- **Sales Summary** — total sales/revenue/tax/discount, grouped by branch
- **Top Products** — ranked by revenue, with quantity and tax totals

## Tests

- Unit tests for report query handlers (15+ tests)
- Unit tests for CSV export service (5+ tests)
- Unit tests for dashboard KPI queries (5+ tests)
- Integration tests blocked on Postgres

## Offline & sync

Reports are online-only (read-only queries over committed data). No offline behavior needed.

## Future improvements

- PDF generation (QuestPDF) for formal tax return documents
- Tenant-managed tax rule CRUD endpoints
- Compound tax strategies (excise-then-VAT, fuel levies)
- Kenya (`KE_KRA`) and Uganda (`UG_URA`) tax packs
- TRA VFD fiscal adapter (write `fiscal_*` placeholders)
- Customer-level tax exemptions (requires Customers module)
- Report scheduling (email CSV on 1st of month)
- Pivot tables and charts in Flutter
