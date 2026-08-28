# ADR-0009 — Local dev database: dedicated role on the system PostgreSQL

- **Status:** Accepted
- **Date:** 2026-08-05

## Context

The local machine runs a system PostgreSQL 17 on port 5432. The project needs its own
database and role so it never collides with other projects on the same server. Redis and
MinIO are not installed system-wide.

## Decision

- Use the **system PostgreSQL 17** with a dedicated, app-owned role `businessos` and
   database `businessos` (owner `businessos`). Dev password: set via `DATABASE_URL` env var
   (the trailing period is part of the password).
- Cache/queue: `ICacheService` interface with an in-memory fallback for dev; a Redis 7
  container (Podman) is provided via `deploy/docker-compose.yml` and used when running.
- Files: MinIO container (Podman) via docker-compose, used from Phase 1 onward.

## Consequences

- No extra database server to maintain; the app never touches other projects' databases.
- Dev password is local-only; production secrets come from env/secret store.
