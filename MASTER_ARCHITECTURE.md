# Business OS — Master Architecture

> **Single source of truth.** Read this first, then `docs/ArchitectureRules.md`,
> `docs/CodingStandards.md`, `docs/APIStandards.md`, and `docs/Security.md` for detail.
> Anything in this file wins; if you find a contradiction, update this file and the
> referenced doc together.

---

## 1. Vision

Business OS is the African alternative to Odoo, Zoho, SAP Business One, and Microsoft
Dynamics 365. It competes on **offline capability, mobile-first design, simple UX, local
payments, and local business workflows** — not on feature count.

Target users: small shops, retail, wholesale, manufacturing, schools, hospitals, hotels,
and agriculture across East Africa first (Tanzania, Kenya, Uganda).

Strategic posture: build a **platform**, not an ERP. The product is a *Business Operating
System* — a set of platform capabilities (auth, tenants, RBAC, audit, events, workflows,
reporting, sync, plugins, APIs) that every future business module reuses. The moat is the
**platform**, not the modules.

## 2. Product layers

```
BusinessOS
├── Platform          ← build FIRST, reuse everywhere
│     Auth · Tenants · RBAC · Audit · Notifications · Search · Files
│     Workflow · Automation · Reporting · Payments · Sync · Feature Flags
│     Dynamic Forms · Settings · Plugin System (the moat)
├── Core Business     ← MVP scope
│     CRM · Sales · Purchasing · Inventory · Accounting · POS
├── Enterprise        ← Phase 2
│     HR · Payroll · Manufacturing · Projects · Assets · Fleet · Help Desk
└── Industry Modules  ← Phase 3+, grown by partners
      Agriculture · Hospital · School · Hotel · Construction · Logistics · Wholesale
```

Growth rule: a capability graduates up. Industry modules are thin skins over Platform +
Core Business engines — fields, workflows, reports, localizations — never parallel
implementations.

## 3. System architecture: Modular Monolith

**Do NOT start with microservices.** One deployable host, modules as vertical slices.
Split into services only when a module's team/speed/scale demands it.

```
┌──────────────────────────────────────────────────┐
│ BusinessOS.Api  (modular monolith, ONE deploy)   │
│  Platform: Auth·Tenants·RBAC·Audit·Notifications│
│           Search·Files·Settings·Workflow·Autom· │
│           Reporting·Sync·Plugins                 │
│  Modules: CRM·Sales·Inventory·Acct·POS·Purchas. │
└──────────────────────┬──────────────────────────┘
        outbox → reliable delivery
┌──────────────────────┴──────────────────────────┐
│ PostgreSQL · Redis · MinIO/S3 · (OpenSearch)    │
└─────────────────────────────────────────────────┘
        Workers (outbox, sync, jobs, automation)
        — same modules, separate process, same deployment
```

Rules:
- Modules reference platform contracts (`Application`) but **never** other modules.
- Everything cross-module goes through **domain events** (outbox-backed), never direct calls.
- Workers are the same modules in a separate process of the same deployment.

## 4. Repository layout

```
├── MASTER_ARCHITECTURE.md        ← you are here
├── AGENTS.md                     ← AI working agreement
├── docs/                         ← engineering handbook + ADRs
├── memory/                       ← project memory (read before tasks)
├── changelog/                    ← CHANGELOG.md
├── frontend/                     ← Flutter client (one codebase, multiple platforms)
│   └── jolinx_app/
│       ├── lib/
│       │   ├── core/             shared: auth, API client, models, state, validation, offline
│       │   ├── features/         feature modules (sales, products, inventory, etc.)
│       │   └── presentation/     pages, widgets, theme, localization
│       ├── android/              Android-specific
│       ├── ios/                  iOS-specific
│       ├── linux/                Linux desktop
│       ├── macos/                macOS desktop
│       ├── windows/              Windows desktop
│       └── web/                  Web-specific
└── backend/
    ├── BusinessOS.slnx           ← includes tests project
    ├── src/
    │   ├── Shared/               kernel: Result, Error, Entity, IDomainEvent, options, audit context
    │   ├── Domain/               platform domain: Tenant, User, Role, Permission, AuditLog, FeatureFlag
    │   ├── Application/          CQRS use cases (MediatR), ports/interfaces, behaviors
    │   ├── Infrastructure/       EF Core (Postgres), Redis, JWT, BCrypt, event bus, outbox,
    │   │                         storage, jobs, permission cache, health checks
    │   ├── Api/                  composition root: middleware, endpoints, exceptions, health
    │   ├── Notifications/        notification engine: email/SMS/push/WhatsApp channels
    │   ├── Workers/              background hosts: outbox dispatcher, token cleanup, jobs
    │   └── Modules/              one project per business domain (vertical slice)
    │       └── Sales/            reference implementation of the module pattern
    └── tests/BusinessOS.Tests/   unit + integration (WebApplicationFactory)
```

## 5. Backend conventions

Dependency rule: each layer references only the one below it. `Infrastructure` is **not**
referenced by `Application` or `Domain` — implementations are injected at the composition
root (`API`/`Workers`).

