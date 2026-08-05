# ADR-0010 — Riverpod over Bloc (per-feature swap)

- **Status:** Accepted
- **Date:** 2026-08-05

## Context

The Flutter app currently uses Bloc. Riverpod is simpler for offline-first, DI-heavy,
sync-oriented state and avoids boilerplate that discourages small features.

## Decision

Migrate to **Riverpod**, feature by feature, behind feature flags — no big-bang rewrite.
Keep go_router for navigation.

## Consequences

- Lower boilerplate, easier testing of providers, natural DI for repositories/services.
- Both paradigms coexist during transition (guarded by feature flags).
