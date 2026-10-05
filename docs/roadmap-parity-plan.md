# Roadmap — Competitive Parity & Modularity

> Written 2026-10-01 after a static scan of GMS TradeSoft ERP (`app.gmstradesoft.com`).
> Source: the app's own public assets — 250 route literals and 89 service-worker-precached
> page chunks. **No authentication, no decryption, no source reconstruction.** Everything
> below about their product is inferred from route names and bundled component names, so
> treat module *presence* as reliable and module *quality* as unknown.
>
> Specs live in `specs/`; task breakdowns in `tasks/`. Approval is per-milestone —
> do not start a milestone whose spec is not approved.

## Why this document exists

GMS is a broad ERP with a comparable surface to ours. This plan states, once, which of
their features we adopt, which we deliberately skip, and in what order — so that
"should we build X?" is answered by a document instead of a fresh debate each time.

## Where we are already ahead — protect these

These are the differentiators. Do not dilute them chasing parity on the table below.

| Their gap | Our position |
| --- | --- |
| **No offline.** No IndexedDB, no Dexie, no `navigator.onLine`. Install-only PWA; precaches the whole app on first visit. | M5 offline-first POS + Drift sync; M9.2 offline-invisible login; 72h window; local encrypted store (SQLCipher) |
| **No receipt printer path** — `jspdf` + `html2canvas` only | M7 `Thermal80mmRenderer` — one source of truth for screen, text, PDF and ESC/POS |
| **No fiscal/tax engine** surfaced | Dual-VAT (`TzDualVatTaxStrategy`), TRA-ready, plug-in localisation per `ArchitectureRules.md` |
| **Ad-hoc add-on sprawl** (`/subscription/addons/*`) | M13/M13.2 entitlement formula `(plan ∪ packages) ∩ flags`; packages never widen a tenant past its flags |
| **90-item sidebar**, role-filtered only | `ux.md` progressive complexity — gate by *business scale*, not by role |
| Stock blocks sales | Advisory stock, never blocks — correct for African retail |
| ~22 invoice templates | Template rendering is presentation-only in our model, not a domain concern |

## Corrected scope

An earlier draft of this plan assumed purchases and invoicing were unbuilt. Both ship:

- `Domain/Purchasing` — 7 files (`Supplier`, `PurchaseOrder`, `PurchaseOrderLine`,
  `SupplierBill`, `SupplierPayment`, 2 enums). `Features/Purchasing` — 4 files.
  `specs/purchasing.md` sub-slices 8a–8c are `[x]`. Flutter `features/purchases` +
  `features/suppliers` with full CRUD and routes.
- `Domain/Invoicing` — `CustomerInvoice` + lines + status (M13.2). Flutter
  `features/invoices`, routes wired.

Only `tasks/purchasing/TASKS.md` 8d is outstanding, blocked on Postgres. That is a
verification task, not a build.

## Modularity decision

**Keep the folder-based structure. Do not mass-migrate to `Modules/*` assemblies.**

`docs/roadmap.md:157` promises one project per module, but `backend/src/Modules/Sales`
contains **only `obj/`** — no source. Everything real lives as `Domain/<Area>/` +
`Application/Features/<Area>/`. "Modularity" today is folder-level, not assembly-level.

Splitting `Domain/Catalog` and `Domain/Sales` into assemblies buys compile-time
enforcement of a rule we are not currently breaking, at the cost of a large risky
refactor across a system with 597 backend + 261 Flutter tests. Bad trade.

Instead, **go vertical from here**:

1. New domains with a hard external dependency (`DocumentIntelligence`, `Hr`) start as
   real `Modules/*` projects — a worked reference for the plugin contract (rule 14).
2. Existing features stay as folders. No rewrite of working code.
3. Enforce what actually matters, and is greppable:
   - no `Features/X` → `Features/Y` references
   - cross-module effects via domain events + outbox only (rule 7)
   - new shared capability → `Application/Ports` interface, impl in `Infrastructure`

A full assembly split can wait until the plugin marketplace makes it load-bearing.

## Sequencing

```
Wave 1  Security & onboarding            ← launch bar
  M14   TOTP MFA + session management            [spec ready, awaiting approval]
  M15   Catalog Excel import                     [planned]

Wave 2  Revenue & procurement                  ← schools & hospitals
  M16   Quotations + document templates         [planned]
  M17   Purchases 8d integration verification   [planned]

Wave 3  Differentiators
  M18   OCR document intelligence               [planned]
  M19   Scheduled reports                       [planned]
  M20   HR: employees + attendance              [planned]
```

## Wave 1

### M14 — TOTP MFA + session management · `specs/mfa-sessions.md`

Closes the debt logged in M10.3: a stolen refresh token is currently unbounded, and a
lost device is a support ticket. Scope and the two scope decisions (owner-level
enforcement, no offline gating) are in the spec.

### M15 — Catalog Excel import

**Why.** Our onboarding assumes an empty catalog. The target user is a shop *already
trading*, with data in a spreadsheet or a previous system. This is a conversion killer.

