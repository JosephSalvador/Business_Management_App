# MVP TO PILOT — Execution Plan (JOLINX BUSINESS OS)

Repo: `business_app` (Flutter client + `backend/` modular monolith). Jolinx Platform repo is
out of scope. Backend endpoints are reused as-is; Flutter is the UI + offline layer.

## Backend facts driving the plan (verified 2026-08-21)

- Auth: `POST /api/v1/auth/{register,login,refresh,revoke}`, `GET /api/v1/users/me`.
  Registration creates Tenant + HQ Branch + Administrator role + user and returns tokens.
  **No email verification exists yet** → minimal backend slice required (M2).
- Organization: `GET/PUT /api/v1/organization` (name, contact, address, CountryCode, TaxId;
  currency fixed at registration).
- Catalog: products CRUD/status/variants; categories/brands/units CRUD (tenant-scoped,
  empty for new tenants → onboarding must seed one unit).
- Pricing: price-lists CRUD + `PUT /price-lists/{id}/prices` + `GET /pricing/resolve`.
  **No default price list auto-created** → onboarding must create it ("Bei ya Duka").
- Inventory: warehouses CRUD (+ MAIN location auto-created), `GET /inventory/stock`,
  `GET /inventory/movements`, `POST /inventory/stock/opening`, `POST /inventory/stock/adjustments`.
  **New tenants have no warehouse** → onboarding must create one for HQ branch.
- Sales: `POST /api/v1/sales` with `ClientSaleId` idempotency (+ `Idempotency-Key` header),
  server recomputes prices/tax/stock; list/get/void. PaymentMethod enum: Cash, MobileMoney,
  Card, BankTransfer, Credit, Other. SaleSource: Online, Offline.
- Dashboard: summary/low-stock/recent-activity. Reports: tax-summary/sales-summary/top-products.
- Errors: ProblemDetails `{title, detail, status, code}`; success = 200 raw DTO (204 unit-less).

## Milestones

