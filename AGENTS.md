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
## Implementation Plan — Registration Timeout & Phantom Conflict Auto-Recovery
- [x] Task 1: Update `ApiClient._canFailover` to respect `skip_retry: true` and prevent blind retries of mutating requests (`POST`/`PUT`/`DELETE`) on `receiveTimeout` & 504.
- [x] Task 2: Enhance `auth_controller.dart` to attempt seamless auto-login on `ConflictException` during registration (if credentials match the freshly created user, proceed into the app; otherwise surface conflict).
- [x] Task 3: Configure primary `API_URL` to point directly to Azure Container App in `.github/workflows/build-clients.yml` to eliminate Cloudflare 503 drops.
- [x] Task 4: Fix `deploy/cloudflare-failover-worker.js` proxy forward logic (remove forbidden Host header override and ensure safe abort controller).
- [x] Task 5: Bump version code to `1.0.0+65` in `pubspec.yaml` and `app_update_service.dart`.
- [x] Task 6: Commit, push to `feature/mobile-pos-foundation`, and trigger GitHub Actions `build-clients.yml` to publish updated production APK (Run 41041507461).
## Implementation Plan — Multi-Step Registration & Instant Availability Verification (Microsoft-Style)
- [x] Task 1: Backend - Add `/api/v1/auth/check-availability` endpoint for fast pre-validation of email and phone.
- [x] Task 2: Frontend - Add `checkAvailability` in `AuthRepository` and wire pre-check into `AuthController`.
- [x] Task 3: Frontend - Transform `register_page.dart` into a smooth 2-step wizard (Step 1: Identity & Contact with live availability check; Step 2: Password, Policy Checklist & Terms).
- [x] Task 4: Frontend - Add step indicator progress UI, smooth step transition animations, and back-step navigation in `register_page.dart`.
- [x] Task 5: Frontend - Add localization strings in `app_en.arb` and `app_sw.arb` for step indicators, headers, and navigation buttons.
- [x] Task 6: Frontend & Backend Tests - Update unit and widget tests (`auth_controller_journey_test.dart`, `auth_forms_widget_test.dart`).
- [x] Task 7: Bump version code to `1.0.0+66` in `pubspec.yaml` and `app_update_service.dart`.
- [x] Task 8: Commit, push to `feature/mobile-pos-foundation`, and trigger GitHub Actions `build-clients.yml` to publish updated production APK (Run 41196720293).

## Implementation Plan — UI Polish, Recent Activity Business Overhaul & Cloud Deployment
- [x] Task 1: Backend - Exclude query handlers from audit logging in `AuditBehavior.cs` and filter non-business commands in `ListRecentActivityAsync`.
- [x] Task 2: Frontend - Redesign `_ActivityFeed` in `dashboard_page.dart`: map actions to clean human-readable business phrases, distinct semantic icons/colors, and locale-aware relative timestamps.
- [x] Task 3: Frontend - Add supplier refresh and quick "+ Ongeza Msambazaji" action in `purchase_form_page.dart`.
- [x] Task 4: Frontend - Fix light mode visibility across all expense screens (`expenses_page.dart`, `expense_form_page.dart`, `record_account_expense_page.dart`, `cash_session_page.dart`).
- [x] Task 5: Bump version code to `1.0.0+67` in `pubspec.yaml` and `app_update_service.dart`.
- [x] Task 6: Deploy updated backend to Azure Container Apps production (`deploy-azure.yml`) so `/check-availability` is active in production.
- [x] Task 7: Build and publish production APK v1.0.0+67 via GitHub Actions (`build-clients.yml`).

## Implementation Plan — Permanent Android Signing Keystore & In-Place Updates
- [x] Task 1: Generate permanent 2048-bit RSA release keystore (`android/app/upload-keystore.jks`) valid for 10,000 days (until 2054).
- [x] Task 2: Configure `android/key.properties` and update `android/app/build.gradle.kts` to load release signing config with `key.properties` and fallback to `upload-keystore.jks`.
- [x] Task 3: Store base64-encoded keystore and credentials securely in GitHub Secrets (`ANDROID_KEYSTORE_BASE64`, `STAGING_ANDROID_KEYSTORE_BASE64`, etc.).
- [x] Task 4: Update `.github/workflows/build-clients.yml` to automatically decode keystore and write `android/key.properties` before APK build.
- [x] Task 5: Bump version code to `1.0.0+68` in `pubspec.yaml` and `app_update_service.dart`.
- [x] Task 6: Commit, push to `feature/mobile-pos-foundation`, and trigger production build workflow on GitHub Actions.

