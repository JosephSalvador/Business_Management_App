# AGENTS — Working agreement for AI assistants (OpenCode)

Read this file, plus `memory/project.md`, `docs/ArchitectureRules.md`, and
`docs/CodingStandards.md` at the start of every session.

## The loop (never skip)

1. Read project memory → architecture rules → the feature spec.
2. Create an implementation plan (this file) → get approval before implementing.
3. Implement one small task at a time.
4. Run analyzers and tests; fix failures.
5. Produce a completion report; update documentation; suggest the next task.

## Never do

- Invent architecture or rename unrelated files.
- Modify completed modules without a task.
- Leave TODOs in production code.
- Skip tests or documentation.
- Ignore warnings.
- Mix UI and business logic.
- Commit code without verification.
- Ship or commit client builds without strictly incrementing build-number/versionCode (so installed devices can update in-place without uninstalling).

## Definition of Done

See `docs/ArchitectureRules.md`. Nothing is done until spec, implementation, tests,
documentation, migration, permissions, audit, API, offline, and sync are complete.

## Implementation Plan — Advisory Stock in POS & Offline Checkout
- [x] Task 1: Update `OfflineSaleRecorder.record` to not block sales when stock is low/zero (advisory stock).
- [x] Task 2: Update `_ProductCard`, `_addToCart`, and `_quickQuantity` in `pos_page.dart` to make stock advisory (allow tap, show advisory badge instead of red error/disabled tap).
- [x] Task 3: Update `test/features/sales/offline_checkout_test.dart` to verify non-blocking advisory stock.
- [x] Task 4: Increment version code in `pubspec.yaml` (1.0.0+56).
- [x] Task 5: Run flutter analyze and flutter test; verify clean passes.
- [x] Task 6: Commit and push changes, then trigger `build-clients.yml` to produce the new APK for the user.

## Implementation Plan — Remove VAT & Tax Everywhere in the App
- [x] Task 1: Remove Tax/VAT summary row from `sale_detail_page.dart` and `receipt_printer_service.dart`.
- [x] Task 2: Replace "Tax No" / "Namba ya Kodi" labels with "TIN" in `receipt_renderer.dart` and update receipt tests.
- [x] Task 3: Remove "VAT Registered" / "Mwasilishaji VAT" switch and display from `customer_form_page.dart` & `customer_detail_page.dart`.
- [x] Task 4: Remove "Tax %" / "Kodi %" input from invoice creation (`create_invoice_page.dart`).
- [x] Task 5: Remove dedicated "Tax" / "Kodi" section in `settings_page.dart` and merge TIN into Organization Information.
- [x] Task 6: Clean up TRA / Tax marketing copy in `module_upgrade_sheet.dart`, documentation, and ARB localization files.
- [x] Task 7: Increment version code in `pubspec.yaml` (1.0.0+59).
- [x] Task 8: Commit, push changes, and trigger `build-clients.yml` (Run 40120044671) to generate the updated APK.

## Implementation Plan — True Local-First Offline Operating System
- [x] Task 1.1: Backend - Update `Customer.Create` and `CreateCustomerCommand` to accept optional `Guid? id = null` with idempotency replay.
- [x] Task 1.2: Backend - Update `Expense.Create` and `CreateExpenseCommand` to accept optional `Guid? id = null` with idempotency replay.
- [x] Task 1.3: Backend - Update `CashSession.Open` and `OpenCashSessionCommand` to accept optional `Guid? id = null` with idempotency replay.
- [x] Task 1.4: Backend - Update `Product.Create`, `Supplier.Create`, and `PurchaseOrder.Create` to accept optional `Guid? id = null` with idempotency replay.
- [x] Task 2.1: Frontend - Add dedicated Drift SQLite tables for `LocalCustomers`, `LocalExpenses`, and `LocalCashSessions` in `tables.dart`.
- [x] Task 3.1: Frontend - Refactor `CustomerRepository` & `CustomersController` to be local-first (read from SQLite, write to SQLite + queue, zero failure screens).
- [x] Task 3.2: Frontend - Refactor `ExpenseRepository` & `ExpensesController` to be local-first (read from SQLite, write to SQLite + queue, zero failure screens).
- [x] Task 3.3: Frontend - Refactor `MoneyAccountRepository` & `CashSessionController` to be local-first (read from SQLite, write to SQLite + queue, zero failure screens).
- [x] Task 3.4: Frontend - Refactor `ProductRepository`, `CatalogController`, and `ProductsController` to be local-first (offline catalog fallbacks, deterministic IDs, zero failure screens).
- [x] Task 3.5: Frontend - Refactor `SupplierRepository`, `PurchaseRepository`, `PurchasesController`, `InvoiceRepository`, `InvoicesController`, `ReportsController`, `SalesHistoryController`, and `SettingsController` to eliminate failure screens and operate offline-first.
- [x] Task 4.1: Frontend - Update `SyncEngine` to pass deterministic client IDs and handle idempotent delivery smoothly across sales, customers, expenses, products, suppliers, cash sessions, inventory, and purchases.
- [x] Task 5.1: Bump version code in `pubspec.yaml` (1.0.0+60).

## Implementation Plan — Grafana Loki Real-Time Backend Monitoring
- [x] Task 1: Create Loki deployment configuration (`deploy/monitoring/loki/loki-config.yaml`) and provision Loki datasource in Grafana (`deploy/monitoring/grafana/provisioning/datasources/loki.yaml`).
- [ ] Task 2: Launch `loki` container on port 3100 with `--restart always` and connect it with Grafana.
- [ ] Task 3: Create real-time backend errors & warnings Grafana dashboard (`deploy/monitoring/grafana/dashboards/backend-realtime-logs.json`).
- [ ] Task 4: Add Serilog Loki sink to `BusinessOS.API` with environment configuration and non-blocking fallback.
- [ ] Task 5: Verify end-to-end ingestion and live streaming in Grafana.
## Implementation Plan — Production APK Build v1.0.0+63
- [x] Task 1: Stash invoice WIP safely and bump version to `1.0.0+63` in `pubspec.yaml` and `app_update_service.dart`.
- [x] Task 2: Commit and push changes on branch `feature/mobile-pos-foundation`.
- [x] Task 3: Trigger GitHub Actions workflow `build-clients.yml` with `deploy_target: production` (Run 40874518788).
- [x] Task 4: Monitor remote workflow execution until production APK is published to `https://github.com/JosephSalvador/Business_Management_App/releases/tag/latest`.
## Implementation Plan — Password Policy UI & Submission Guardrails
- [x] Task 1: Add password policy ARB localization strings for length, uppercase, lowercase, numbers, and special characters (`app_en.arb`, `app_sw.arb`).
- [x] Task 2: Enhance `password_field.dart` with `PasswordRequirements`, client-side validator `validatePasswordPolicy`, live `PasswordRequirementsView` checklist, and `errorText` support.
- [x] Task 3: Update `register_page.dart` and `reset_password_page.dart` to bind `validatePasswordPolicy`, show `PasswordRequirementsView`, pass `errorText`, and prevent submission until all requirements are met.
- [x] Task 4: Update unit and widget tests (`password_strength_test.dart` and `auth_forms_widget_test.dart`) to verify local rejection of non-compliant passwords.
- [x] Task 5: Bump version code to `1.0.0+64` in `pubspec.yaml` and `app_update_service.dart`.
- [x] Task 6: Commit (`53c39d5`), push to `feature/mobile-pos-foundation`, and trigger GitHub Actions `build-clients.yml` (Run 41023114036) to publish the updated APK.

