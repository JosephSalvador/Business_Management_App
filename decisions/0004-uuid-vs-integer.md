# ADR-0004 — UUID over integer primary keys

- **Status:** Accepted
- **Date:** 2026-08-05

## Context

Offline-first: devices generate entities without a server round-trip, then sync. Integer
identity breaks when two offline devices both assign id 5. GUIDs also enable non-enumerable
resource ids (security) and cross-tenant merging.

## Decision

UUID (v4, generated client- or server-side) as the primary key for all entities. Also used
as `Idempotency-Key` and event ids.

## Consequences

- No id conflicts offline; sync is simpler.
- Slight index bloat vs bigint — irrelevant at our scale; Postgres `uuid` is efficient.
- PostgreSQL stores as `uuid` type.
