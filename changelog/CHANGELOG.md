# Changelog

## v0.4.0 — 2026-08-07 — Phase 1: Users, Roles & Permissions (backend slice)

### Users, Roles & Permissions
- **Domain:** `UserBranch` entity (`AssignBranches` invariants: single default, default ∈
  assigned, duplicate rejection, stale-child replacement); `User.SetRoles` no-op on
  identical sets; `Role.Description` + `Clone` + `Rename`/`Delete` guard helpers; new
  identity domain events (`UserCreatedEvent`, `UserProfileUpdatedEvent`,
  `UserRolesChangedEvent`, `UserStatusChangedEvent`, `UserBranchesChangedEvent`,
  `RoleCreatedEvent`, `RoleUpdatedEvent`, `RolePermissionsChangedEvent`,
  `RoleDeletedEvent`); `SystemRoles.Administrator` constant.
- **Persistence:** `UserBranches` table (unique `(UserId, BranchId)` + partial unique index
  on default per user), `Roles.Description` column + unique `(TenantId, Name)` index via
  migration `20260806_AddUserRoleAndBranchManagement`; `UserBranch` managed through the
  `User` aggregate (no child repository); `IPermissionRepository` returns the **tracked**
  catalog so `Role.Grant` attaches without re-inserting it.
- **Repositories:** `IUserRepository` tenant-scoped `GetByIdAsync(tenantId, id)`,
  `GetByIdWithRolesAsync`, `ListAsync(tenantId, page, pageSize)`, `CountAsync`,
  `CountActiveAdministratorsAsync(tenantId, excludeUserId)`; `IRoleRepository`
  `GetByIdAsync(tenantId, id)`, `GetByNameAsync`, `ListAsync(tenantId)`,
  `GetPermissionsAsync(tenantId, roleId)`, `RemoveAsync`; new `IPermissionRepository`
  (`ListAsync`, `GetByNameAsync`, `ResolveByNamesAsync`).
- **Application:** `Features/Users` (list/get/create/update/status/delete, roles, branches)
  and `Features/Roles` (list/get/create/update/delete, permissions) with validators,
  DTOs, mappers, and `UserAdminGuard` (self + last-active-Administrator protection).
- **API:** `IdentityEndpoints` — users, roles and permission-catalog routes under
  `/api/v1`, gated with `RequirePermission(Users.* / Roles.*)`.
- **Events:** `IdentityActivityFeedHandler` (outbox-backed activity feed) registered in the
  notification engine.
- **Tests:** 154 passing (unit + integration) — branch-assignment invariants, last-admin
  guard, role grant idempotency, user/role CRUD + status, duplicate email/role → Conflict,
  self + last-admin protection, permission round-trip, tenant isolation, 403 for
  `Users.View`-only role, audit rows, outbox dispatch.

### Docs
- Spec `specs/users-roles-permissions.md` persistence notes; tasks
  `tasks/users-roles-permissions/TASKS.md` all ticked; roadmap item 3 marked
  `[x] backend slice`; `memory/project.md` and readiness report updated.

## v0.3.0 — 2026-08-06 — Phase 1: Organizations & Branches (backend slice)

### Organizations & Branches
- **Domain:** `Tenant` extended with organization profile (`ContactEmail`, `ContactPhone`,
  `Address`, `Currency` default `TZS`, `TaxId`, `UpdateProfile`); new `Branch` aggregate
  (`Create`, `UpdateProfile`, `Activate`/`Deactivate`, code normalization to uppercase);
  events `BranchCreatedEvent`/`BranchUpdatedEvent`/`BranchStatusChangedEvent`; new
  `PermissionNames`: `Organizations.View/Manage`, `Branches.View/Create/Update/Delete`.
- **Persistence:** `Branch` table (unique index `(TenantId, Code)`) + tenant profile columns
  via migration `20260805202634_AddOrganizationProfileAndBranches`; `IBranchRepository` +
  `BranchRepository`; restored the previously-uncommitted `20260805051819_AddUserLockout`
  migration (test DB already had it; dev DB was missing lockout columns) and consolidated
  migrations under `Infrastructure/Migrations/`.
- **Application:** `Features/Organizations` (GET/PUT) and `Features/Branches` (list/get/
  create/update/status) with validators, `PagedResult<T>`, tenant-scoped repositories.
