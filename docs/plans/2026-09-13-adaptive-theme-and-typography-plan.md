# Adaptive Theme and Typography Plan

## Goal

Make the Flutter client visually consistent and accessible in both light and
dark modes, while preserving the platform default typeface and responding to
the device's text-size setting.

## Scope

- Keep `ThemeMode.system` as the default and retain the existing user override.
- Consolidate theme-aware visual tokens around Material `ColorScheme` and
  `TextTheme`.
- Complete the dark-theme component definitions to match the light theme.
- Update shared widgets and high-traffic screens that currently hard-code
  light-mode colors.
- Verify layout at normal and large text scaling.

## Non-goals

- No custom global font or bundled brand font. The app should retain the
  platform's default typeface. Receipt text remains monospace by design.
- No business-flow, API, data, routing, or permission changes.
- No redesign of the established JOLINX blue/teal visual identity.

## Implementation tasks

1. **Theme foundation**
   - Refactor `AppTheme` so light and dark themes define the same Material 3
     component surface: buttons, inputs, cards, navigation, sheets, dialogs,
     chips, dividers, lists, tabs, snackbars, and progress indicators.
   - Use `ColorScheme` values for component state colors rather than fixed
     light-mode tokens.
   - Add a small theme extension for semantic success and warning colors where
     Material `ColorScheme` has no suitable token.

2. **Typography and accessibility**
   - Keep `fontFamily` unset in the application text theme so the platform
     default typeface is selected.
   - Use `TextTheme` roles instead of repeated local font-size/color rules in
     shared widgets and the scoped screens.
   - Do not override `MediaQuery.textScaler`; this preserves device text-size
     changes and accessibility settings.
   - Use flexible layouts, wrapping, and scroll-safe sheets where larger text
     could otherwise overflow.

3. **Shared component conversion**
   - Update `StatCard`, `AppSearchBar`, empty/not-found states, section headers,
     responsive shell, and wave-backed surfaces to resolve colors from the
     current theme.
   - Preserve the decorative wave treatment but reduce its contrast behind
     readable content in dark mode.

4. **Screen conversion and visual QA**
   - Convert direct `AppColors.surface`, text, outline, white, and black usage
     in the primary authenticated flows: dashboard, POS/cart/payment, products,
     finance, settings, and reports.
   - Convert onboarding/authentication fixed colors that break dark mode.
   - Leave intentionally fixed receipt/printer styling unchanged.

5. **Verification and documentation**
   - Add focused widget tests for system/light/dark rendering and text-scale
     resilience of shared components.
   - Run `dart format`, `flutter analyze`, and the Flutter test suite.
   - Record the completed visual-system change in project documentation.

## Acceptance checks

- Changing the phone's light/dark appearance updates the app when the user has
  selected "Follow device".
- No standard content surface or body text remains light-only in dark mode.
- Default UI text has no forced font family; only receipt output may use
  monospace.
- Key screens remain usable at 130% and 200% text scale without clipped actions
  or inaccessible controls.
- Analyzer and tests are clean.