**Shape.** Deliberately generic, in `Application/Features/Common/Import/`:
`IImportHandler<T>` with `ValidateAsync` / `CommitAsync`, exposed as two-phase
`.../preview` then `.../commit` — matching the reference app's `/import` + `/import-rows`
split.

**Non-negotiable: no bulk-insert fast path.** Import replays through the ordinary
`CreateProductCommand`. Domain invariants, events and audit all apply. A shop's catalog
is hundreds of rows, not millions; correctness wins. Template download endpoint;
per-row `Valid`/`Warning`/`Error` with row number; in-file duplicate SKUs are per-row
errors, not a whole-file abort; 5,000-row cap.

**Client.** `ImportWizardPage`: template → file → preview table with row errors →
commit → summary. Behind feature flag `catalog.import.enabled` (rule 13: modules off by
default). Permission `Catalog.Import` — owner/admin, never cashier.

## Wave 2

### M16 — Quotations + document templates

Cheapest item in the plan — `Domain/Invoicing` already ships.

New `Quotation` aggregate mirroring `CustomerInvoice`'s status flow
(`Draft → Sent → Accepted/Declined → Converted/Expired`) with `ConvertToInvoice`.
**Templates stay presentation-only**: store `TemplateCode` on the document, layouts in
Flutter assets. Reuse the M7 single-source-of-truth rendering pattern; do not build a
second rendering engine.

*Open decision for the spec:* credit note as a separate `CreditNote` aggregate
(recommended — keeps numbering and audit clean) versus a reversal of `CustomerInvoice`.

### M17 — Purchases verification

`tasks/purchasing/TASKS.md` 8d is `[!]` blocked on Postgres. Get
`localhost:5432` running (`podman postgres:17`, see `database.md`), run the suite, fix
what breaks, flip 8d to `[x]`. **No new features.** Fix defects only.

## Wave 3

### M18 — OCR document intelligence

First real `Modules/` project. Justified by a hard external dependency, per-tenant cost,
and a plausible third-party contributor — all three argue against coupling it to Catalog.

Photo → `IntakeDocumentCommand` enqueues → worker calls OCR → `DocumentParsedEvent` →
Purchasing consumes it to draft a bill. Async only; a provider outage can never block
receiving.

**Cost guardrail: gate behind a package plan (`SubscriptionItem`), not a feature flag.**
A flag is free to flip; OCR bills per call. This is exactly what M13.2's `Plan.IsPackage`
exists for.

### M19 — Scheduled reports

Cheapest item in Wave 3. `IJobQueue`, outbox jobs and the notification engine
(email/SMS/WhatsApp) all exist.

`ReportSchedule` entity: tenant, report key, filter JSON, cadence, recipients, next run,
active. **Report keys stored as strings** (`"sales-summary"`), validated at runtime —
storing an enum forces a migration per new report. Reuse the existing `ReportingQueries`
handlers so a schedule renders exactly what the screen renders. Reuse `SalesReportsView`.

### M20 — HR (employees + attendance only)

**Payroll is explicitly deferred.** It is a per-country statutory rules engine (PAYE in
TZ and KE) and rule 8 forbids hardcoding — meaning a rules engine, which is a project of
its own. Do not build it until a paying customer demands it.

New `Domain/Hr`. **Do not unify `Employee` with `User`.** A user logs in; an employee is
on the payroll register. Share by id only — coupling them means a payroll defect locks
staff out of the app. `AttendanceRecord` is append-only with **no derived overtime** in
the aggregate (recompute later; overtime rules change per country). Feature-flag
`hr.enabled`; full module as a package plan later.

## Explicitly skipped

| Skipped | Reason |
| --- | --- |
| Restaurant vertical (floor plan, kitchen display) | Wrong market entirely |
| Social OAuth login | Not the buyer; adds provider dependency + support surface |
| E-commerce marketplace | Different buyer, different problem |
| Their dual `/inventory` + `/warehouse` model | Two parallel inventory models, overlapping children (`/brands` *and* `/warehouse/products/brands`). Likely a half-finished v2 migration — and if so, a correctness bug, not just clutter. We have one model. Do not copy the ambiguity. |
| A 90-item sidebar | Our progressive-complexity thesis is the moat. Copying breadth destroys it |
| Google Analytics / any tracking SDK | No third-party tracking in our app |
| Their precache-everything PWA strategy | Downloads the entire app before first paint. Fatal on our low-bandwidth targets |
| Payroll, production/BOM, logistics, drivers, delivery notes, meetings | Enterprise-distribution shaped or too large for the current buyer |

## Method note

The scan used only publicly-served assets: response headers, `manifest.webmanifest`, the
Vite entry bundle, and the service worker precache manifest. No credentials were used and
no authenticated traffic was captured.

Next step to deepen this: export a HAR from an authenticated session of **our own** test
tenant and re-run the comparison against real payloads, response shapes and permission
gating. The route map here is complete; the data model and behaviour are not.
