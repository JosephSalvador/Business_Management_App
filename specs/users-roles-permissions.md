# Feature Spec — Identity Management: Users, Roles & Permissions (Slice 2a)

> Phase 1, second slice (first part of Identity & Workforce Management). Approval required
> before coding. Tasks in `tasks/users-roles-permissions/TASKS.md`.
>
> **Status: implemented & verified 2026-08-13.** Backend slice complete (tasks 001–009);
> tests green (154/154). Flutter admin screens remain as listed under Future improvements /
> Offline & sync.
>
> Deferred to **Slice 2b** (separate spec): invitations, password policies/history, sessions
> & device tracking, login history, force-logout/token versioning.

## Feature

Tenant-scoped management of users, roles, the permission matrix, and branch access — the
administrative layer every transactional module (Sales, POS, Inventory) depends on. Answers:
who can log in, what they can do, which branches they may operate in, and who changed what.

## Purpose

Roadmap item #3 (Users, Roles & Permissions). The RBAC engine, audit engine, organizations,
branches and notification engine already exist. This slice adds the **business layer** to
manage them: create/edit/deactivate users, assign roles and branches, build custom roles from
the permission catalog, and audit every action. Sales/POS can then enforce cashier
permissions and branch-scoped access without revisiting the authorization model.

## Business rules

- A **user** belongs to exactly one tenant. Users are identified by a globally-unique email
  (the login identifier; per-tenant email reuse is deferred — see "Decisions" below).
- Users are **deactivated, never hard-deleted** (sales/audit/tokens reference users).
  `DELETE /users/{id}` is a soft delete: deactivate + revoke all refresh-token families.
- You **cannot deactivate or delete yourself**; the **last active user holding a system
  `Administrator` role** in a tenant cannot be deactivated/deleted (prevents lockout).
- Inactive or locked users cannot log in (already enforced by Auth).
- A **role** belongs to exactly one tenant; role names are unique per tenant.
- **System roles** (`IsSystem = true`, e.g. Administrator) cannot be renamed or deleted, but
  their permission set may be adjusted. **Custom roles** are fully editable/deletable.
  (Explicit decision recorded in `docs/adr/0001-system-role-permissions.md`.)
- Deleting a role leaves its users intact but removes those grants (they lose that role).
- The **permission catalog** is seeded (`PermissionNames.All`); the slice manages
  *assignment* of existing permissions to roles, not the catalog itself.
- New businesses receive ready-to-use roles at registration: protected `Administrator` and
  `Staff` system roles, plus editable `Manager`, `Cashier`, `Inventory Officer`, and
  `Accountant` starter roles. The starter roles are tenant-owned defaults: a client may rename,
  change, or delete them, and deleted roles are never re-created for an existing tenant.
- A user may be assigned to **zero or more branches**; **at most one default branch**.
  The default branch id must be among the assigned branches (or null).
- Branch assignments require the branch to exist in the tenant (checked per assignment).
- User/role/assignment changes are audited by the platform audit engine automatically.
- Passwords for admin-created users are set at creation by the admin (temporary password
  flow and invitations are Slice 2b).

## Screens (Flutter)

None in this slice (API-first). Flutter admin screens consume these endpoints later.

## API (backend)

