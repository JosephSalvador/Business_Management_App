# Project Memory — read before every task

## business.md — who we build for

- **Target users:** small shops, retail, wholesale, manufacturing, schools, hospitals,
  hotels, agriculture (East Africa first: Tanzania, Kenya, Uganda).
- **Buyer pain:** offline POS, mobile money, local tax (TRA/KRA/URSB), Swahili UI, low
  bandwidth, simple onboarding (< 10 min), per-branch pricing.
- **Positioning:** the African alternative to Odoo / Zoho / SAP B1 / Dynamics 365. Platform,
  not a single ERP.

## architecture.md — current state (2026-08-06)

- Modular monolith: Shared / Domain / Application / Infrastructure / API / Workers /
  Notifications / Modules.*. Solution `backend/BusinessOS.slnx` (includes the tests project).
- Event-driven + outbox; CQRS (MediatR); UUID PKs; shared-DB tenancy with `tenant_id`.
- **Implemented:** JWT auth (register/login/refresh/revoke) + BCrypt + account lockout;
  RBAC with permission cache; audit pipeline (redacted); notification engine (email/SMS/
  push/WhatsApp channels + welcome email + analytics/activity handlers); outbox-backed job
  queue (`SendEmailJob` etc.) + scheduled jobs; local/S3 file storage; health endpoints
  (`/health`, `/health/live`, `/health/ready`); API versioning (v1) + Swagger; exception
  handler (ProblemDetails), correlation/security-headers middleware, rate limiting, CORS,
  structured Serilog logging; options-pattern configuration. Build is clean
  (`--warnaserror`, 0 warnings); `dotnet format` passes.
- **Phase 1 slice 1 (Organizations & Branches, done 2026-08-06):** `Tenant` organization
  profile (contact/address/currency/taxId); `Branch` aggregate with code normalization;
  tenant-scoped `IBranchRepository`; `Features/Organizations` + `Features/Branches`
  commands/queries with validators + `PagedResult<T>`; endpoints
  `GET/PUT /api/v1/organization`, `GET/POST /api/v1/branches`,
  `GET/PUT /api/v1/branches/{id}`, `PATCH /api/v1/branches/{id}/status` — all gated with
  `RequirePermission` (readiness gap #3 closed); registration auto-creates the default
  `HQ` branch; seeder re-grants new permissions to existing admin roles; outbox-backed
  `BranchActivityFeedHandler`; 62 tests pass (unit + integration against real Postgres).
- **Phase 1 slice 2a (Users, Roles & Permissions), tasks 001–003 done 2026-08-07:**
  domain hardening (`UserBranch` invariants: single default, duplicate-rejection, stale
  replacement; `User.SetRoles` no-op on identical; `SystemRoles.Administrator` constant);
  migration `20260806_AddUserRoleAndBranchManagement` (UserBranches table + Roles
  Description + unique `(TenantId, Name)`); repository ports/implementations
  (`IUserRepository` tenant-scoped `GetByIdAsync/GetByIdWithRolesAsync/ListAsync/CountAsync/
  CountActiveAdministratorsAsync`, `IRoleRepository` `GetByIdAsync/GetByNameAsync/ListAsync/
  GetPermissionsAsync/RemoveAsync`, new `IPermissionRepository` `ListAsync/GetByNameAsync/
  ResolveByNamesAsync`); auth callers updated (register/login/refresh/current-user/cache).
  Key decisions: `UserBranch` is managed only through the `User` aggregate (no child repo);
  `IPermissionRepository` returns **tracked** catalog entities so grants attach without
  re-inserting the catalog; EF child-state pitfall (client Guid keys in added children must
  use default keys so EF treats them as Added, not Modified). 91 tests pass.
- Key docs: `MASTER_ARCHITECTURE.md` (single source of truth), `docs/ArchitectureRules.md`,
  `docs/Architecture.md`, `docs/roadmap.md`, `specs/organizations-branches.md`,
  `specs/users-roles-permissions.md`.

## coding.md — see `docs/CodingStandards.md`

## api.md — see `docs/APIStandards.md`

## database.md — see `docs/TechStack.md` + ADR-0002/0008

- Local: podman postgres:17, db `businessos`, user `businessos`, password `Joseph662.`
  (trailing period is part of the password), port 5432. Redis `localhost:6379`, MinIO
  `localhost:9000/9001`. Test DB: `businessos_test`.

## ux.md — product principles

- Mobile-first, one-hand usable, works on cheap Android, offline-first.
- Swahili + English localization first-class. Large tap targets for POS.
- Guided onboarding < 10 min. Every screen earns its place.

## branding.md

- Product name: **Business OS**. Flutter package: `business_management_system`.
- Goal tone: trustworthy, simple, local. (Full brand guide deferred.)

## known_issues.md

- System Postgres 17 `postgres` password unknown → we use our own container DB (ADR-0009).
- Redis/minio binaries not installed → containers.
- Integration tests need real Postgres on `localhost:5432` → CI runs unit tests only.
- Success `Result<T>` endpoints return **200**, not 201 (platform `ToApiResult` convention) —
  documented in the Organizations & Branches spec.

## technical_debt.md

- Flutter app: SharedPreferences + in-memory mocks still drive auth/products/sales; Drift DB
  (11 tables) is built but disconnected from the running app.
- Dev DB `businessos` may contain smoke-test users; `businessos_test` is recreated per run.
- Roadmap checkboxes marked `[x]` for Phase 0 are aspirational — many are now real (see
  "architecture.md" above).