```
API ──► Application (CQRS use cases) ──► Domain (entities, rules, events)
  │            │
  └──► Infrastructure (EF Core, Redis, JWT, outbox, event bus, storage, jobs)
```

- **CQRS + MediatR.** Writes = commands, reads = queries. Every command returns
  `Result<T>`; failures are `Error` (Validation/Conflict/NotFound/Unauthorized…).
- **MediatR pipeline** (outer → inner): `ValidationBehavior` (FluentValidation) →
  `TransactionBehavior` (saves changes + dispatches domain events via outbox) →
  `AuditBehavior` (writes a redacted audit log for successful non-`Get*` commands).
- **Audit behavior redaction**: sensitive fields (`password`, `secret`, `token`, `key`,
  `authorization`) are replaced with `***REDACTED***` before an audit row is written.
- Composition root registers engines via small `Add*` extension methods:
  `AddApplication`, `AddInfrastructure`, `AddNotificationEngine`, `AddFileStorage`,
  `AddJobQueue`, `AddPermissionEngine`, `AddPlatformHealthChecks`.

## 6. Platform services (implemented)

| Service | Where | Notes |
|---|---|---|
| Auth | `Api/Endpoints/AuthEndpoints.cs` | JWT access + rotating refresh, register/login/refresh/revoke, account lockout, `/api/v1/auth/*` |
| RBAC | `Infrastructure/Authorization` | `IPermissionService` + 5-min cache, `RequirePermission` / `RequirePermissionAttribute` |
| Audit | `Application/Behaviors/AuditBehavior` | Every successful mutation writes an audit log with actor, tenant, IP, device, correlation id |
| Notifications | `Notifications/` | `INotificationService`: Email (SMTP), SMS/Push/WhatsApp (logging channels), welcome-email + analytics/activity handlers |
| Jobs | `Infrastructure/Jobs` + `Workers/Jobs` | `IJobQueue` (outbox-backed), `SendEmail/Sms/Push/WhatsAppJob`, `JobExecutionService`, `ScheduledJobRunner` |
| Storage | `Infrastructure/Storage` | `IFileStorage`: `LocalFileStorage` (path-traversal safe) or `S3FileStorage` via `Storage:Provider` |
| Health | `Api/Health` | `/health`, `/health/live` (liveness), `/health/ready` (DB + Redis + storage + workers) |
| Config | `Shared/Configuration` | Options-pattern `*Options` classes bound from appsettings sections |
| Security | `Api/Middleware` | Correlation ID, user-context, security headers; rate limiting; structured Serilog logging; RFC7807 ProblemDetails |
| Versioning | `Api/Program.cs` | URL-segment API versioning; current version v1; Swagger UI |

## 7. Events and the outbox

- Aggregates raise `IDomainEvent`s (e.g. `UserRegisteredEvent`, `SaleCompleted`).
- `TransactionBehavior` persists events to the `OutboxMessages` table **in the same
  transaction** as the mutation, publishes in-process, then marks them processed.
- `Workers/Outbox/OutboxDispatcherService` polls the outbox and re-delivers anything that
  wasn't dispatched (crash-safe). **Consumers must be idempotent.**
- Jobs (`SendEmailJob` etc.) are also outbox messages — the reliable message queue.

## 8. Multi-tenancy

- Shared database; `tenant_id` on every tenant-owned row.
- Repository guardrail: queries must not run without a tenant filter.
- Schema-per-tenant is the documented escape hatch for enterprise, **not** the default.
- Feature flags gate module visibility per tenant.

## 9. Database conventions

- PostgreSQL; EF Core migrations in `Infrastructure` (date-prefixed, e.g. `AddUserLockout`).
- Every table: UUID primary key, `CreatedAt`/`CreatedBy`, `UpdatedAt`/`UpdatedBy`.
- Development database `businessos`, integration-test database `businessos_test`
  (both `localhost:5432`). Tests override the connection string via configuration.
- Redis optional; in-memory cache fallback when not configured.

## 10. API conventions

- **API-first**: a REST endpoint exists before a UI screen.
- Route prefix `/api/v{version}/…`; responses are `Result<T>` mapped to proper status codes
  (200/201/204/400/401/403/404/409) with RFC7807 ProblemDetails on failure.
- Every mutation writes an audit log; every mutation persists domain events.
- Swagger UI enabled in Development/Testing.

## 11. Security

- Passwords: BCrypt. Auth: JWT (access, short-lived) + rotating refresh tokens; revoke endpoint.
- Account lockout after repeated failed logins (configurable via `Security:MaxFailedLoginAttempts`).
- Rate limiting: `auth` policy (login/register) + `global` policy.
- Security headers on all responses; `X-Correlation-ID` end-to-end; request logging includes
  UserId/TenantId/CorrelationId.
- Audit logs redact secrets. Never log or store plaintext passwords or tokens.
- CORS locked to configured origins (permissive in Development only).

## 12. Offline-first sync