- **Registration + seeder:** `RegisterUserCommand` auto-creates the default `Head Office`
  (`HQ`) branch from `Payments:Currency`; `DatabaseSeeder` re-grants new permissions to
  existing system `Administrator` roles and seeds the demo tenant's default branch.
- **API:** `OrganizationEndpoints` — `GET/PUT /api/v1/organization`,
  `GET/POST /api/v1/branches`, `GET/PUT /api/v1/branches/{id}`,
  `PATCH /api/v1/branches/{id}/status`, all gated with `RequirePermission`
  (readiness gap #3 closed).
- **Events:** `BranchActivityFeedHandler` (outbox-backed activity feed) registered in the
  notification engine.
- **Tests:** 62 passing (unit + integration) — register default branch, CRUD + status,
  duplicate code → Conflict, 403 for `Branches.View`-only role, tenant isolation (404),
  audit rows, outbox dispatch of `BranchCreatedEvent`.

### Docs
- Spec `specs/organizations-branches.md` marked implemented; tasks
  `tasks/organizations-branches/TASKS.md` all ticked; readiness report gap #3 closed.

## v0.2.0 — 2026-08-05 — Phase 0.5 Platform Hardening

### Platform
- **Exception handling:** `GlobalExceptionHandler` → RFC7807 ProblemDetails with
  trace/correlation ids.
- **Observability:** `CorrelationIdMiddleware` (`X-Correlation-ID`), `UserContextMiddleware`
  (`RequestContext`), Serilog request logging (UserId/TenantId/CorrelationId/Ip).
- **Security:** security headers (nosniff/DENY/no-referrer/permissions-policy), rate limiting
  (auth + global policies), account lockout (`AddUserLockout` migration), `revoke` endpoint,
  `TokenCleanupService`, CORS.
- **Validation:** FluentValidation structured per-field errors (`ValidationProblemDetails`).
- **API versioning:** URL-segment `v1`, Swagger v1 + Bearer; all routes now `/api/v1/*`.
- **Configuration:** options-pattern classes in `Shared/Configuration/PlatformOptions.cs`
  (Database/Redis/Smtp/Sms/Storage/Payments/Cors/RateLimiting/Security).
- **Storage engine:** `IFileStorage` with `LocalFileStorage` (path-traversal safe) and
  `S3FileStorage`; `AddFileStorage`.
- **Messaging/jobs/events:** outbox-backed `IJobQueue`, `SendEmail/Sms/Push/WhatsAppJob`,
  `JobExecutionService`, `ScheduledJobRunner`, `AddJobQueue`/`AddBackgroundJobs`.
- **Notification engine:** channel-based `INotificationService` (Email/SMS/Push/WhatsApp),
  welcome-email + analytics + activity-feed handlers for `UserRegisteredEvent`.
- **Permission engine:** `IPermissionService` + `PermissionCacheService` (5-min TTL),
  `RequirePermission`/`RequirePermissionAttribute`.
- **Audit engine:** `AuditBehavior` in the MediatR pipeline — every successful non-`Get*`
  command writes a redacted audit log (passwords/tokens never persisted).
- **Health/CI:** `/health/live` + `/health/ready` (DB/Redis/storage/worker heartbeats),
  GitHub Actions CI (build `--warnaserror`, `dotnet format`, unit tests, coverage),
  `Directory.Build.props` + `.editorconfig`.
- **Tests:** 45 passing (34 unit + 11 integration) incl. storage, jobs, notifications,
  permission cache, audit behavior.

### Docs
- `MASTER_ARCHITECTURE.md` (single source of truth) added at repo root.
- `memory/project.md` brought up to date. CI comment corrected.

## v0.1.0 — 2026-08-05 — Phase 0 foundation (in progress)

### Backend
- Created modular-monolith solution `backend/BusinessOS.slnx` (Shared, Domain, Application,
  Infrastructure, API, Workers, Notifications, Modules.Sales).
- Domain kernel: `Result<T>`/`Error`, `Entity`/`AggregateRoot`, `IDomainEvent`.
- Platform domain stubs: `Tenant`, `Role`, `Permission`, `PermissionNames`, `UserRegisteredEvent`.
- **Superseded by v0.2.0:** JWT auth, EF Core + Postgres, seed, outbox, audit — all now real.
