# Changelog

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