Device writes go to a Drift outbox (`SyncQueueItems`) and flush over idempotent REST
endpoints. Server applies server-wins on `updatedAt` conflict (v1); per-table strategy is
configurable later. (Flutter side currently in progress.)

## 13. Testing

- `backend/tests/BusinessOS.Tests`: unit tests (pure logic, no DB) + integration tests
  (`Integration/`, `WebApplicationFactory<Program>` against `businessos_test`).
- Integration tests require a real PostgreSQL on `localhost:5432`; CI runs **unit tests
  only** (`FullyQualifiedName!~Integration`).
- CI (`.github/workflows/ci.yml`): restore → build (`--warnaserror`) → `dotnet format
  --verify-no-changes` → unit tests → coverage artifact.
- Code style is enforced via `backend/Directory.Build.props` (warnings as errors) and
  `backend/.editorconfig`.

## 14. Coding standards

Full rules in `docs/CodingStandards.md` and `docs/ArchitectureRules.md`. Non-negotiables:

1. No duplicated business logic — extract to a shared service/engine.
2. No direct DB access from UI or controllers — go through `Application`.
3. No hardcoded business rules, URLs, colors, or magic numbers — everything configurable.
4. No TODOs in production code.
5. Mixing UI and business logic is forbidden.
6. Never commit unverified code; never skip tests or documentation.

## 15. Definition of Done

Everything in `docs/ArchitectureRules.md#Definition-of-Done` must be true:

requirements implemented · no analyzer warnings · tests pass · manual checklist passes ·
documentation updated (spec/API/changelog) · DB migration created · localization added ·
audit logging added · permissions added · responsive UI verified · offline + sync verified ·
error handling verified.

## 16. Roadmap

- **Phase 0 — Foundation (now):** platform services (auth, RBAC, audit, events, outbox,
  notifications, storage, jobs, health, hardening). Detailed in `docs/roadmap.md`.
- **Phase 0.5 — Platform Hardening (current):** exception handling, validation, logging,
  API versioning, configuration, security headers/rate limiting/lockout, file storage,
  messaging/jobs/events, notification engine + email queue, permission engine, audit engine,
  health + CI. → **Platform Readiness Report** gates the next phase.
- **Phase 1 — Core Business MVP:** Auth (real), Organizations & Branches ✅ (2026-08-06),
  Users/Roles/Permissions ✅ (2026-08-13), Product & Inventory Foundation (Slice 3, next),
  Sales + Offline POS, Dashboard, Inventory, Purchasing, Accounting basics, Reporting + Tax,
  Workflow v1, Dynamic Forms v1.
- **Phase 2 — Enterprise:** HR, Payroll, Projects, Assets, Fleet, Help Desk, Documents,
  Analytics, Report Builder, OpenTelemetry, search indexing.
- **Phase 3 — Ecosystem:** Plugin System + Marketplace, Public API + SDKs, Manufacturing,
  Automation/Rule Engine, AI Engine, industry modules by partners.

## 17. Workflow (AI assistants and humans)

1. Read project memory → architecture rules → the feature spec.
2. Create an implementation plan → get approval before implementing.
3. Implement one small task at a time.
4. Run analyzers and tests; fix failures.
5. Produce a completion report; update documentation; suggest the next task.

## 18. Deployment

- Cloud SaaS (default): Api + Workers behind TLS; tenant-isolated data.
- Self-hosted/on-premises: Docker Compose/Helm; customers keep their data.
- Offline desktop: Flutter desktop + local SQLite, optional sync to a company server.

## 19. Client architecture (Flutter — locked 2026-08-31)

**One Flutter codebase targets all platforms.** This is a deliberate solo-developer
optimization: one language (Dart), one UI framework, one state management, one navigation
system, one testing approach, one deployment pipeline.

```
                    JOLINX BUSINESS OS
                           │
                    .NET 10 Backend
                           │
                    PostgreSQL
                           │
                    REST API / Events
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
     Flutter            Flutter            Flutter
       Web              Desktop             Mobile
        │                  │                  │
     Browser        Windows/Linux/       Android/iOS
                     macOS
```

**Shared across platforms:** authentication, API client, models, state management,
validation, localization, theme, components, navigation concepts, error handling,
permissions, business workflows, offline storage, synchronization, testing utilities.

**Platform-specific behind common interfaces:** receipt printer, USB, Bluetooth, barcode
scanner, camera, file system, OS APIs. Each has a platform implementation behind a Dart
interface (e.g. `ReceiptPrinter.print(receipt)`).

**One codebase ≠ one UI.** Each platform adapts to its device:
- Desktop POS: keyboard, barcode scanner, mouse, receipt printer
- Mobile: touch, camera, mobile money, small screen
- Web: information density, management workflows

**All platforms are first-class.** The backend doesn't care what device the tenant uses.
Tenant configurations determine which platforms are available, not the technology.

**Offline-first:** Local-first where workflow requires it + cloud synchronization. Device
writes go to Drift outbox, flush over idempotent REST endpoints. Backend applies server-wins
on conflict (v1).
