# ADR-0007 — JWT + rotating refresh tokens, BCrypt

- **Status:** Accepted
- **Date:** 2026-08-05

## Context

Native + web clients on cheap devices, offline sessions, and mobile-money-driven transactions
need secure but simple auth with long-lived sessions that can be revoked.

## Decision

- Access tokens: short-lived JWT (~15 min).
- Refresh tokens: rotating, hashed (SHA-256) at rest, revocable, stored server-side.
  Replay detection revokes the whole token family.
- Passwords: BCrypt (cost 12).
- MFA (TOTP) and OTP planned on the same seam.

## Consequences

- Revocation possible server-side (kills a stolen session).
- Refresh rotation adds DB writes per refresh — negligible at our scale.
