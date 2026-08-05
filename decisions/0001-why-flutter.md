# ADR-0001 — Why Flutter

- **Status:** Accepted
- **Date:** 2026-08-05

## Context

We must serve offline-first POS to small African businesses on cheap Android devices, plus
desktop (self-hosted) and eventually web. The team writes both a native-quality UI and a
sync-heavy client.

## Decision

Flutter/Dart for all client surfaces: Android, iOS, Windows/macOS/Linux desktop, web.

## Consequences

- One codebase, near-native performance, excellent offline story (SQLite via Drift).
- Riverpod for state; go_router for navigation.
- Trade-off: not native — acceptable for business forms and POS, where Flutter is proven.
