# Release Process

> Local development only for now (no deployment). This defines the loop we follow per change.

## Flow

```
Architecture → Roadmap → Sprint → Feature spec → Plan (approval)
→ Implement one task → analyzers → tests → manual checklist
→ documentation → commit → changelog → release
```

## Backend checks (before any commit)

```bash
cd backend
dotnet build --nologo          # must be 0 errors, 0 warnings
dotnet test --nologo           # all green
dotnet ef migrations list      # migrations consistent with model
```

## Frontend checks

```bash
flutter analyze                # 0 issues
flutter test                   # all green
dart format --set-exit-if-changed lib test
```

## Definition of Done

See `docs/ArchitectureRules.md`. Nothing is "done" until spec, implementation, tests,
documentation, migration, permissions, audit, API, offline, sync are all complete.

## Versioning

SemVer. `changelog/` holds a dated, human-readable entry per release:

```
YYYY-MM-DD  v0.1.0  Phase 0 foundation
```

## Release steps (eventually)

1. Bump version in csproj + pubspec + changelog.
2. Run full backend + frontend check suites.
3. Deploy primary + backup backends using the universal `Dockerfile` (compatible with Render, Hugging Face Spaces, and Koyeb) connected to managed PostgreSQL 17 (Neon.tech), fronted by `deploy/cloudflare-failover-worker.js` at `https://api.joberthix.xyz`.
4. Push to GitHub or trigger `.github/workflows/build-clients.yml` to build all 6 client platforms (Android, Web, Windows, Linux, macOS, iOS) with `--dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://api.joberthix.xyz --dart-define=API_FALLBACK_URL=https://jolinx-api.onrender.com`.
5. Nightly PostgreSQL disaster recovery backups run via `.github/workflows/db-backup.yml` (`pg_dump` custom compressed format retained for 90 days).
