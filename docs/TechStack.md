# Tech Stack

> Status: governing. Recorded in ADR-0002 … ADR-0006.

| Concern | Choice | Why |
|---|---|---|
| Mobile/desktop client | Flutter (Dart) | One codebase for Android/iOS/desktop/web, offline-first, strong UI toolkit |
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

## Development environment (local only — no deployment)

| Service | How | Connection |
|---|---|---|
| PostgreSQL | Podman container, `postgres:17` | `localhost:5432`, db `businessos`, user `businessos`, password `Joseph662` |
| Redis | Podman container, `redis:7` | `localhost:6379` |
| MinIO | Podman container, `minio/minio` | `localhost:9000` / console `9001` |
| API | `dotnet run` (API project) | `https://localhost:5001` / `http://localhost:5000` |

Secrets for local development live in `appsettings.Development.json` (never committed for
prod). The committed files contain dev-only values.
