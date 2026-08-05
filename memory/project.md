# Project Memory — read before every task

## business.md — who we build for

- **Target users:** small shops, retail, wholesale, manufacturing, schools, hospitals,
  hotels, agriculture (East Africa first: Tanzania, Kenya, Uganda).
- **Buyer pain:** offline POS, mobile money, local tax (TRA/KRA/URSB), Swahili UI, low
  bandwidth, simple onboarding (< 10 min), per-branch pricing.
- **Positioning:** the African alternative to Odoo / Zoho / SAP B1 / Dynamics 365. Platform,
  not a single ERP.

## architecture.md — current state (2026-08-05)

- Modular monolith: Shared / Domain / Application / Infrastructure / API / Workers /
  Notifications / Modules.*. Solution `backend/BusinessOS.slnx`.
- Event-driven + outbox; CQRS (MediatR); UUID PKs; shared-DB tenancy with `tenant_id`.
- **Honest status:** scaffold only. API is still the default weather template; Application,
  Infrastructure, Notifications, Modules.Sales have no source files; Workers does not build;
  build currently FAILS. Phase 0 real implementation is in progress.
- Key docs: `docs/ArchitectureRules.md`, `docs/Architecture.md`, `docs/roadmap.md`.

## coding.md — see `docs/CodingStandards.md`

## api.md — see `docs/APIStandards.md`

## database.md — see `docs/TechStack.md` + ADR-0002/0008

- Local: podman postgres:17, db `businessos`, user `businessos`, password `Joseph662`,
  port 5432. Redis `localhost:6379`, MinIO `localhost:9000/9001`.

## ux.md — product principles

- Mobile-first, one-hand usable, works on cheap Android, offline-first.
- Swahili + English localization first-class. Large tap targets for POS.
- Guided onboarding < 10 min. Every screen earns its place.

## branding.md

- Product name: **Business OS**. Flutter package: `business_management_system`.
- Goal tone: trustworthy, simple, local. (Full brand guide deferred.)

## known_issues.md

- System Postgres 17 `postgres` password unknown → we use our own container DB (ADR-0009).
- Redis/minio binaries not installed → containers.
- API project started from the .NET weather template; weather endpoint must be removed.
- Workers project namespace is broken (`BusinessOS.Workers`); needs a real host.

## technical_debt.md

- Flutter app: SharedPreferences + in-memory mocks still drive auth/products/sales; Drift DB
  (11 tables) is built but disconnected from the running app.
- Roadmap checkboxes marked `[x]` for Phase 0 are aspirational — not all implemented.