| # | Milestone | Status |
|---|-----------|--------|
| M1 | Flutter security foundation (Dio + secure storage + env + Riverpod swap for auth; mocks removed) | done |
| M2 | Real auth + workspace/onboarding (register→verify→login→create business→enter OS) | done |
| M3 | Business setup wizard (simple Swahili-first labels) | done |
| M4 | POS core / sales (product→cart→payment→sale→receipt, online) | done |
| M5 | Offline-first POS + sync (encrypted Drift DB, device identity, cache, offline sale, sync queue/engine, conflicts) — rescoped 2026-08-23 (former "Basic inventory" mostly delivered in M3; remainder → backlog) | done |
| M6 | POS (search/cart/payment cash+mobile money → complete sale) — delivered by M4 | done |
| M7 | Receipts (preview/share/print/reprint) — redesigned ticket, thermal print, reprint watermark + print audit (spec: `specs/receipts.md`) | done |
| M8 | Offline-first POS + sync (Drift encrypted DB, ClientSaleId idempotency, queue) — delivered by M5 | done |
| M9 | Auth to global standard (optional business name, required phone + login by email OR phone, forgot/reset password, password UX, EN/SW i18n scaffold) | done |
| M9.1 | Staff join-by-invitation-code (owner generates a code → staff registers with it → joins owner's business with Staff role; no tenant/Administrator created) | done |
| M10 | Backup & recovery (encrypted export/import + validation) | pending |
| M11 | UX hardening (Swahili-first nav, a11y, confirmations) | pending |
| M12 | Pilot preparation + checklist | pending |
| M13 | Subscription foundation (Starter trial gates) | partial |
| M14 | Production readiness checks | pending |

## Open blockers from 2026-08-24 device bring-up

1. ~~Compile break providers.dart:287~~ FIXED — `branchIdOf: () => branchIds()`.
2. ~~Splash deadlock (root cause of the eternal "Business OS" loading screen)~~
   FIXED 2026-08-24, two independent defects:
   - **Router deadlock:** `journeyRedirect` treated `/splash` as allowed for
     `AuthUnauthenticated`, returning null → parked forever (SplashPage never
     navigates by design). Authenticated users escaped via the
     `_isJourneyScreen('/')→/home` rule, which is why earlier logged-in
     sessions worked. Fix: splash no longer allowed once auth is known;
     regression test added (app_router_test).
   - **Secure-storage contention at startup:** ConnectivityMonitor's health
     probe went through `_attachAuth` (token read) concurrently with session
     bootstrap's read; flutter_secure_storage deadlocked on the Samsung
     device → both chains frozen → AuthUnknown forever. Fix: probe sends
     `skip_auth` (unauthenticated endpoint) AND `bootstrap()` now has a 10 s
     watchdog degrading to Login instead of hanging.
3. **Release-mode SQLite loading** — code already correct
   (`open.overrideFor(..., openCipherOnAndroid)` incl. per-isolate
   `isolateSetup`; DB file created on device 17:37). Still verify a RELEASE
   build end-to-end on the tablet.
4. **Device ↔ API connectivity** — `.env` baseUrl is `127.0.0.1:5000`, which
   requires `adb reverse tcp:5000 tcp:5000` per run session (wireless adb
   included). Without it every call fails instantly ("Hakuna muunganisho").
   Consider LAN-IP baseUrl for cable-free pilots.
5. **Uncommitted work:** the ENTIRE MVP effort (M1–M5 Flutter, M2/M3/M5 backend
   slices, tasks/mvp docs) sits uncommitted/untracked on
   `feature/mobile-pos-foundation`. Commit in reviewable chunks next.
6. Note: `pm clear` was used during debugging (22:0x) — tablet local data
   (test tokens/DB) was wiped; register again on device.
7. ~~Dev DB migrations pending~~ RESOLVED 2026-08-25 — `AddUniqueUserPhone` and
   `AddPasswordResetCodes` applied to dev database `businessos`
   (`dotnet ef database update`; design-time DATABASE_URL wants the raw
   Npgsql format `Host=...;...`, NOT a postgresql:// URL). Restart the dev
   API so it picks up the new auth contract.


## M5 task breakdown (Offline-first POS + sync) — spec approved 2026-08-23

Audit verdict (see memory/project.md M5 audit): backend needs ZERO structural change for
push-only sync — POST /sales is exactly-once (unique TenantId+ClientSaleId, per-tenant
advisory lock, replay-first returns original SaleDto) and accepts client effectiveAt.
Local DB is greenfield. Phases:

1. M5.1 core/local: Drift schema v1 (meta, cached_products, cached_stock, local_sales,
   local_sale_lines, local_payments, sync_queue), SQLCipher key from secure storage,
   migrations from day one, DAOs + atomic sale transaction.
2. M5.2 DeviceIdentity: UUIDv4 installation id in secure storage; stamped on queue ops.
3. M5.3 PosCatalogController: cache-first product/price/stock reads; refresh online;
   offline search local only.
4. M5.4–5.5 OfflineSaleRecorder: CheckoutController falls back to a single local
   transaction on NetworkException/TimeoutException (sale+lines+payments+queue row+
   projected stock deduction); clientSaleId = operation id = Idempotency-Key; totals are
   estimates; conservative block at cart (projected balance guard).
5. M5.6–5.7 SyncQueueDao + engine: FIFO drain, exponential backoff, statuses
   pending/syncing/synced/failed/conflict, failed ops retained; price re-check at send
   (cached snapshot vs resolved → conflict PRICE if drifted).
6. M5.8 ConnectivityMonitor (connectivity_plus + reachability probe + hysteresis);
   auto-sync on reconnect, manual "Sawazisha sasa", single worker.
7. M5.9 Offline window: 72 h from last successful auth (meta.last_auth_success_at);
   expiry blocks new sales, pending remain viewable/syncable.
8. M5.11 Backend: enforce Tenant.IsActive in the request pipeline (small middleware +
   cache); backend tests for suspended tenant / disabled user rejection.
9. M5.12–5.16 Conflicts deterministic (idempotency auto; stock→CONFLICT/STOCK review;
   user/branch disabled→failed); Swahili banners 🟢🟠🔴 + sync status sheet; provisional
   receipts marked "Mauzo ya Offline".
10. M5.17 Logout with pending ops → confirm dialog, tokens cleared, encrypted DB kept,
    tenant-mismatch wipe prompt.
11. M5.18 Tests (25-case matrix) → 12. M5.19 real E2E m5_e2e.sh → 13. security review +
    docs.

## M4 task breakdown (POS core / sales) — plan approved 2026-08-23

Audit verdict: the backend sales engine is complete and authoritative — POST /api/v1/sales
(Sales.Create), server-side price resolution (default list, Retail, tax-inclusive),
TaxEngine (TZ dual-VAT plug-in), payments (Cash=0/MobileMoney=1, must cover total exactly),
whole-sale stock rejection ("Insufficient stock for 'X'."), NumberSequence receipt numbers,
ClientSaleId idempotency with authoritative Guid Idempotency-Key header (replay returns the
original SaleDto), GET /sales/{id}, GET /sales list (from/to/status/search). BranchId is
required and absent from WorkspaceDto → fetch first branch via GET /branches. Zero backend
changes planned.

Flutter slice (features/sales):
1. Domain `sale.dart`: CartLine, PaymentMethod consts, SaleDto parser, toCreateBody()
   sending only client-allowed data (productId/qty/clientSaleId/branchId/payments,
   source=0 Online, isElectronicPayment = method != cash).
2. `sale_repository.dart`: create (Idempotency-Key header), getById, listToday, resolvePrice.
3. Controllers: cart (add/inc/dec/remove/clear; price resolve on add w/ silent fallback to
   cached retail price), pos (products+search reusing M3 providers), checkout (clientSaleId
   generated once per checkout and kept across retries + submitting guard → double-tap safe;
   Swahili error mapping incl. "Kiasi cha bidhaa hakitoshi.", session expiry, network),
   sales_history ("Mauzo ya leo", refreshed after each sale).
4. Pages: PosPage (search + product cards + bottom cart bar JUMLA/[Lipa]), cart sheet
   (± qty/remove), PaymentSheet (Jumla, Cash/Mobile Money, Lipa disabled while submitting),
   SaleSuccessPage (Muamala umekamilika; Uza tena primary), ReceiptPreviewPage (ticket text,
   copy + save .txt — no printer stack in M4), SaleDetailPage + history list.
5. Router: /pos, /pos/success, /pos/receipt/:id, /sales/:id; Mauzo tab swaps placeholder for
   PosPage; controllers reset on logout.
6. Cart VAT decision (approved): shelf prices are tax-inclusive server-side and there is no
   tax-rules read API — cart shows Jumla only (+ hint "Bei zinajumuisha kodi"); exact
   Subtotal/VAT/Total shown on success/receipt from server truth.
7. Tests: repository contract (body shape, header, parse), cart/checkout/history controllers
   (double-submit single request + stable key, replay, insufficient stock, 401/403/network),
   router reachability, widget tests for totals/payment/success flow.
8. Real-API E2E: full journey incl. oversell rejection, duplicate submit = exactly one sale,
   restart + fresh-login persistence.

Out of scope (per spec): void/refund UI, barcode scanning (no existing stack), Bluetooth
printing (preview/share only), offline POS (M8).

## M3 task breakdown (business setup + product catalog)

Audit verdict (2026-08-23): backend already covers products CRUD, categories/brands/units,
warehouses, opening stock, balances, pricing engine — M3 is ~90% Flutter work. A new
self-registered tenant gets ONLY a branch ("Head Office"/HQ) + admin role: no warehouse,
no price list, no units, and tax categories have no read endpoint. Plan approved 2026-08-23
(full scope incl. case-insensitive search fix).

Backend slice:
1. `CompleteOnboarding` ensures defaults, idempotently: default warehouse "Main Store"
   (code MAINSTORE, location MAIN) under the tenant's first active branch + default
   "Retail Prices" price list in the tenant currency — each only when none exists
   (unconditional ensure; guards make it idempotent). Command holds the tenant advisory
   lock.
2. `GET /api/v1/tax-categories` read endpoint (existing `Products.View` permission) over
   the platform TaxCategories table.
3. Product search made case-insensitive (`EF.Functions.ILike`) in PlatformRepositories.
4. Fixed latent bug: `WarehouseRepository.ListAsync` did not include Locations (list
   endpoints returned empty `locations[]`) — now `.AsSplitQuery().Include(...)`.
5. Tests: `OnboardingDefaultsTests` — first-run defaults created, repeat run idempotent,
   partial defaults healed (missing warehouse re-created exactly once), tax-categories
   seeded catalog + anonymous 401, case-insensitive search. Full suite green.

Flutter slice:
5. Bottom-nav shell: Mauzo / Bidhaa / Stock / Ripoti / Zaidi (Mauzo+Ripoti placeholders).
6. `features/products`: models (Product, UnitOfMeasure, TaxCategory, Warehouse,
   StockBalance, PriceList), repository (incl. GET-merge-PUT price upsert), controllers.
7. Products screen: search/status/price/stock badge, empty state "Hujaongeza bidhaa bado".
8. Add/Edit product form (Jina/Kipimo/Bei ya kuuza/Kodi/SKU/Aina) with client validation +
   friendly error mapping (409 duplicate SKU etc.). Create sends status=1 (Active).
9. Opening stock sheet: Kiasi + Main Store auto-selected, [ Hifadhi ]; stock screen with
   balances.
10. Business setup step after create-business when no products yet: "Tuanzishe biashara
    yako" summary + ensure standard units + CTA to first product.
11. Router journey extension + tests; controller/repository/widget tests.

Known debt flagged: buying price not supported by backend (omitted from form); product
list stock badges join one balances page client-side (no batch endpoint); case-sensitive
search fixed for products only.

### M3 stock follow-up (done 2026-09-12)

Post-M3 improvements to make stock advisory and shippable:

- **Stock is advisory, never blocks sales.** `SaleStockDebitService` locks row, creates
  balance if missing, always debits (negative allowed). `StockBalance.Apply` no longer
  throws on negative.
- **Idempotent adjustments.** `AdjustStockCommand` dedupes via `Idempotency-Key` header or
  `ClientAdjustmentId` body field; replays return current balance without double-applying.
- **Staff can top up stock.** `InventoryManage` + `WarehousesView` added to the Staff role
  (`PermissionNames.cs`).
- **defaultWarehouse** prefers code `MAINSTORE` over `.first` (multi-warehouse safe).
- **Flutter AddStockSheet** localized, idempotent, opens from ProductDetailPage stock card.
- **Products tile** reverts to chevron; opens detail page where stock action lives.
- **ARB keys** (en+sw): add-stock flow + product detail stock card + product badges.
- **Tests:** `StockRow.status` + `StockReady.visible` filtering; backend adjustment
  idempotency + non-blocking debit + oversell-to-negative integration.

## M2 task breakdown (real auth + workspace/onboarding)

Audit verdict (2026-08-22): register/login/refresh/revoke + BCrypt(12) + lockout +
hashed refresh-token families with replay detection all exist and are reused. Missing
(proven by audit): email verification (zero code paths), unverified-login gate, any
"my workspaces" endpoint, onboarding-state signal.

Backend slice:
1. `Error.Forbidden` / `Error.TooManyRequests` factories; MapFailure case for
   `AccountNotVerified` → 403.
2. `SecurityOptions` += VerificationCodeTtlMinutes (1440), VerificationMaxAttempts (5),
   VerificationResendCooldownSeconds (60).
3. Domain `EmailVerificationCode` (6-digit crypto-random code, SHA-256-hashed at rest,
   TTL, single-use, attempt counter) + table mapping + repository port/impl.
4. Migration `AddEmailVerificationAndOnboarding`: codes table + Tenants.BusinessType +
   Tenants.OnboardingCompletedAt.
5. `VerificationCodeService` (issue/invalidate/cooldown/enqueue via existing
   IJobQueue.SendEmailJob — first real user of the wired-but-unused job pipeline).
6. Register stops issuing tokens → returns UserDto (verification now mandatory);
   login rejects unverified with AccountNotVerified; endpoints POST /auth/verify-email,
   POST /auth/resend-verification. Seeder marks demo admin verified/onboarded.
7. GET /api/v1/workspaces/mine (array derived from JWT tenant claim) +
   POST /api/v1/organization/onboarding (OrganizationsManage; stamps completion).
8. Tests: unit (validators/service) + integration (register→verify→login matrix,
   expired/reused/exhausted codes, resend cooldown, tenant isolation).

Flutter slice:
9. Auth feature: register no longer persists a session → verify screen; verification
   controller (submit/resend); Swahili-first copy.
10. Workspace feature: repository + controller over /workspaces/mine + onboarding
    complete call.
11. Pages: VerifyEmailPage, ZeroWorkspacePage ("Hujaanzisha biashara bado"),
    CreateBusinessPage (name/type/country/currency/tax), WorkspacePickerPage,
    HomePage shell.
12. Deterministic router state machine (login/verify/create/picker/dashboard; no loops).
13. Flutter tests: journey controllers + routing decisions + failure paths.

**Flagged decision (reported, not silently made):** the data model is single-tenant-per-user
(`User.TenantId`; registration IS org creation). True multi-workspace needs a membership
redesign — out of M2 scope. The new endpoint returns an array so the Flutter side is
future-proof; >1 workspaces is unreachable today.

## M1 task breakdown

1. Dependency audit: add dio, flutter_secure_storage, flutter_riverpod, flutter_dotenv,
   connectivity_plus, uuid, intl; dev: http_mock_adapter. Remove bloc/equatable/provider +
   dead UI deps after mock removal. All MIT/BSD, actively maintained.
2. `core/config/app_config.dart` + `.env` (dev-only, committed) + https enforcement.
3. `core/network/`: typed `ApiException` (ProblemDetails parsing), `ApiClient` (Dio):
   bearer injection, single-flight refresh-on-401, redacting logging.
4. `features/auth/data/`: `TokenStore` abstraction + `SecureTokenStore`
   (flutter_secure_storage), `AuthRepository` against real backend.
5. Delete mock era: bloc auth, hardcoded users/passwords, UserProvider, LocalStorageService,
   disconnected Drift schema, mock sales/product/dashboard/report/settings/user-management UI
   and services (git history preserves them; each returns milestone-by-milestone).
6. New router (go_router + Riverpod redirect) + minimal shell until M2 lands real screens.
7. Tests: config https guard, refresh flow, error mapping, redaction, token store contract,
   auth repository happy/failure paths. `flutter analyze` + `flutter test` green.

## Verification commands

- Flutter: `flutter analyze && flutter test`
- Backend: `dotnet build backend/BusinessOS.slnx --warnaserror` + `dotnet test backend/tests/...`

## Progress log

- 2026-08-21: Plan created. Baseline verified: backend builds clean (0 warnings);
  Flutter baseline has mock auth + hardcoded credentials (to be removed in M1).
- 2026-08-22: M1 complete. Removed all mock-era features/deps; added dio + Riverpod +
  secure-storage foundation (`core/config`, `core/network`, `features/auth`,
  `core/di`, `core/routing`); real backend auth wired end to end. 16 tests green,
  analyzer clean. Gotcha recorded: http_mock_adapter runs route callbacks at
  registration and matches the LAST registered handler — per-request scripting
  uses our own `ScriptedAdapter` in `test/support/fakes.dart`.
- 2026-08-23: M2 complete (backend + Flutter). Backend: email verification
  (SHA-256-hashed codes, TTL, attempts, resend cooldown), unverified-login gate,
  /workspaces/mine + onboarding completion, migration
  AddEmailVerificationAndOnboarding. Latent infra bugs fixed en route: test factory
  env-var injection, missing [Migration] attributes on 3 hand-written migrations +
  snapshot regeneration, OutboxJobQueue never stamped TenantId (ITenantScopedEvent),
  JournalEntry shadow-FK duplicate relationship (JournalEntryId1), seeder empty-currency
  crash. 535/535 backend tests green; fresh-DB migration chain verified. Flutter:
  RegisteredUser flow, AuthNeedsVerification state, workspace feature
  (repo/controller/domain), journey router machine (pure journeyRedirect), 5 new
  pages. ScriptedAdapter now records request bodies. flutter analyze clean;
  38/38 tests green. Tech debt flagged: attribute-only Designer.cs on three
  slice-8/9 migrations; single-tenant-per-user model (see flagged decision above).
- 2026-08-23: M3 complete (backend + Flutter). Backend: onboarding defaults
  (Main Store warehouse + Retail Prices list, idempotent), GET /tax-categories,
  ILIKE product search, warehouse Locations include fix; 540/540 tests green.
  Flutter: products feature end to end (domain/repository/controllers/pages),
  HomeShell bottom-nav shell (/home?tab=), /setup first-run screen after
  create-business, add/edit form with GET-merge-PUT price upsert, opening-stock
  sheet, starter units ensured on setup entry (Kipande/Kilo/Lita/Gunia). Real-API
   E2E verified the full journey incl. restart + fresh login persistence and 409
   on duplicate opening stock. flutter analyze clean; 55/55 tests green. Debt:
   search matches contiguous substrings only; stock badges join one balances page;
   buying price unsupported by backend.
- 2026-08-23: M5 complete — offline-first POS + sync. Flutter: core/local Drift
   schema v1 (meta, cached_products, cached_stock, local_sales/lines/payments,
   sync_queue) with SQLCipher key held in flutter_secure_storage; DeviceIdentity
   (UUIDv4 installation id); PosCatalogController cache-first grid (offline search,
   projected stock = last-known balance − pending offline qty); CheckoutController
   falls back to OfflineSaleRecorder (single atomic transaction sale+lines+payment+
   queue row, SAME clientSaleId reused so replay dedupes); SyncEngine FIFO drain
   with exponential backoff, price-drift pre-check (conflict PRICE), stock/product
   conflicts kept for review, 401 pauses without burning attempts; ConnectivityMonitor
   (probe + hysteresis, never trusts connectivity_plus alone); 72 h offline window
   anchored to last real auth (SessionJournal); logout warns about pending count;
   sync status sheet + 🟢🟠 banners in Swahili only. Backend: TenantActiveMiddleware
   (30 s cached) enforces suspension on every authenticated request + 3 integration
   tests. flutter analyze clean; 110/110 tests green (33 new). Real E2E m5_e2e.sh:
   offline queue → API restart → reconnect sync → lost-response retry →
   timeout-after-acceptance → exactly-once per key → oversell rejected untouched →
   suspended tenant blocked (403) then reactivated → final stock math exact.
   Debt: no delta-pull APIs (full refetch v1); suspension cache delays enforcement
   ≤30 s; SQLCipher absent on Linux desktop builds (warns loudly).
- 2026-08-23: M4 complete (Flutter-only; backend sales engine reused as-is).
   Sales feature end to end: domain (CartLine/PaymentMethod ints, SaleDto parsers,
   buildCreateSaleBody, buildReceiptText), SaleRepository (create with
   Idempotency-Key header, getById, list, resolvePrice), CartController,
   CheckoutController (clientSaleId drawn once per logical sale and kept across
   retryable network/server errors so retries never double-charge; cleared after
   success or definitive rejection; pre-submit price re-resolve per line),
   SalesHistoryController (today window). Pages: PosPage (search + grid +
   cart bar), CartSheet, PaymentSheet, SaleSuccessPage, ReceiptPreviewPage
   (copy + save .txt — no printer stack in M4), SalesHistoryPage, SaleDetailPage.
   Router: /pos, /pos/success, /sales, receipt + detail routes; home tab 0 = POS.
   posBranchIdProvider fetches first branch (WorkspaceDto has no BranchId).
   Design decision (user-approved): cart shows Jumla only with "Bei zinajumuisha
   kodi." hint — shelf prices are tax-inclusive server-side and there is no
   tax-rules read API, so exact Subtotal/VAT split is shown only on the success
   screen/receipt from server truth. flutter analyze clean; 77/77 tests green
   (14 new). Backend 540/540 unchanged. Real-API E2E (/tmp/opencode/m4_e2e.sh)
   verified: register→verify→onboard→branch→product→price→opening stock→resolve
   →cash sale S-2026-000001 (subtotal 5000, VAT 762.71 tax-inclusive, total
   5000)→GET by id→stock 50→48→oversell 400→same Idempotency-Key replay returns
   ORIGINAL sale with exactly 1 row in DB→today's sales list→API restart→fresh
   login→sale + stock still correct. Debt: cart VAT split hidden until payment;
   receipt unit prices shown without TSh symbol; no void/refund UI yet.
- 2026-08-24: Android device bring-up on SM-T865 (session ended mid-fix — see
   "Open blockers" above). Release builds failed 3× with R8/dex duplicate-class
   (`Sqlite3FlutterLibsPlugin` shipped by BOTH sqlite3_flutter_libs and
   sqlcipher_flutter_libs) → removed sqlite3_flutter_libs + drift_flutter;
   sqlcipher_flutter_libs is now the sole SQLite plugin (pubspec note added).
   Post-fix verification: flutter analyze clean, 110/110 tests green, debug +
   release APKs built (36.6 MB release), release installed on tablet. On-device
   findings left OPEN: providers.dart:287 analyzer error introduced by the last
   edit; release-mode dlopen of libsqlite3.so fails (only libsqlcipher.so
   bundled); tablet could not reach the dev API (offline banner). No commits
   made yet for any MVP work.
- 2026-08-24 (late): eternal-splash root-caused & fixed (see blockers #2).
   Diagnosis via adb logcat + VM-service widget-tree inspection on the live
   tablet. Two fixes: journeyRedirect no longer parks unauthenticated users
   on splash (+ regression test), health probe marked skip_auth, bootstrap
   watchdog 10 s. Verified live: app now reaches Login/Register on the SM-T865.
   Tablet data cleared during debugging — re-register on device.
- 2026-08-25: M9 complete (backend + Flutter). Backend: PhoneNumber value
   object (E.164 normalize; TZ default +255, KE +254/UG +256 dialled
   explicitly); register requires phone + makes business name optional with a
   placeholder tenant name ("Biashara ya {firstName} #{id4}" — Tenant.Name has
   a global unique index); unique filtered index on Users.Phone +
   migration AddUniqueUserPhone. Login accepts ONE `identifier` field
   (BREAKING: wire field renamed email→identifier; contains '@' → email else
   phone lookup). CreateUser/UpdateUser admin commands now normalize/dedupe-
   check phones too. Password reset end to end: PasswordResetCode (SHA-256
   hash-only, TTL 30 min, 5 attempts, 60 s resend cooldown), silent-success
   forgot endpoint (anti-enumeration), reset also verifies email + clears
   lockout + revokes all refresh tokens; migration AddPasswordResetCodes.
   Backend tests: TestPhones.Next() process-unique phones (shared persistent
   DB!), historical duplicate phones scrubbed from businessos_test once;
   new unit tests for PhoneNumber + AuthFlowTests for every new flow.
   Flutter: PasswordField (show/hide toggle) + strength meter (5-check
   heuristic), auth_error_mapper (per-field errors from ProblemDetails +
   409 keyword mapping), forgot/reset/terms pages wired into the router
   (all public screens), LoginPage = one identifier field + brand mark,
   RegisterPage = optional business name w/ helper text + required TZ-hinted
   phone + confirm password + terms checkbox linking TermsPage. i18n
   scaffold (M9.9): flutter_localizations + gen-l10n (l10n.yaml,
   synthetic-package:false → lib/l10n/generated), EN/SW ARBs (~70 strings),
   LocaleStore in secure storage restored before first frame, EN|SW switcher
   on all auth screens, every auth string goes through context.loc (Swahili
   fallback so widget tests need no delegates). dart analyze clean;
   125/125 flutter tests green; backend suite green after fixture fixes
   (563 total). Debt: reset-code emails still dev-outbox only (no SMTP);
   language switcher not on in-app (post-login) screens yet; docs/APIStandards.md
    does not document endpoint bodies — API contract changes recorded here only.
- 2026-08-28: M9.1 staff join-by-invitation-code done (backend + Flutter).
    Backend: InvitationCode entity (8-char A–Z code, SHA-256 hash-only, TTL 72 h,
    5 attempts, single-use) + InvitationCodes table (unique CodeHash, migration
    AddInvitationCodes); SystemRoles.Staff + a limited PermissionNames.Staff
    permission set (dashboard/view, sales create/view/reports, product/category/
    brand/unit/inventory/warehouse view — no admin/tenant ops). POST
    /api/v1/users/invitations (RequirePermission Users.Create) issues a code and
    returns it once as { code, expiresAtUtc }; POST /api/v1/auth/register-staff
    redeems it: attaches the user to the code's tenant + HQ branch with the
    Staff role, without creating a tenant or an Administrator. Staff registration
    auto-activates (the code is the owner's approval), emails a verification code,
    and audit-logs the join. InvitationStaffFlowTests: 6/6 green (auth-guard,
    valid-code join as active staff, same-code-twice rejected, duplicate-phone
    conflict, full journey w/o admin perms, invalid-code validation).
    Flutter: RegisterPage gained an Owner/Staff segmented toggle — staff tab adds
    the invitation-code field (8-char validator) and calls registerStaff; the
    business-name field was removed from the register form entirely (business
    naming moved to onboarding, CreateBusinessPage). AuthRepository.registerStaff
    + issueInvitation, AuthController.registerStaff. New owner-only StaffPage at
    /staff (generates + copy-to-clipboard + expiry), surfaced in the "Zaidi" tab
    only for owners (Users.Create permission). ARB strings added for the staff
    flow. dart analyze: only 2 pre-existing checkout_controller warnings + 1
    pre-existing unused import; 129/129 flutter tests green.
- 2026-09-22: M13 backend slice written (code-only; build/tests run on the next
    permitted session). Freemium monetization on free hosting: platform plan
    catalog (Free = POS+inventory backstop; Pro = TZS 25,000/mo, quota
    branches=3/users=5/products=3000) + per-tenant Subscription (14-day Pro trial
    auto-granted at registration/provisioning, backfilled for legacy tenants by
    the seeder) + prepaid voucher codes (CSPRNG `XXXX-XXXX-XXXX`, unambiguous
    alphabet, 1–365 days) + per-tenant Invoices (renewal invoice auto-issued on
    trial lapse; PDF rendered client-side from the DTO — offline-first decision,
    no server PDF endpoint). New permissions Billing.View + Billing.Manage.
    Enforcement: SubscriptionAccessMiddleware 402s premium writes while a
    subscription is in debt (reads + POS/inventory writes keep working);
    entitlement derived purely from dates by a stateless evaluator and cached
    30s. Commands/queries: GetSubscription (entitlement), ListPlans,
    ListInvoices, GetInvoice, RedeemVoucher, EvaluateSubscription (idempotent
    self-heal), owner desk MarkInvoicePaid (extends subscription by payable
    window — the manual M-Pesa settlement path) + IssueVouchers + ListBillingDebts
    under /admin/billing. Migration `20260922000000_AddPlansSubscriptionsVouchers
    Invoices` (hand-written Up/Down + snapshot + Designer that delegates BuildTargetModel
    to the snapshot so a future `dotnet ef migrations add` cannot drift it; the
    three additive billing tables reuse the "attribute-only Designer" pattern
    from slice-8/9 plus a slight variant). Unit tests (evaluator, entity state
    machines, code format/unambiguity) + integration suite
    (BillingEndpointsTests) written. Flutter billing page + client feature gating
    are the next task (deferred). Pricing note: legacy docs quote USD Starter/
    Growth/Pro — actual MVP catalogs Pro at TZS 25,000/mo; Flutterwave phase
    replaces manual voucher/M-Pesa settlement later.
- 2026-09-25: M13.1 written (code-only; still unverified — the M13 row stays
    `partial` until the user runs build/analyze/tests). Flutter billing client
    shipped: domain/repository/providers/controller, `/billing` page + home tile,
    invoice PDF share, EN/SW strings, `PaymentRequiredException` with a
    single-flight entitlement refresh on 402, debt lock + premium route redirects,
    and product price fields gated on full access. Backend hardening: reads
    short-circuit before entitlement access; disabled module on a write → 403
    ModuleDisabled; pricing/price-lists mapped in ModuleRouteMap; quota checks on
    branch/user/product creation under the tenant advisory lock; feature-flag
    toggles now raise `FeatureFlagChangedEvent` so the 30s entitlement cache
    invalidates post-commit; evaluate/redeem self-heal in one round trip via EF
    local-tracker visibility; `SetFeatureFlag` no longer enables a flag when
    `IsEnabled=false` with a config payload. Tests added on both sides (unrun).
    Known edge: product metadata + price are two requests, so a 402 on the price
    write leaves metadata saved.
