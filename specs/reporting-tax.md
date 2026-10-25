# Feature Spec — Reporting (Tax/VAT Disabled)

## Feature

`Reporting — Sales summary reports, dashboard KPIs, and CSV export`

## Purpose

Tax and VAT functionality is disabled until the business is legally eligible to use it.
TIN remains an organization/customer identifier only. Active reports show sales, revenue,
discounts, quantities, stock, and cash movement without tax calculations or tax summaries.

## Screens

- `ReportsPage` — Sales Summary, Top Products, and operational reports.
- `SalesSummaryPage` — date range filters and aggregated sales data.
- `TopProductsPage` — date range and top products by revenue/quantity.

## API

Active reporting endpoints include:

- `GET /api/v1/reports/sales-summary`
- `GET /api/v1/reports/top-products`
- `GET /api/v1/reports/sales-trend`
- Operational sales, stock, purchasing, expense, and cash reports.

Tax-summary, dashboard-tax-KPI, and tax-export endpoints are not registered.

## Business rules

- Sales reporting is tenant-scoped.
- Revenue is the recorded selling amount; no VAT is added or deducted.
- Date filters default to the current reporting period.
- CSV export uses UTF-8 BOM for Excel compatibility.
- Reports are online-only and read committed data.

## Data and compatibility

TIN is retained as an identification field for organizations, customers, and receipts.
Legacy tax columns may remain in historical database migrations for compatibility, but
active checkout, invoices, reports, synchronization, and UI do not calculate, collect,
display, or expose tax/VAT behavior.

## Permissions

- `Sales.View` — sales reports.
- `Products.View` — product reports.
- Existing inventory, purchasing, and expense permissions apply to their reports.

## Future

Tax/VAT can only be reintroduced after legal eligibility is confirmed and a separately
approved localization, migration, API, and test plan is completed.
