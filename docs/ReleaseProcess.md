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
3. Tag `vX.Y.Z` in git. Write changelog entry.
4. (Deployment is out of scope until later phases.)
