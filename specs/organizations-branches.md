# Feature Spec — Organizations & Branches

> Phase 1, first slice. Approval required before coding. Tasks in
> `tasks/organizations-branches/TASKS.md`.
>
> **Status: implemented & verified 2026-08-06.** Backend slice complete (tasks 001–009);
> tests green. Flutter/Drift follow-ups remain as listed under Offline & sync / Future
> improvements.

## Feature

Organizations & Branches — tenant (organization) profile management and a tenant-scoped
branch hierarchy, the foundation for per-branch pricing and the POS branch context.

## Purpose

Phase 1 roadmap item #2. Every business module (Sales, POS, Inventory, Accounting) needs a
branch context to operate in. This slice establishes the tenant-scoped repository pattern,
the first live use of `RequirePermission` on real business endpoints (readiness gap #3),
and the first `Modules`-style vertical slice using platform engines (audit, outbox events,
permissions).

## Business rules

- An **organization is the tenant** (`Tenant` aggregate). There is exactly one organization
  per tenant; no separate 1:1 profile table.
- Every tenant has **one or more branches**. Registration auto-creates a default branch
  `Head Office` (code `HQ`) so a tenant is POS-ready immediately.
- A **branch** belongs to exactly one tenant and is never visible to another tenant
  (tenant isolation is enforced in queries and by unique index on `(TenantId, Code)`).
- Branch `code` is unique within a tenant, trimmed and uppercased, `A-Z0-9-` only.
- Branches are **deactivated**, never hard-deleted (future sales reference `branch_id`).
- Per-branch pricing is supported: each branch carries an ISO 4217 `currency`; a tenant has
  a default currency used for its initial branch.
- Branch/organization updates are tracked by the audit engine automatically.

## Screens (Flutter)

None in this slice (API-first). The Flutter organization/branch screens consume these
endpoints in the onboarding flow (later Phase 1 task). Drift currently has no branches
table — adding one is a follow-up Flutter task.

## API (backend)

All authenticated (`Bearer`), versioned `/api/v1`, rate-limited by the `global` policy.

| Method | Route | Permission | Body / Query | Success |
|---|---|---|---|---|
| GET | `/api/v1/organization` | `Organizations.View` | — | 200 `OrganizationDto` |
| PUT | `/api/v1/organization` | `Organizations.Manage` | `UpdateOrganizationRequest` | 200 `OrganizationDto` |
| GET | `/api/v1/branches` | `Branches.View` | `?page=1&pageSize=50` | 200 `PagedResult<BranchDto>` |
| POST | `/api/v1/branches` | `Branches.Create` | `CreateBranchRequest` | 200 `BranchDto` |
| GET | `/api/v1/branches/{id}` | `Branches.View` | — | 200 `BranchDto` |
| PUT | `/api/v1/branches/{id}` | `Branches.Update` | `UpdateBranchRequest` | 200 `BranchDto` |
| PATCH | `/api/v1/branches/{id}/status` | `Branches.Update` | `SetBranchStatusRequest { isActive }` | 200 `BranchDto` |

Failure: RFC 7807 `ProblemDetails` with stable `code` (`Validation`, `NotFound`,
`Conflict`, `Unauthorized`, `Forbidden`). Errors never leak internals.

> Note: all successful mutations return `200` — the platform's `ToApiResult` maps every
> success to `200` (established in the Auth slice); `201` is reserved for a future
> `Idempotency-Key`/created-resource handling change.

`OrganizationDto` = id, name, email, phone, address, currency, taxId, isActive.
`BranchDto` = id, tenantId, name, code, address, phone, email, currency, isActive,
createdAt, updatedAt.

## Database

- **`tenants`** — extended (migration): `ContactEmail` (varchar 320?), `ContactPhone`
  (varchar 30?), `Address` (text?), `Currency` (varchar 3, default `TZS`), `TaxId`
  (varchar 64?).
- **`branches`** — new table: `Id` uuid PK, `TenantId` uuid FK indexed, `Name` varchar 200,
  `Code` varchar 50, `Address` text?, `Phone` varchar 30?, `Email` varchar 320?,
  `Currency` varchar 3, `IsActive` bool. Unique index `(TenantId, Code)`. Standard
  `CreatedAt/CreatedBy/UpdatedAt/UpdatedBy` (base `Entity`).
- Migration name: `20260805_AddOrganizationProfileAndBranches`.

## Validation

- Organization name: required, max 200. Email: valid format when present. Currency:
  required ISO 4217 uppercase. TaxId: max 64.
- Branch name: required, max 200. Code: required, max 50, `^[A-Za-z0-9-]+$` (normalized to
  uppercase on write). Email: valid format when present. Currency: required ISO 4217
  uppercase.
- Duplicate branch code → `Conflict` (case-insensitive after normalization).

## Permissions

New entries in `PermissionNames` (added to `All`):

- `Organizations.View`, `Organizations.Manage`
- `Branches.View`, `Branches.Create`, `Branches.Update`, `Branches.Delete`
  (`Branches.Delete` reserved for a future hard-delete; status toggle uses `Branches.Update`)

The seeder must **re-grant new permissions to existing system `Administrator` roles** so
existing tenants (including the demo admin) gain them without re-registering.

## Events

- `BranchCreatedEvent` (raised on `Branch.Create`)
- `BranchUpdatedEvent` (raised on profile update)
- `BranchStatusChangedEvent` (raised on activate/deactivate)

Consumed (outbox-backed) by an activity-feed handler that logs — proves event delivery for
branch mutations; future consumers: notifications, reporting, sync.

## Reports

None in this slice.

## Tests

- **Unit:** `Branch` factory + code normalization + activate/deactivate; `Tenant` profile
  update; new permission constants in `All`.
- **Integration** (`WebApplicationFactory` against `businessos_test`):
  - Register auto-creates the default `HQ` branch.
  - Full CRUD + status flow returns the right codes and shapes.
  - Without the permission claim → 403; `Branches.View` role cannot create.
  - Tenant A cannot read/update tenant B's branch (`NotFound`).
  - Pagination shape `{ items, page, pageSize, total }`.
  - Audit rows written for create/update/status mutations.
  - `BranchCreatedEvent` lands in the outbox and is dispatched.

## Offline & sync

- `GET /api/v1/branches` is the sync source for the future device branch cache.
- Branch rows carry `UpdatedAt` for the `updatedAt` server-wins conflict strategy.
- Mutations accept `Idempotency-Key` for replay safety (per API standards).
- Drift `branches` table + flush wiring are a follow-up Flutter task (Phase 1 POS).

## Future improvements

- Hard delete with guardrails; branch addresses/geo; opening-hours; per-branch numbering
  sequences; default branch per POS device; Flutter onboarding screens + Drift cache.
