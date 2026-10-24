# AGENTS — Working agreement for AI assistants (OpenCode)

Read this file, plus `memory/project.md`, `docs/ArchitectureRules.md`, and
`docs/CodingStandards.md` at the start of every session.

## The loop (never skip)

1. Read project memory → architecture rules → the feature spec.
2. Create an implementation plan (this file) → get approval before implementing.
3. Implement one small task at a time.
4. Run analyzers and tests; fix failures.
5. Produce a completion report; update documentation; suggest the next task.

## Never do

- Invent architecture or rename unrelated files.
- Modify completed modules without a task.
- Leave TODOs in production code.
- Skip tests or documentation.
- Ignore warnings.
- Mix UI and business logic.
- Commit code without verification.
- Ship or commit client builds without strictly incrementing build-number/versionCode (so installed devices can update in-place without uninstalling).

## Definition of Done

See `docs/ArchitectureRules.md`. Nothing is done until spec, implementation, tests,
documentation, migration, permissions, audit, API, offline, and sync are complete.

## Implementation Plan — Advisory Stock in POS & Offline Checkout
- [x] Task 1: Update `OfflineSaleRecorder.record` to not block sales when stock is low/zero (advisory stock).
- [x] Task 2: Update `_ProductCard`, `_addToCart`, and `_quickQuantity` in `pos_page.dart` to make stock advisory (allow tap, show advisory badge instead of red error/disabled tap).
- [x] Task 3: Update `test/features/sales/offline_checkout_test.dart` to verify non-blocking advisory stock.
- [x] Task 4: Increment version code in `pubspec.yaml` (1.0.0+56).
- [x] Task 5: Run flutter analyze and flutter test; verify clean passes.
- [x] Task 6: Commit and push changes, then trigger `build-clients.yml` to produce the new APK for the user.

