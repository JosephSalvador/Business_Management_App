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

## Implementation Plan — Remove VAT & Tax Everywhere in the App
- [x] Task 1: Remove Tax/VAT summary row from `sale_detail_page.dart` and `receipt_printer_service.dart`.
- [x] Task 2: Replace "Tax No" / "Namba ya Kodi" labels with "TIN" in `receipt_renderer.dart` and update receipt tests.
- [x] Task 3: Remove "VAT Registered" / "Mwasilishaji VAT" switch and display from `customer_form_page.dart` & `customer_detail_page.dart`.
- [x] Task 4: Remove "Tax %" / "Kodi %" input from invoice creation (`create_invoice_page.dart`).
- [x] Task 5: Remove dedicated "Tax" / "Kodi" section in `settings_page.dart` and merge TIN into Organization Information.
- [x] Task 6: Clean up TRA / Tax marketing copy in `module_upgrade_sheet.dart`, documentation, and ARB localization files.
- [x] Task 7: Increment version code in `pubspec.yaml` (1.0.0+59).
- [ ] Task 8: Commit, push changes, and trigger `build-clients.yml` to generate the updated APK.


