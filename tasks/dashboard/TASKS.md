# TASKS — Operational Dashboard (Slice 5)

> Spec: `specs/dashboard.md`. Implement one task at a time; run analyzers and tests after each;
> update this file as you go. No code until the spec is approved.
>
> Read-only backend slice: no domain changes, no migrations, no events, no audit writes.
> Commit style: `feat(dashboard): ...`, `test(dashboard): ...`, `docs(dashboard): ...`.

## Status legend

`[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked (note why)

- [x] 001 **Ports + repository**: `IDashboardRepository` in `Application/Ports`
      (`GetSummaryAsync`, `ListLowStockAsync`, `ListRecentActivityAsync`) + EF
      `DashboardRepository` in `Infrastructure/Repositories` (tenant-scoped GROUP BY/SUM
      aggregations over existing tables, join `Users` for actor emails, newest-first);
      register in DI.
- [x] 002 **Application — dashboard**: `Features/Dashboard` DTOs
      (`DashboardSummaryDto`, `DashboardLowStockDto`, `DashboardActivityDto`), mapper, and
      queries `GetDashboardSummaryQuery`, `GetLowStockQuery`, `GetRecentActivityQuery` +
      handlers with validation (`limit` 1..100, `maxQuantity` >= 0).
- [x] 003 **API endpoints**: `DashboardEndpoints` — `GET /api/v1/dashboard/summary`,
      `/low-stock`, `/recent-activity`, all `RequirePermission(PermissionNames.DashboardView)`;
      register in `Program.cs`.
- [x] 004 **Tests**: unit (mapper projections, validation) + integration (summary KPIs match a
      seeded tenant; low-stock ordering + threshold; recent-activity newest-first with actor
      email; 403 for a `Dashboard.View`-less role; tenant isolation; no audit rows written by
      dashboard reads). Full suite: 236/236 passing.
- [x] 005 **Docs + commit**: build/format/tests; spec implemented & verified; changelog bullet,
      `memory/project.md`, roadmap item 5 `[x] backend slice`, readiness report; completion
      report; pause for review.
