# ADR-0008 — Shared-DB multi-tenancy with tenant_id

- **Status:** Accepted
- **Date:** 2026-08-05

## Context

Affordable multi-tenant SaaS for SMEs: many small tenants, low per-tenant cost, easy
backups, and a clear isolation story for enterprise customers later.

## Decision

Shared database; **`tenant_id` on every tenant-owned row**; repository/query-layer guardrail
that refuses tenant-owned queries without a tenant filter. Feature flags gate module
visibility per tenant. Schema-per-tenant is the documented escape hatch for enterprise.

## Consequences

- Low cost per tenant, simple ops, easy reporting across tenants.
- Isolation depends on code discipline → enforced by pipeline guardrail + tests.
- Enterprise escape hatch: same server, separate schema, no code change.
