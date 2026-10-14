import 'package:flutter/material.dart';

/// Refined color tokens for JOLINX Business OS.
///
/// Design principles:
/// - Blue as primary brand — trustworthy, professional
/// - Teal as restrained accent — positive actions, status indicators
/// - Strong contrast for accessibility (WCAG AA)
/// - No excessive saturation — calm and practical for daily use
class AppColors {
  AppColors._();

  // ── Primary (Blue) ──────────────────────────────────────────────
  static const Color primary = Color(0xFF1A6DFF);
  static const Color primaryLight = Color(0xFF4D8FFF);
  static const Color primaryDark = Color(0xFF0050CC);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFE8F0FE);
  static const Color onPrimaryContainer = Color(0xFF003A99);

  // ── Secondary (Teal) ────────────────────────────────────────────
  static const Color secondary = Color(0xFF00B894);
  static const Color secondaryLight = Color(0xFF55D6BE);
  static const Color secondaryDark = Color(0xFF008F6F);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFE6F9F4);
  static const Color onSecondaryContainer = Color(0xFF004D3D);

  // ── Tertiary (Warm Neutral) ─────────────────────────────────────
  static const Color tertiary = Color(0xFF6B7280);
  static const Color onTertiary = Color(0xFFFFFFFF);

  // ── Surfaces ────────────────────────────────────────────────────
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFF8FAFB);
  static const Color surfaceContainer = Color(0xFFF1F4F8);
  static const Color surfaceContainerHigh = Color(0xFFE8ECF0);
  static const Color onSurface = Color(0xFF1A1C1E);
  static const Color onSurfaceVariant = Color(0xFF4A4D52);

  // ── Background ──────────────────────────────────────────────────
  static const Color background = Color(0xFFF8FAFB);
  static const Color onBackground = Color(0xFF1A1C1E);

  // ── Outline ─────────────────────────────────────────────────────
  static const Color outline = Color(0xFFD1D5DB);
  static const Color outlineVariant = Color(0xFFE5E7EB);

  // ── Semantic ────────────────────────────────────────────────────
  static const Color error = Color(0xFFEF4444);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFEE2E2);
  static const Color onErrorContainer = Color(0xFF991B1B);

  static const Color success = Color(0xFF00B894);
  static const Color onSuccess = Color(0xFFFFFFFF);
  static const Color successContainer = Color(0xFFDCFCE7);
  static const Color onSuccessContainer = Color(0xFF166534);

  static const Color warning = Color(0xFFF59E0B);
  static const Color onWarning = Color(0xFF1A1C1E);
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color onWarningContainer = Color(0xFF92400E);

  // ── Text ────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A1C1E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textInverse = Color(0xFFFFFFFF);

  // ── Dark-mode text overrides ───────────────────────────────────
  static const Color textPrimaryDark = Color(0xFFE3E3E3);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textTertiaryDark = Color(0xFF64748B);

  // ── Theme-aware helpers ────────────────────────────────────────
  /// Returns the correct text color based on current brightness.
  static Color resolveTextPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? textPrimaryDark
          : textPrimary;

  static Color resolveTextSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? textSecondaryDark
          : textSecondary;

  static Color resolveTextTertiary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? textTertiaryDark
          : textTertiary;

  static Color resolveCardBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E293B)
          : surface;

  static Color resolveOutline(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF334155)
          : outline;

  // ── Legacy aliases (backward compat) ────────────────────────────
  static const Color primaryColor = primary;
  static const Color secondaryColor = secondary;
  static const Color backgroundColor = background;
  static const Color surfaceColor = surface;
  static const Color errorColor = error;
  static const Color successColor = success;
  static const Color warningColor = warning;

  // ── Wave Background ────────────────────────────────────────────
  // Light theme — layered blues with warm contrast
  static const Color waveLightDeep = Color(0xFFDBEAFE); // back layer, softest
  static const Color waveLightBase = Color(0xFFBFDBFE); // second layer
  static const Color waveLightMid = Color(0xFF7DD3FC); // mid layer, visible
  static const Color waveLightFront = Color(0xFF38BDF8); // front layer, vivid
  static const Color waveLightAccent = Color(0xFF0284C7); // accent wave, deep
  static const Color waveLightWarm = Color(0xFFFDE68A); // warm contrast hint
  static const Color waveLightGlow = Color(0xFFBAE6FD); // radial glow center

  // Dark theme — visible but muted blues with gold accent
  static const Color waveDarkDeep =
      Color(0xFF1A2744); // back layer, visible lift
  static const Color waveDarkBase =
      Color(0xFF1E3A5F); // second layer, slate blue
  static const Color waveDarkMid = Color(0xFF2563EB); // mid layer, bright blue
  static const Color waveDarkFront =
      Color(0xFF3B82F6); // front layer, primary blue
  static const Color waveDarkAccent =
      Color(0xFF60A5FA); // accent wave, light blue
  static const Color waveDarkWarm =
      Color(0xFFF59E0B); // gold accent, brand identity
  static const Color waveDarkGlow = Color(0xFF1E40AF); // radial glow, blue

  // ── Gradients (subtle, for decorative use only) ─────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0050CC), Color(0xFF1A6DFF), Color(0xFF4D8FFF)],
    stops: [0.0, 0.5, 1.0],
  );
}
