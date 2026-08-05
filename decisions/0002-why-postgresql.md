# ADR-0002 — Why PostgreSQL

- **Status:** Accepted
- **Date:** 2026-08-05

## Context

Multi-tenant relational data with heavy reporting, JSONB dynamic fields, strong integrity
(transactions + outbox), and reliability. MySQL/MSSQL/NoSQL considered.

## Decision

PostgreSQL 17 via Npgsql + EF Core.

## Consequences

- Transactions + outbox give reliable event delivery.
- JSONB supports dynamic fields (per-tenant custom attributes) without a schema change.
- Row-level tenancy and `tenant_id` guardrails are straightforward.
- Trade-off: schema-per-tenant escape hatch still possible (same server, separate schemas).
