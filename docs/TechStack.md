# Tech Stack

> Status: governing. Recorded in ADR-0002 … ADR-0006.

| Concern | Choice | Why |
|---|---|---|
| Client (all platforms) | Flutter (Dart) | **One codebase** for Android/iOS/desktop/web, offline-first, strong UI toolkit, solo-dev maintenance optimization |
| Backend | ASP.NET Core (.NET 10), C# | High performance, strong typing, mature ecosystem, CQRS tooling |
| Architecture | Clean Architecture + CQRS (MediatR) | Enforced separation, testability, DDD seams |
| Database | PostgreSQL 17 (Npgsql + EF Core) | Reliable, JSONB for dynamic fields, row-level multi-tenancy |
| Cache / queue | Redis (interface w/ in-memory fallback for dev) | Session/cache/rate-limit/queue, swappable |
| Search | OpenSearch behind `ISearchService` (later) | Indexed search across all modules |
| Files | S3-compatible object storage (MinIO local) | Receipts, contracts, images, backups |
| Auth | JWT access + refresh, BCrypt, MFA (TOTP), OTP later | Stateless + refresh rotation |
| Event bus | In-process bus + Postgres outbox (worker flushed) | Reliable delivery without premature microservices |
| Observability | Serilog (structured logs) → OpenTelemetry, health endpoints | Trace a request per tenant from day one |
| State on device | Riverpod (per-feature, migrating from Bloc) + go_router | Offline state management |
| Local DB on device | Drift (SQLite) | Offline-first outbox schema already modelled |

## Languages

**Only two:** Dart + C#

**Dropped (2026-08-31):** React (separate web frontend), Tauri (separate desktop frontend).

**Rationale:** Solo developer optimizing for maintenance complexity, not "best technology
per platform." One codebase = shared auth, API client, models, state management, validation,
localization, theme, components, navigation, error handling, permissions, business workflows,
offline storage, synchronization, testing utilities.

## Development environment (local only — no deployment)

| Service | How | Connection |
|---|---|---|
| PostgreSQL | Podman container, `postgres:17` | `localhost:5432`, db `businessos`, user `businessos`, password from `DATABASE_URL` env var |
| Redis | Podman container, `redis:7` | `localhost:6379` |
| MinIO | Podman container, `minio/minio` | `localhost:9000` / console `9001` |
| API | `dotnet run` (API project) | `https://localhost:5001` / `http://localhost:5000` |
| Workers | `dotnet run` (Workers project) | background host (outbox/email) |

**Run both.** Outbox-backed work (e.g. the email-verification code, password-reset emails,
scheduled jobs) is delivered only by the separate **Workers** host draining the Postgres
outbox. If the API runs alone, aggregate events with in-process handlers (like the welcome
email) still arrive, but outbox-only emails never do. Start everything together with:

```bash
./backend/run-dev.sh      # API + Workers (see the script header for prereqs)
```

or run the two projects in separate terminals:
```bash
dotnet run --project backend/src/API/BusinessOS.API.csproj
dotnet run --project backend/src/Workers/BusinessOS.Workers.csproj
```

Both projects keep their own `appsettings.Development.json`; `src/Workers/appsettings.Development.json`
mirrors the API's dev DB/JWT/SMTP values so the Workers host can reach Postgres and MailHog, and
`src/Workers/Program.cs` binds the `Smtp` options (without it the `EmailChannel` reports
"SMTP not configured" and no email is ever sent).

Secrets for local development live in `appsettings.Development.json` (never committed for
prod). The committed files contain dev-only values.