All authenticated (`Bearer`), versioned `/api/v1`, rate-limited by the `global` policy.
Every endpoint is tenant-scoped (the caller's `TenantId`), never a cross-tenant read/write.

### Users

| Method | Route | Permission | Body / Query | Success |
|---|---|---|---|---|
| GET | `/api/v1/users` | `Users.View` | `?page=1&pageSize=50` | 200 `PagedResult<UserDto>` |
| GET | `/api/v1/users/{id}` | `Users.View` | — | 200 `UserDto` |
| POST | `/api/v1/users` | `Users.Create` | `CreateUserRequest` | 200 `UserDto` |
| PUT | `/api/v1/users/{id}` | `Users.Update` | `UpdateUserRequest` | 200 `UserDto` |
| PUT | `/api/v1/users/{id}/roles` | `Users.Update` | `{ roleIds[] }` | 200 `UserDto` |
| GET | `/api/v1/users/{id}/branches` | `Users.View` | — | 200 `List<UserBranchDto>` |
| PUT | `/api/v1/users/{id}/branches` | `Users.Update` | `{ branchIds[], defaultBranchId? }` | 200 `List<UserBranchDto>` |
| PATCH | `/api/v1/users/{id}/status` | `Users.Update` | `{ isActive }` | 200 `UserDto` |
| DELETE | `/api/v1/users/{id}` | `Users.Delete` | — | 204 |

### Roles

| Method | Route | Permission | Body / Query | Success |
|---|---|---|---|---|
| GET | `/api/v1/roles` | `Roles.View` | — | 200 `List<RoleDto>` |
| POST | `/api/v1/roles` | `Roles.Manage` | `CreateRoleRequest` | 200 `RoleDto` |
| PUT | `/api/v1/roles/{id}` | `Roles.Manage` | `UpdateRoleRequest` | 200 `RoleDto` |
| DELETE | `/api/v1/roles/{id}` | `Roles.Manage` | — | 204 |
| GET | `/api/v1/roles/{id}/permissions` | `Roles.View` | — | 200 `List<string>` |
| PUT | `/api/v1/roles/{id}/permissions` | `Roles.Manage` | `{ permissionNames[] }` | 200 `RoleDto` |

### Permission catalog

| Method | Route | Permission | Body / Query | Success |
|---|---|---|---|---|
| GET | `/api/v1/permissions` | `Users.View` | — | 200 `List<PermissionDto>` |

Failure: RFC 7807 `ProblemDetails` with stable `code` (`Validation`, `NotFound`, `Conflict`,
`Unauthorized`, `Forbidden`). Success mutations return `200` per the platform `ToApiResult`
convention (`DELETE` → `204`).

DTO shapes:
- `UserDto` = id, tenantId, email, fullName, phone, isActive, emailVerified, isLockedOut,
  roleIds, branchIds, defaultBranchId, createdAt, updatedAt.
- `RoleDto` = id, tenantId, name, description, isSystem, permissionNames, createdAt.
- `UserBranchDto` = branchId, branchName, branchCode, isDefault.
- `PermissionDto` = name, description.

## Database

- **`UserBranches`** — new table: `Id` uuid PK, `TenantId` uuid FK indexed, `UserId` uuid FK,
  `BranchId` uuid FK, `IsDefault` bool, `AssignedBy` uuid, `AssignedAt` timestamptz. Unique
  `(UserId, BranchId)`. Partial unique index on `UserId` where `IsDefault = true` (one default
  per user).
- **`Roles`** — add nullable `Description` (varchar 200). Make the `(TenantId, Name)` index
  **unique** (currently non-unique in the model; rule says unique per tenant).
- No `Users` schema change (keeps `FullName`, `Phone`; `FirstName/LastName/DisplayName`
  split is not needed — see "Decisions").
- Migration name: `20260806_AddUserRoleAndBranchManagement`.

Persistence notes (from Task 003):
- `UserBranch` is an aggregate child of `User` — there is **no** `IUserBranchRepository`;
  assignments are replaced through `User.AssignBranches` and persisted by the `User`
  aggregate's repository.
- `IPermissionRepository` returns the **tracked** catalog entities so they can be attached to
  roles (`Role.Grant`) without EF re-inserting the catalog rows; catalog reads are reference
  data for aggregate composition.
- `IUserRepository.GetByIdAsync` reads roles and branches with `AsSplitQuery`; reads use
  `AsNoTracking` except where entities must attach to aggregates.

## Validation

- Create user: email required + valid + globally unique → `Conflict` on duplicate; fullName
  required max 200; phone max 30; password must satisfy the existing Auth policy (≥8 chars,
  upper/lower/digit/special); `roleIds` must exist in tenant; `branchIds`/`defaultBranchId`
  must exist in tenant and default ∈ branchIds.
- Update user profile: fullName required max 200; phone max 30.
- Status: cannot deactivate self or the last active system Administrator → `Conflict`.
- Role: name required max 100, unique per tenant → `Conflict`; system role rename/delete →
  `Conflict`; deleting a role in use is allowed (grants removed).
- Permissions: `permissionNames` must all exist in the catalog → `Validation` otherwise.
- Branch assignment: `branchIds` must be non-duplicated and exist; `defaultBranchId` ∈
  `branchIds` (or null/absent → no default).

## Permissions

Existing `PermissionNames` entries are reused — no new catalog entries in this slice:
`Users.View/Create/Update/Delete`, `Roles.View/Manage`. Registration already grants all
permissions to the system `Administrator` role; the seeder's re-grant logic (added in Slice 1)
keeps existing tenants current. The `GET /permissions` catalog is gated by `Users.View`.

## Events

Outbox-backed, consumed by an identity activity-feed handler (logs; proves delivery):
- `UserCreatedEvent` (admin-created user; registration keeps `UserRegisteredEvent`)
- `UserProfileUpdatedEvent`, `UserRolesChangedEvent`
- `UserStatusChangedEvent` (activate/deactivate/soft-delete)
- `UserBranchesChangedEvent`
- `RoleCreatedEvent`, `RoleUpdatedEvent`, `RolePermissionsChangedEvent`, `RoleDeletedEvent`

## Reports

None in this slice.

## Tests

- **Unit:** last-administrator guard; branch-assignment invariants (single default, default ∈
  assigned); role grant idempotency; system-role immutability.
- **Integration** (`WebApplicationFactory` against `businessos_test`):
  - User CRUD + status + soft delete return right codes/shapes; duplicate email → `Conflict`.
  - Cannot deactivate/delete self → `Conflict`; last active Administrator protected → `Conflict`.
  - Role CRUD; duplicate role name → `Conflict`; system role rename/delete → `Conflict`;
    permission assignment round-trip.
  - Branch assignment round-trip (assign, default, replace-all clears prior).
  - Cross-tenant isolation: tenant B cannot read/update tenant A's user or role (`NotFound`).
  - 403 for a `Users.View`-only role on create/delete endpoints.
  - Audit rows for create/update/status/role/assignment mutations.
  - `UserCreatedEvent` / `RolePermissionsChangedEvent` land in the outbox and are dispatched.

## Offline & sync

- `GET /api/v1/users` is the sync source for the future device staff cache (POS shift login).
- User rows carry `UpdatedAt` for the `updatedAt` server-wins conflict strategy (same as
  branches). No Flutter/Drift changes in this slice.

## Decisions (deliberate deviations from the outline)

- Keep `FullName` (no FirstName/LastName split) — the existing auth flows, DTOs and tests use
  it; splitting adds churn with no functional gain for Slice 2a.
- Email stays **globally unique** — it is the login identifier and the DB enforces a unique
  index; per-tenant email reuse would require tenant-qualified login (deferred decision).
- User delete = **soft delete** (deactivate + revoke sessions), consistent with branch
  deactivation; hard delete deferred with guardrails.
- Permission catalog stays seeded; this slice manages role↔permission assignment only.
- Default role setup is intentionally hybrid: the owner is assigned only `Administrator`, while
  the remaining role presets remove permission-matrix work for new clients without preventing
  custom roles.
- `Idempotency-Key` remains deferred platform-wide (no endpoint implements it yet).

## Future improvements (Slice 2b and later)

- Invitations (email/SMS temp token, set-your-own-password); password policies + history;
  session management (revoke all, device tracking, token versioning); login history;
  per-tenant emails; user avatar/photo; `PATCH /users/{id}/default-branch` shortcut; custom
  permission definitions.