## Implementation Plan — Registration Deadlock Fix, Auto-Login Guardrails & Azure Production Deployment
- [x] Task 1: Backend - Move `response.IsFailure` check before `SaveChangesAsync` in `TransactionBehavior.cs` to eliminate saving dirty entities or deadlocks on failed commands.
- [x] Task 2: Backend - Wrap `FailedLoginCount` and audit logging in non-fatal try-catch in `LoginCommand.cs` to prevent turning invalid credentials into 30s 500 timeouts.
- [x] Task 3: CI/CD - Fix `deploy-azure.yml` to use unique image tag `${{ env.image_name }}:${{ github.sha }}` ensuring Azure Container Apps deploys a new revision on every run.
- [x] Task 4: Frontend - Add 4-second timeout to auto-login in `auth_controller.dart` on `ConflictException`, rethrowing conflict immediately on failure.
- [x] Task 5: Frontend - In `register_page.dart`, reject existing email/phone immediately in Step 1, route to Step 0 on conflict, and provide direct one-tap "Ingia kwenye Akaunti" action.
- [x] Task 6: Bump version code to `1.0.0+69` in `pubspec.yaml` and `app_update_service.dart`.
- [x] Task 7: Commit, push to `feature/mobile-pos-foundation`, deploy backend to Azure production, and trigger client build on GitHub Actions.

## Implementation Plan — Enterprise-Grade High-Speed Invoicing & Delivery Note Management
- [x] Task 1: Database & Persistence Layer — EF Core models (`CustomerInvoice`, `CustomerInvoiceLine`, `DeliveryNote`, `DeliveryNoteItem`) with strict `TenantId`, composite indexes `(TenantId, CreatedAt)`, `(TenantId, Number)` unique, and global query filters `HasQueryFilter(e => FilterTenantId == null || e.TenantId == FilterTenantId)`.
- [x] Task 2: Sequence Concurrency Service — Thread-safe `IInvoiceNumberSequenceService` and `InvoiceNumberSequenceService` acquiring tenant advisory lock with `SELECT FOR UPDATE` to guarantee contiguous, gap-free, collision-free numbers.
- [x] Task 3: Transactional Outbox Integration — MediatR command handlers (`CreateCustomerInvoiceCommand`, `CreateDeliveryNoteCommand`) executing inside explicit database transaction, atomically persisting entities and domain events into `OutboxMessages`.
- [x] Task 4: Endpoints & Application CQRS — Minimal APIs for `/api/v1/invoices` and `/api/v1/delivery-notes` (`List`, `Get`, `Create`, `Dispatch`, `Deliver`, `Cancel`) with `.AsNoTracking()` projections and permission security.
- [x] Task 5: Database Migration & Snapshot — Migration `20261031180000_AddDeliveryNotesAndDocumentIndexes` and updated `BusinessDbContextModelSnapshot`.
- [x] Task 6: Comprehensive Tests — Unit and integration tests covering aggregate lifecycle, status transitions, sequential document numbering, outbox persistence, and strict multi-tenant query filter isolation.

## Implementation Plan — Template Marketplace and Fluid.Core Liquid Rendering Engine
- [x] Task 1: Domain & Persistence Layer — `DocumentTemplate` (system-level marketplace aggregate) and `TenantDocumentConfiguration` (tenant-scoped aggregate) with unique index on `(TenantId, DocumentType)`, global multi-tenant query filter on configurations, and no query filter on shared templates.
- [x] Task 2: High-Performance Fluid.Core Engine — `InvoiceTemplateRenderService` implementing `IDocumentTemplateRenderService` with `IMemoryCache` caching compiled AST structures under `tpl:{templateId}:{layoutHash}`, sub-50ms execution, and isolated `MemberAccessStrategy` whitelisting flat DTO properties.
- [x] Task 3: HTML Sanitization & Safety — `HtmlSanitizerService` shielding Liquid tokens (`{{ ... }}` and `{% ... %}`), removing `<script>`, `<iframe>`, `<object>`, inline event handlers, and malicious URIs prior to database storage.
- [x] Task 4: Validation Pipeline — `UpdateTenantDocumentConfigurationCommandValidator` enforcing valid hex color codes and sanitizing custom layout overrides.
- [x] Task 5: Seeding & Marketplace Catalog — Seeded 4 marketplace templates in `DatabaseSeeder.cs` (Modern Minimalist Invoice, Classic Corporate Invoice, Standard Logistics Delivery Note, Thermal POS Slip).
- [x] Task 6: Minimal API Endpoints — `DocumentTemplateEndpoints.cs` mapping `GET /document-templates`, `GET /tenant-document-configurations`, `PUT /tenant-document-configurations/{documentType}`, `GET /invoices/{id}/html`, `GET /delivery-notes/{id}/html`, and `POST /document-templates/preview`.
- [x] Task 7: Database Migration & Model Snapshot — Migration `20261031190000_AddDocumentTemplatesAndTenantConfigurations.cs` and synced `BusinessDbContextModelSnapshot.cs`.
- [x] Task 8: Comprehensive Unit Tests — `HtmlSanitizerServiceTests`, `TemplateRenderServiceTests` (validating sub-50ms render), and `TemplateValidatorsTests`.



