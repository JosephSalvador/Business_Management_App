# Business OS — Roadmap & Architecture Plan

> Goal: the African alternative to Odoo, Zoho, SAP Business One, and Microsoft Dynamics 365.
> Compete on offline capability, mobile-first design, simple UX, local payments, and local business workflows — not on feature count.
>
> **Strategic posture:** build a **platform**, not an ERP. The product is a *Business Operating System* — a set of platform capabilities (auth, tenants, RBAC, audit, events, workflows, reporting, sync, plugins, APIs) that every future business module reuses. Industry modules are grown on top, not written from scratch.

---

## 1. Current State (mapped 2026-08-05)

The repo is a **Flutter client-only app**. No backend exists. Three data systems coexist, only one is live:

| System | Status | Used by the running app? |
|---|---|---|
| SharedPreferences (`LocalStorageService`) | Live | Yes — auth session, saved printer |
| In-memory mocks (mock users, products, sales history) | Live | Yes — auth, products, sales list |
| Drift SQLite (`app_database.dart`, 11 tables, offline-sync schema) | Built, **dead code** | No — never instantiated outside tests |

### Module status

| Module | Status | Notes |
|---|---|---|
| Auth | Partial | Login mock works (5 hardcoded users). Register/forgot/verify = UI-only TODOs. |
| Dashboard | Partial | UI complete, stats hardcoded, quick-action buttons no-op. |
| Menu / Navigation | Complete | GoRouter + privilege-filtered drawer. |
| User Management | Partial | Hardcoded 5 users; add/filter dialogs empty. |
| Product Management | Stub | Empty page, commented-out repo. |
| Sales | Partial | Real VAT (dual VAT A/B), real Bluetooth ESC/POS printing, real TRA TIN API with mock fallback. Products mocked, payments simulated, history in-memory (lost on restart). |
| Reports | Stub | "Coming Soon". Not routed. |
| Settings | Stub | "Coming Soon". Not routed. |
| Drift DB + repositories | Complete but disconnected | 11 tables with `remoteId/syncStatus/deletedAt` — offline-first design already modelled. |
| Tests | 2 files, 4 tests | Drift enum/seeder + User JSON. |

**Unrouted pages:** Settings, Reports, Products, EmailVerification, UserSelection.

**Biggest gap:** the offline-POS foundation (last commit) is disconnected from the running app.

---

## 2. Product Architecture — Layers of Capability

Never think "a folder per feature." Think **layers of capability**:

```
BusinessOS
├── Platform                    ← build FIRST, reuse everywhere
│   ├── Authentication          │  JWT + refresh, MFA, phone/email OTP, social
│   ├── Organizations/Tenants   │  branches, subscriptions
│   ├── RBAC (permissions)      │  e.g. Sales.Create, Accounting.Approve
│   ├── Audit Logs              │  every mutation, traceable
│   ├── Notifications           │  email, SMS, WhatsApp, FCM — via one engine
│   ├── Search                  │  products, invoices, customers, documents
│   ├── Files (object storage)  │  receipts, contracts, images, backups
│   ├── AI                      │  NL queries, OCR, insights — one engine
│   ├── Workflow Engine         │  no-code approvals & pipelines
│   ├── Automation / Rules      │  when X → do Y
│   ├── Reporting / Report Builder
│   ├── Payments / Sync
│   ├── Feature Flags
│   ├── Dynamic Forms & Settings (configurable everywhere)
│   └── Plugin System           ← the moat — ecosystem, not product
│
├── Core Business               ← MVP scope
│   ├── CRM       ├── Sales    ├── Purchasing
│   ├── Inventory ├── Accounting ├── POS
│
├── Enterprise                  ← Phase 2
│   ├── HR       ├── Payroll  ├── Manufacturing
│   ├── Projects ├── Assets   ├── Fleet     ├── Help Desk
│
└── Industry Modules            ← Phase 3+, grown by partners
    ├── Agriculture ├── Hospital ├── School ├── Hotel
    ├── Construction ├── Logistics ├── Wholesale
```

