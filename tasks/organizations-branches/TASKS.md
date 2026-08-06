# TASKS — Organizations & Branches

> Spec: `specs/organizations-branches.md`. Implement one task at a time; run analyzers and
> tests after each; update this file as you go. No code until the spec is approved.

## Status legend

`[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked (note why)

## Tasks

- [x] 001 **Domain**: extend `Tenant` with organization profile (`ContactEmail`,
      `ContactPhone`, `Address`, `Currency`, `TaxId` + `UpdateProfile`); add `Branch`
      aggregate (`Create`, `UpdateProfile`, `Activate`, `Deactivate`, code normalization);
      add `BranchCreatedEvent`, `BranchUpdatedEvent`, `BranchStatusChangedEvent`;
      extend `PermissionNames` with Organizations + Branches entries.
- [x] 002 **Persistence**: `Branch` `DbSet` + mapping in `BusinessDbContext` (unique index
      `(TenantId, Code)`, max lengths); EF migration
      `20260805_AddOrganizationProfileAndBranches` (also restored the previously-uncommitted
      `20260805051819_AddUserLockout` migration and consolidated migrations under
      `Infrastructure/Migrations/`).
- [x] 003 **Ports + repositories**: `IBranchRepository` (`GetByIdAsync(tenantId, id)`,
      `GetByCodeAsync(tenantId, code)`, `ListAsync(tenantId, page, pageSize)`,
      `CountAsync(tenantId)`, `AddAsync`, `ListAllAsync(tenantId)`); `BranchRepository`
      implementation; register in `Infrastructure/DependencyInjection`.
- [x] 004 **Application**: `Features/Organizations` (`GetOrganizationQuery`,
      `UpdateOrganizationCommand` + validator); `Features/Branches` (`ListBranchesQuery`
      paginated, `GetBranchQuery`, `CreateBranchCommand`, `UpdateBranchCommand`,
      `SetBranchStatusCommand` + validators); `PagedResult<T>` DTO in Shared/Application.
- [x] 005 **Registration + seeder**: `RegisterUserCommand` creates default `HQ` branch
      (currency from `Payments:Currency` via `IOptions`); `DatabaseSeeder` re-grants new
      permissions to existing system `Administrator` roles and seeds a default branch for
      the demo tenant.
- [x] 006 **API endpoints**: `OrganizationEndpoints` + `BranchesEndpoints` with
      `RequirePermission(PermissionNames.*)`; registered in `Program.cs`.
      (`Idempotency-Key` deliberately deferred — no existing endpoint implements it;
      platform-wide change needed.)
- [x] 007 **Event consumers**: `BranchActivityFeedHandler` (logs Branch* events) in
      Notifications; register in `NotificationEngineExtensions`.
- [x] 008 **Tests**: unit (Branch, Tenant profile) + integration (register default branch,
      CRUD + status, 403 without permission, tenant isolation, pagination, audit rows,
      outbox dispatch of `BranchCreatedEvent`).
- [x] 009 **Docs + verification**: build (`--warnaserror`), `dotnet format`, full test run;
      update `MASTER_ARCHITECTURE.md`, `docs/PlatformReadinessReport.md` gap #3, changelog
      v0.3.0, `memory/project.md`; tick spec checkboxes.
