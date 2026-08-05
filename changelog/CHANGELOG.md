# Changelog

## v0.1.0 — 2026-08-05 — Phase 0 foundation (in progress)

### Backend
- Created modular-monolith solution `backend/BusinessOS.slnx` (Shared, Domain, Application,
  Infrastructure, API, Workers, Notifications, Modules.Sales).
- Domain kernel: `Result<T>`/`Error`, `Entity`/`AggregateRoot`, `IDomainEvent`.
- Platform domain stubs: `Tenant`, `Role`, `Permission`, `PermissionNames`, `UserRegisteredEvent`.

### Docs
- Engineering handbook: Vision, Architecture, TechStack, CodingStandards, ArchitectureRules,
  APIStandards, Security, ReleaseProcess, roadmap.
- Decision log ADR-0001…0010. Project memory. Changelog. Spec/task templates.

### Known gaps (next)
- API is still the default template; no auth, no EF, no Postgres wiring yet.
- Application/Infrastructure/Notifications/Modules.Sales empty.
- Workers project does not build. Dev infra (podman) not yet created.