Growth rule: a capability graduates up. Industry modules are thin skins over Platform + Core Business engines — they add fields, workflows, reports, and localizations, not parallel implementations.

---

## 3. System Architecture — Modular Monolith

**Decision: do NOT start with microservices.** Start as a **modular monolith** — one deployable host, modules as vertical slices. Split into services only when a module's team/speed/scale demands it (this is exactly how Odoo/Zoho-class platforms evolved).

```
                ┌───────────────────────────────┐
                │        BusinessOS.Api          │  ONE deployment
                │      (modular monolith)        │
                │                                │
                │  ┌─────────── Platform ───────┐│
                │  │ Auth · Tenants · RBAC ·    ││
                │  │ Audit · Notifications ·    ││
                │  │ Search · Files · Settings  ││
                │  │ Workflow · Automation ·    ││
                │  │ Reporting · Sync · Plugins ││
                │  └────────────────────────────┘│
                │  ┌───── Modules ──────────────┐│
                │  │ CRM  Sales  Inventory      ││
                │  │ Acct  POS   Purchasing     ││
                │  │ HR   Payroll Mfg  ...      ││
                │  └────────────────────────────┘│
                └───────────┬───────────────────┘
                            │
              ┌─────────────┴──────────────┐
              │ In-process Event Bus        │ (outbox → reliable)
              │ Redis · PostgreSQL · S3/MinIO│
              └─────────────┬──────────────┘
                            │
                  Workers (outbox, sync,
                  reports, automation)  — same modules, separate process, same deployment
```

### Event-driven by default

Modules never call each other. They raise domain events; other modules listen.

```
POS: SaleCompleted ──► Inventory (reduces stock)
                     ──► Accounting (posts journal entry)
                     ──► Notifications (SMS receipt)
                     ──► Analytics (aggregates)
                     ──► Audit (writes log)
```

First-class domain events: `SaleCompleted`, `StockReduced`, `InvoiceCreated`, `PaymentReceived`, `CustomerRegistered`, `PurchaseApproved`, `EmployeeCreated`. Events are persisted through an **outbox** → delivered reliably even if a consumer crashes.

### Business Engines (reusable, not per-module)

| Engine | Responsibility |
|---|---|
| Workflow Engine | No-code approval pipelines (PO → manager → finance → director → pay) |
| Notification Engine | One API → email/SMS/WhatsApp/FCM/push, per-tenant templates |
| Approval Engine | Escalations, delegation, SLAs |
| Tax Engine | Country rules, versioned, effective-dated (TRA 18/16 dual VAT, KRA, etc.) — no code per country |
| Document Engine | Storage, versioning, signing, approvals |
| Search Engine | Indexes everything; `ISearchService` abstraction (OpenSearch behind it) |
| Payment Engine | `IPaymentProvider` — M-Pesa Daraja, Airtel, Tigo, Mixx, cards |
| Sync Engine | Offline queue → idempotent REST sync → conflict merge |
| Report Engine | PDF/Excel/CSV/charts + user-defined report builder |
| Rule/Automation Engine | "When invoice paid → SMS → receipt → update stock → notify manager" |
| AI Engine | NL queries, OCR receipts, document extraction, predictions |
| Plugin Engine | Install/enable/disable/update/license third-party modules |

---

## 4. Backend Repository Layout (Modular Monolith)

```
backend/
├── BusinessOS.slnx
├── src/
│   ├── Shared/                 BusinessOS.Shared      — shared kernel: Result, Error, Entity, ValueObject, IDomainEvent
│   ├── Domain/                 BusinessOS.Domain      — platform domain: Tenant, User, Role, Permission, AuditLog, FeatureFlag, events
│   ├── Application/            BusinessOS.Application — platform use cases (CQRS/MediatR), contracts/interfaces
│   ├── Infrastructure/         BusinessOS.Infrastructure — EF Core (Postgres), Redis, JWT, BCrypt, event bus, outbox, seeding
│   ├── Api/                    BusinessOS.Api         — modular monolith host (composition root, controllers, Swagger)
│   ├── Notifications/          BusinessOS.Notifications — email/SMS/push interfaces + implementations
│   ├── Workers/                BusinessOS.Workers     — background hosts (outbox, sync flush, automation, reports)
│   └── Modules/                BusinessOS.Modules.*   — one project per business domain (vertical slice)
│       └── Sales/              BusinessOS.Modules.Sales — reference implementation of the module pattern
└── deploy/
    └── docker-compose.yml      — postgres, redis, minio, api, workers
```

