# ADR-0006 — Event-driven + outbox

- **Status:** Accepted
- **Date:** 2026-08-05

## Context

Sale → stock reduction → accounting → SMS → analytics → audit used to be one hard-coded
method call chain. That couples modules and loses events if a step crashes.

## Decision

Modules raise **domain events**; other modules/engines subscribe. Events are persisted to an
**outbox** table in the same transaction as the state change, then delivered by a worker
(in-process for MVP, reliable against crashes). Consumers are idempotent.

## Consequences

- Loose coupling: Sales never knows about Accounting/Notifications.
- Reliability: an event is never lost between transaction and delivery.
- Basis for analytics, audit, and future microservice split.
