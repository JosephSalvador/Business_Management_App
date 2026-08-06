# Architecture Rules

> Read before every task. These are non-negotiable and "almost never change."

## Code rules

- Never duplicate business logic. Extract to a shared service or engine.
- Never access the database directly from UI or controllers. Go through `Application` use cases.
- Modules never reference other modules — only platform contracts.
- Every API returns `Result<T>` (or a problem-details envelope on failure).
- Every table has a UUID primary key.
- Every table has `CreatedAt` / `CreatedBy` and `UpdatedAt` / `UpdatedBy`.
- Every mutation creates an audit log entry (actor, action, entity, tenant, old/new).
- Every mutation that raises side effects persists domain events (outbox) in the same transaction.
- Every feature has permissions defined in `PermissionNames` and enforced by the RBAC pipeline.
- Every feature has unit tests; cross-module flows have integration tests.
- No feature merges without documentation (spec + API + changelog updated).
- No TODOs in production code.
- No magic numbers, no hardcoded colors, no hardcoded URLs, no hardcoded business rules.
- Everything configurable: tax rules, numbering sequences, currencies, units, dynamic fields, UI strings.
- API-first: a REST endpoint exists before the UI screen.

## Database schema strategy

- All tables live in the `public` schema during Platform and Foundation phases to keep migration
  complexity low.
- Every EF Core entity mapping declares its schema explicitly with
  `ToTable("<Table>", "<Schema>")` — never rely on provider defaults.
- Table names and schemas come from the catalog in
  `backend/src/Infrastructure/Persistence/TableNames.cs`, grouped by bounded context
  (Organization, Identity, Platform, ...). Mappings reference these constants only.
- A bounded context moves into its own PostgreSQL schema by changing its schema constant in
  `TableNames.cs` and generating one migration. Do not split schemas until Sales, Inventory,
  and Accounting are stable.

## Process rules

- Read `docs/ArchitectureRules.md` + `docs/CodingStandards.md` + the feature spec before coding.
- Create an implementation plan and get approval before implementing a feature.
- Implement one small task at a time. Run analyzers and tests. Fix failures.
- Produce a completion report; update documentation; suggest the next task.
- OpenCode must never invent architecture, rename unrelated files, modify completed modules
  without a task, skip tests/docs, ignore warnings, change standards, or commit unverified code.

## Definition of Done (all must be true)

- Requirements implemented
- No analyzer warnings
- Tests pass
- Manual checklist passes
- Documentation updated (spec/API/changelog)
- Database migration created
- Localization added
- Audit logging added
- Permissions added
- Responsive UI verified
- Offline mode + sync verified
- Error handling verified
