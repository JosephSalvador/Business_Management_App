# ADR-0005 — CQRS with MediatR

- **Status:** Accepted
- **Date:** 2026-08-05

## Context

A platform with many modules and a strict "API-first, business logic behind use cases" rule.
We need a uniform pipeline for validation, tenant filtering, RBAC, audit, and transactions so
cross-cutting concerns are not re-implemented per endpoint.

## Decision

Commands and queries via **MediatR**, dispatched from thin API endpoints. Handlers are the
unit of business logic. Pipeline behaviors handle validation, tenancy, and transaction/outbox.

## Consequences

- One place for cross-cutting concerns (pipeline behaviors), not per-endpoint copies.
- Handlers are plain classes — easy to unit test without HTTP.
- Trade-off: indirection; kept honest by keeping handlers thin and domain logic in entities.