Each module owns its models, rules, events, commands, and queries (DDD). Platform contracts live in `Application`; modules reference them but not each other.

**API-first:** every feature ships a REST endpoint before a screen. Flutter is a client of the API, never the owner of business logic.

---

## 5. Non-Negotiable Architecture Decisions

1. **Backend: ASP.NET Core (.NET 10)**, modular monolith first, Clean Architecture + CQRS (MediatR).
2. **Database: PostgreSQL**; **Cache/queue: Redis**; **Search: OpenSearch behind `ISearchService`**; **Files: S3-compatible** (MinIO self-hosted, R2/S3 cloud).
3. **Auth: JWT + refresh tokens, MFA (TOTP), phone/email OTP** — extended for local flows.
4. **Multi-tenancy: shared DB, `tenant_id` on every row**, repository guardrail (never query without tenant filter). Schema-per-tenant is the documented escape hatch for enterprise.
5. **RBAC, not roles:** `Sales.Create`, `Inventory.View`, `Accounting.Approve`; roles are sets of permissions; feature flags gate module visibility per tenant.
6. **Audit log on every mutation** (actor, action, entity, tenant, IP, device, old/new).
7. **Event-driven + outbox** for anything that spans modules or side effects.
8. **Everything configurable:** tax rules (country → rules → version → effective date), numbering sequences, currencies, units, dynamic fields (custom attributes on entities), UI strings. No hardcoded business rules.
9. **Dynamic Forms:** businesses add their own fields to Customer, Product, Sale, etc. without code (schema per tenant via JSONB + metadata).
10. **Offline-first:** Drift on device → `SyncQueueItems` outbox → REST `sync` → server applies idempotently; `updatedAt` + server-wins conflict merge first, per-table strategy later.
11. **Riverpod over Bloc** — swap per feature, not big-bang. Keep go_router.
12. **Observability from day one:** structured logs (Serilog → OpenTelemetry), metrics, distributed tracing, health endpoints, per-tenant performance dashboards.
13. **Feature flags:** modules off by default; enable per tenant/beta-cohort without redeploy.
14. **Plugin system is the moat:** third-party modules appear in the sidebar, inherit permissions/notifications/reports. Start with a defined module contract + marketplace-ready packaging.

---

## 6. Foundation (Phase 0) — PLATFORM FIRST

### Backend
- [x] Modular monolith solution: Shared, Domain, Application, Infrastructure, Api, Notifications, Workers.
- [x] Platform domain: Tenant/Organization, User, Role, Permission, FeatureFlag, AuditLog; RBAC seeded.
- [x] JWT auth (access + refresh), BCrypt, login/register/refresh endpoints.
- [x] EF Core + PostgreSQL, migrations, seed (admin tenant + roles + permissions), health checks.
- [x] Redis cache interface (in-memory fallback for dev) + in-process event bus with outbox table.
- [x] Audit log service writing every mutation.
- [x] Notifications interfaces (Email/SMS/Push) with logging implementation.
- [x] Reference module `BusinessOS.Modules.Sales` proving the slice pattern: domain entity, `CreateSale` command, `SaleCompleted` event consumed by audit + notifications.
- [x] Dev infra: `deploy/docker-compose.yml` (postgres, redis, minio).
- [ ] Structured logging + health/metrics endpoint (OpenTelemetry).
- [ ] Feature-flag service (table + API).
- [ ] Tenant provisioning endpoint.

