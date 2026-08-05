# ADR-0003 — Modular monolith first (no microservices)

- **Status:** Accepted
- **Date:** 2026-08-05

## Context

A platform that will grow many modules. Microservices from day one add distributed
transactions, outbox fan-out, and ops cost before there is a team to justify them.

## Decision

Start as a **modular monolith**: one deployable API host, modules as vertical slices,
communication via domain events + outbox (already the reliable seam microservices need).
Split a module into its own service only when its team, scale, or cadence demands it.

## Consequences

- One deployment: simpler ops, atomic migrations, low-latency in-process events.
- Modules stay decoupled via events, so a future split is mechanical, not a rewrite.
- This is how Odoo/Zoho-class platforms actually evolved.
