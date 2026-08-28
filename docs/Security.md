# Security

> Security baseline for the platform. Local dev only right now — no deployment.

## Identity

- Passwords hashed with **BCrypt** (cost 12). Never stored in plain text or reversible form.
- **JWT access tokens** (short-lived, ~15 min) + **refresh tokens** (rotating, revocable,
  hashed at rest, stored server-side). Refresh rotation: a replayed token is detected and
  the family is revoked.
- MFA (TOTP) and phone/email OTP are planned for Phase 2; the auth model must leave seams.
- Login endpoints are rate-limited (Redis) to slow brute force.

## Tenancy & authorization

- Every tenant-owned query is forced through a tenant filter by the repository/query layer.
- RBAC enforced server-side per endpoint via permission attributes. UI gating is UX, not security.
- Feature flags do not imply security — a disabled feature hides UI, permissions still guard.

## Secrets

- No secrets in code or committed config. `appsettings.json` contains dev-only values;
  production config is injected (env vars / secret store) at deploy time.
- `DATABASE_URL` env var holds the local dev DB password. Never hardcode in source.

## Data

- All connections use TLS in any non-local environment.
- PII (names, phones, TINs) is logged only when necessary; audit logs record *what changed*,
  not full PII dumps.
- Backups: object storage (MinIO) for files; pg_dump scheduled later (Workers).

## Dependency hygiene

- `dotnet list package --vulnerable` / `flutter pub outdated` are part of release checks.
- No unvetted third-party code in the platform core.
