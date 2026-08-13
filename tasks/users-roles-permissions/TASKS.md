# TASKS — Users, Roles & Permissions (Slice 2a)

> Spec: `specs/users-roles-permissions.md`. Implement one task at a time; run analyzers and
> tests after each; update this file as you go. No code until the spec is approved.

## Status legend

`[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked (note why)

## Tasks

- [x] 001 **Domain**: add `UserBranch` entity (assign invariants: single default, default ∈
      assigned, assigned branches must exist); add `Role.Description` + `Clone` +
      `Rename`/`Delete` guard helpers; domain events (`UserCreatedEvent`,
      `UserProfileUpdatedEvent`, `UserRolesChangedEvent`, `UserStatusChangedEvent`,
      `UserBranchesChangedEvent`, `RoleCreatedEvent`, `RoleUpdatedEvent`,
      `RolePermissionsChangedEvent`, `RoleDeletedEvent`).
- [x] 002 **Persistence**: `UserBranches` `DbSet` + mapping (unique `(UserId, BranchId)`,
      partial unique index on default per user); `Roles.Description` column + unique
      `(TenantId, Name)` index; EF migration `20260806_AddUserRoleAndBranchManagement`.
- [x] 003 **Ports + repositories**: extend `IUserRepository` (tenant-scoped
      `GetByIdAsync(tenantId, id)`, `GetByIdWithRolesAsync(tenantId, id)`,
      `ListAsync(tenantId, page, pageSize)`, `CountAsync`,
      `CountActiveAdministratorsAsync(tenantId, excludeUserId)`); extend `IRoleRepository`
      (`GetByIdAsync(tenantId, id)`, `GetByNameAsync(tenantId, name)`,
      `ListAsync(tenantId)`, `GetPermissionsAsync(tenantId, roleId)`, `RemoveAsync`); add
      `IPermissionRepository` (`ListAsync`, `GetByNameAsync`, `ResolveByNamesAsync`);
      update auth callers of the old `GetByIdAsync(id)`/`GetPermissionsAsync(roleId)`
      signatures; register in `Infrastructure/DependencyInjection`. `UserBranch` is managed
      through the `User` aggregate only (no `IUserBranchRepository`).
- [x] 004 **Application — users**: `Features/Users` commands/queries + DTOs + validators:
      `ListUsersQuery`, `GetUserQuery`, `CreateUserCommand` (initial password, roles,
      branches), `UpdateUserCommand`, `SetUserStatusCommand` (self + last-admin guards),
      `DeleteUserCommand` (soft delete + revoke refresh tokens), `SetUserRolesCommand`,
      `GetUserBranchesQuery`, `SetUserBranchesCommand` (default-branch invariant). Last-admin
      guard centralized in `UserAdminGuard` using `SystemRoles.Administrator`; admin-removing
      ops (deactivate/delete/demote) run inside a per-tenant PostgreSQL transaction advisory
      lock acquired on the same DB transaction as the mutation (`ITenantAdvisoryLock` +
      `TransactionBehavior`). Lifecycle (active/deactivated) is separate from auth state
      (refresh-token revocation only on soft delete).
- [x] 005 **Application — roles**: `Features/Roles` commands/queries + DTOs + validators:
      `ListRolesQuery`, `GetRoleQuery`, `CreateRoleCommand`, `UpdateRoleCommand`,
      `DeleteRoleCommand` (system-role guard), `GetRolePermissionsQuery`,
      `SetRolePermissionsCommand` (catalog validation); `GetPermissionsQuery` catalog;
      `RoleDto`/`UserDto` mappers shared with 004.
- [x] 006 **API endpoints**: `IdentityEndpoints` (users, roles, permissions groups) with
      `RequirePermission(PermissionNames.Users.* / Roles.*)`; register in `Program.cs`.
      `DeleteRoleCommand` aligned to non-generic `Result` (→ `204`), matching
      `DeleteUserCommand`. System-role permission-set rule recorded in
      `docs/adr/0001-system-role-permissions.md`.
- [x] 007 **Event consumers**: `IdentityActivityFeedHandler` (logs identity events) in
      Notifications; register in `NotificationEngineExtensions`.
- [x] 008 **Tests**: unit (last-admin guard, branch-assignment invariants, grant idempotency,
      system-role immutability) + integration (user/role/branch CRUD, duplicate email/role →
      Conflict, self + last-admin protection, permission round-trip, tenant isolation, 403 for
      `Users.View`-only role, audit rows, outbox dispatch).
- [ ] 009 **Docs + verification**: build (`--warnaserror`), `dotnet format`, full test run;
      update `docs/roadmap.md`, changelog v0.4.0, `memory/project.md`, readiness report;
      tick spec checkboxes.