### Flutter
- [x] Wire Drift `AppDatabase` into the running app (composition root in `bootstrap.dart`).
- [x] Persist products and sales to SQLite (replace in-memory mocks); seed starter products.
- [x] Route Settings, Reports, Products pages.
- [ ] Riverpod migration starts (per-feature, Phase 1).

### Definition of done for Phase 0
- `dotnet build` + `flutter analyze`/`flutter test` pass.
- Backend boots; Swagger serves `/api/auth/login`; admin logs in → JWT; a sale raises `SaleCompleted` → audit row written.
- Flutter app survives restart: sales + products return from SQLite.

---

## 7. Phase 1 — Core Business MVP (server-backed)

Platform (Phase 0) → then Core Business modules, in this order:

1. **Auth (real)** — server login/register, refresh, OTP, offline session.
2. **Organizations & Branches** — tenant hierarchy. `[x] backend slice 2026-08-06` — spec
   `specs/organizations-branches.md`; Flutter onboarding screens + Drift `branches` cache are
   the follow-up (POS phase).
3. **Users, Roles & Permissions** — CRUD against server RBAC + feature flags.
   `[x] backend slice 2026-08-13` — spec `specs/users-roles-permissions.md` (domain,
   repositories, application layer, `IdentityEndpoints`, activity-feed handler, 154 tests);
   Flutter admin screens are the follow-up.
 4. **Product & Inventory Foundation (Slice 3)** — **build before Sales/POS** so a sale always
    resolves a real product/SKU/unit/price/tax/branch/stock. See "Slice 3 — Product & Inventory
    Foundation" below. `[x] sub-slice 3a Product Catalog 2026-08-13` — spec
    `specs/products-inventory.md` (domain, migration, repositories, application, API,
    activity-feed consumer, 181 tests). 3b Inventory Foundation and 3c Pricing Engine remain.
5. **Dashboard** — real aggregates from events (revenue, VAT, top products, receivables).
6. **Sales + Offline POS** — offline-first POS, barcode, thermal print (already works), returns,
   discounts, loyalty, multiple payments incl. **mobile money** (M-Pesa, Airtel Money, Tigo
   Pesa, Mixx by Yas, HaloPesa).
7. **Inventory** — products, warehouses, stock movements, counts, transfers, batches.
8. **Purchasing** — suppliers, RFQs, POs, goods-received, supplier bills.
9. **Accounting basics** — chart of accounts, journal entries, general ledger, trial balance.
10. **Reporting + Tax** — PDF/Excel/CSV, TRA e-receipt compliance, VAT summaries; tax rules
    loaded from config (no hardcoding).
11. **Workflow Engine v1** — approvals for purchases, expenses, sales discounts.
12. **Dynamic Forms v1** — custom fields on Customer/Product/Sale.

### Slice 3 — Product & Inventory Foundation (proposed next)

To be designed end-to-end before any Product/Inventory code is written — the product model
feeds Sales/POS, Purchasing, and Accounting, so it must be right first.

```
Product Catalog   → SKU, barcode, categories, brands, units of measure,
                    variants, images, status, product types
Business Pricing  → per-branch prices, retail/wholesale, customer-specific prices,
                    price lists, effective dates, min-quantity pricing, discount rules
Inventory         → warehouses, stock locations, opening stock, stock balances,
                    stock movements, adjustments, transfers, reservations
```

- Multi-branch stock follows the existing `Branch` architecture
  (Company → Branch → Warehouse/Shop), making Slice 1's branch model genuinely useful.
- **Country-pack principle:** do **not** hardcode Tanzania into the core domain. Core carries
  the generic engines; a **Tanzania Country Pack** (TZS, VAT, TRA-compatible tax, EFD
  integration architecture, M-Pesa/Airtel/Mixx/HaloPesa/bank/cash) ships alongside, with
  Kenya/Uganda packs to follow. Core = African Business OS; packs = per-country compliance.
- Work order: Product Catalog → Inventory Foundation → Pricing Engine → Customers → Sales
  Domain → Offline POS → Payments (Phase 1 "commercial engine").

