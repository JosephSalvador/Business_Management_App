# ADR-0001 — System roles protect identity but allow permission-set changes

- Status: Accepted
- Date: 2026-08-13
- Deciders: Product owner + engineering
- Area: Users, Roles & Permissions (Slice 2a)

## Context

The RBAC model distinguishes **system roles** (`IsSystem = true`, seeded, e.g.
`Administrator`) from **custom roles**. The platform must guarantee that a tenant can never
lose its last active `Administrator` (lockout prevention, enforced separately by
`UserAdminGuard`). The question is how immutable a system role is.

Two distinct shapes are possible:

1. System role is fully immutable (identity **and** permission set locked).
2. System role protects its **identity** (name, deletion) but its **permission set may be
   adjusted** by `Roles.Manage`.

Shape 2 was chosen for Slice 2a.

## Decision

For system roles:

- cannot be renamed — `UpdateRoleCommand` returns `Conflict` for `IsSystem` roles;
- cannot be deleted — `DeleteRoleCommand` returns `Conflict` for `IsSystem` roles;
- **permission sets CAN currently be changed** — `SetRolePermissionsCommand` accepts system
  roles and validates names against the read-only permission catalog.

The rule was implemented in `Features/Roles` (Task 005) and reflects the existing spec
("system roles cannot be renamed or deleted, but their permission set may be adjusted").

This is **not** equivalent to unrestricted platform administration: mutating a role's
permission set requires the canonical `Roles.Manage` permission (via `RequirePermission`),
never a role name. The permission-management endpoint grants nothing beyond what a role is
already allowed to hold — it only changes which catalog permissions that role carries.

## Consequences

- Custom roles remain fully editable/deletable; deleting a role removes grants but never
  deletes users.
- The `Administrator` role can in principle be weakened (its permission set reduced). This is
  the operator's choice and is audited; it does not bypass the last-active-administrator
  guard because that guard is based on role membership, not permissions.
- **Future work / watch item:** some future system-critical roles may need **protected
  permissions** (permission sets that even `Roles.Manage` cannot alter). Before introducing
  such roles, revisit this ADR and add a `protectedPermissions` concept (e.g. an explicit
  allow-list per system role, or a `CanChangePermissions` flag). Do not silently change the
  current behavior.
- If shape 1 (fully immutable system roles) is ever required, it is a deliberate breaking
  change to this ADR, not an incidental refactor.

## Verification

Covered by `RoleManagementCommandTests` (system-role rename/delete → `Conflict`,
set-permissions success) and `RoleManagementApplicationTests` (system-role endpoints,
permission round-trip, cross-tenant isolation).