**MVP non-negotiables:** offline with reliable sync, mobile money, TRA fiscal compliance, Swahili UI, low bandwidth, guided onboarding < 10 min, audit on every write, events on every mutation.

**Feature slice (proves the whole stack):**
```
POS (drift) → save Sale + items → SyncQueueItems outbox
→ worker flushes → POST /api/sync → CreateSale command → SaleCompleted event
→ outbox → audit writes log + notifications queue SMS → ack
```

---

## 8. Phase 2 — Enterprise & Scale (6–12 months)

- HR (employees, attendance, leave, recruitment, performance, documents)
- Payroll (salary structures, payslips, taxes, allowances, deductions — country-specific)
- Projects (tasks, Gantt, Kanban, time tracking)
- Assets (depreciation, maintenance, register)
- Fleet (vehicles, fuel, service history)
- Help Desk (tickets, SLA, support)
- Documents (file storage, versioning, approvals)
- Analytics (dashboards, KPIs, forecasts)
- Customer portal
- **Report Builder** (users build their own columns/filters/charts/groupings)
- **Workflow Builder v2** (full no-code designer)
- MFA hardening, accountant/auditor roles, import/export tooling
- OpenTelemetry dashboards per tenant; search indexing via OpenSearch

---

## 9. Phase 3 — Platform Ecosystem (12+ months)

- **Plugin System + Marketplace** — third-party modules install/enable/update/license; appear in sidebar; reuse permissions, notifications, reports.
- **Public API + SDKs** — Flutter, .NET, Java, Python, JS SDKs; OpenAPI-first.
- Manufacturing (BOMs, production orders, work centers, QC)
- **Automation/Rule Engine** (no-code triggers)
- **AI Engine** — NL queries ("which customers haven't paid this month?"), OCR receipts, document extraction, inventory/dunning predictions.
- Industry modules (Agriculture, Hospital, School, Hotel, …) built *by partners* on the platform.
- Event-sourced reporting / Power BI connector.

---

## 10. Deployment Strategy

- **Cloud SaaS** (default) — Api + Workers behind TLS; tenant-isolated data.
- **Self-hosted / on-premises** — Docker Compose/Helm; customers keep their data.
- **Offline desktop** — Flutter desktop + local SQLite, optional sync to a company server. Many African SMEs value owning data and running without constant internet.

---

## 11. Key Risks & Open Decisions

| Risk/Decision | Plan |
|---|---|
| Offline sync conflicts | `updatedAt` + server-wins first; per-table strategy config; tests on device loss |
| Multi-tenancy isolation | Row-level `tenant_id` + repository guardrail; escape hatch: schema-per-tenant |
| Mobile money integrations | `IPaymentProvider` adapters per provider (Daraja, Airtel, Tigo); separate sandboxes |
| Country tax rules | `TaxEngine`: country → rules → version → effective date; TRA dual VAT proven in app |
| Riverpod vs Bloc churn | Per-feature swap behind feature flags; keep go_router |
| Plugin security | Modules run in-process → strict contract, signature/licensing, sandboxed storage keys |
| Feature creep | Every module ships with offline + audit + RBAC + events from day one or it doesn't ship |
| Fiscal compliance | TRA/URSB e-invoicing; fiscal QR on receipts per country |
| Bloat trap (again) | Cap features per phase; platform capabilities gate everything |

---

## 12. Positioning

| Capability | Odoo/Zoho | This platform |
|---|---|---|
| Offline-first POS | Weak | Core design |
| Mobile money | Add-on | First-class via Payment Engine |
| Local tax (TRA etc.) | Generic | Versioned country Tax Engine |
| Swahili + local languages | Partial | First-class |
| Low-bandwidth | Poor | Optimized |
| SME pricing | High | Affordable, per-branch |
| Onboarding | Complex | Guided, < 10 min |
| Ecosystem/plugins | Yes (mature) | Plugin system by design from day one |

**The moat is not modules — it is the platform.** Tenants, RBAC, audit, events, workflows, sync, and plugins. Build those first and every industry module that follows is cheap.
