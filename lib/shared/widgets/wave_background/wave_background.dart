import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import 'wave_painter.dart';

/// A rich decorative overlay with layered waves, gradient fills,
/// top-corner accents, radial glow, decorative lines, and floating dots.
///
/// Adapts automatically to light/dark theme.
///
/// ```dart
/// Scaffold(
///   body: WaveBackground(
///     child: MyPageContent(),
///   ),
/// )
/// ```
class WaveBackground extends StatelessWidget {
  const WaveBackground({
    required this.child,
    this.waveColors,
    super.key,
  });

  final Widget child;

  /// Optional override for wave colors.
  final WaveColorSet? waveColors;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final colors = waveColors ?? (isDark ? _darkColors : _lightColors);

    return Stack(
      children: [
        // Full decorative layer
        Positioned.fill(
          child: CustomPaint(
            painter: WavePainter(
              // ── Radial glow ───────────────────────────────────
              radialGlow: RadialGlowData(
                position: const Offset(0.5, 0.0),
                color: colors.glow,
                radius: 320,
                intensity: isDark ? 0.18 : 0.18,
              ),

              // ── Bottom waves (5 layers, back to front) ───────
              waves: [
                // Back layer — widest, softest
                WaveData(
                  color: colors.deep,
                  opacity: isDark ? 0.15 : 0.10,
                  heightRatio: 0.55,
                  amplitude: 22,
                ),
                // Second layer
                WaveData(
                  color: colors.base,
                  opacity: isDark ? 0.18 : 0.12,
                  heightRatio: 0.48,
                  amplitude: 28,
                ),
                // Mid layer — brand blue
                WaveData(
                  color: colors.mid,
                  opacity: isDark ? 0.22 : 0.18,
                  heightRatio: 0.40,
                  amplitude: 35,
                  showLine: true,
                  lineColor: colors.mid,
                  lineOpacity: isDark ? 0.18 : 0.15,
                  lineWidth: 1.2,
                ),
                // Front layer — vivid
                WaveData(
                  color: colors.front,
                  opacity: isDark ? 0.18 : 0.14,
                  heightRatio: 0.32,
                  amplitude: 30,
                  showLine: true,
                  lineColor: colors.front,
                  lineOpacity: isDark ? 0.15 : 0.12,
                  lineWidth: 0.8,
                ),
                // Accent — light blue, tallest
                WaveData(
                  color: colors.accent,
                  opacity: isDark ? 0.10 : 0.08,
                  heightRatio: 0.60,
                  amplitude: 18,
                ),
              ],

              // ── Warm contrast wave (single layer) ────────────
              // Added as the 6th wave for subtle color variety
              // Positioned as the accent layer
              topAccents: [
                TopAccentData(
                  color: colors.warm,
                  opacity: isDark ? 0.15 : 0.06,
                  heightRatio: 0.08,
                  widthRatio: 0.40,
                  side: AccentSide.left,
                ),
                TopAccentData(
                  color: colors.warm,
                  opacity: isDark ? 0.12 : 0.05,
                  heightRatio: 0.06,
                  widthRatio: 0.30,
                  side: AccentSide.right,
                ),
              ],

              // ── Floating dots ────────────────────────────────
              floatingDots: [
                FloatingDot(
                  position: const Offset(0.12, 0.62),
                  color: colors.mid,
                  opacity: isDark ? 0.15 : 0.15,
                  radius: 2.5,
                ),
                FloatingDot(
                  position: const Offset(0.28, 0.70),
                  color: colors.front,
                  opacity: isDark ? 0.12 : 0.12,
                  radius: 1.8,
                ),
                FloatingDot(
                  position: const Offset(0.45, 0.58),
                  color: colors.accent,
                  opacity: isDark ? 0.10 : 0.10,
                  radius: 2.0,
                ),
                FloatingDot(
                  position: const Offset(0.65, 0.65),
                  color: colors.mid,
                  opacity: isDark ? 0.12 : 0.12,
                  radius: 1.5,
                ),
                FloatingDot(
                  position: const Offset(0.80, 0.55),
                  color: colors.warm,
                  opacity: isDark ? 0.18 : 0.10,
                  radius: 2.2,
                ),
                FloatingDot(
                  position: const Offset(0.92, 0.68),
                  color: colors.accent,
                  opacity: isDark ? 0.10 : 0.08,
                  radius: 1.6,
                ),
                FloatingDot(
                  position: const Offset(0.35, 0.78),
                  color: colors.warm,
                  opacity: isDark ? 0.15 : 0.08,
                  radius: 1.2,
                ),
                FloatingDot(
                  position: const Offset(0.72, 0.75),
                  color: colors.warm,
                  opacity: isDark ? 0.12 : 0.06,
                  radius: 1.0,
                ),
              ],
            ),
          ),
        ),

        // Page content
        Positioned.fill(
          child: child,
        ),
      ],
    );
  }
}

/// Defines the full wave color palette for a theme.
class WaveColorSet {
  const WaveColorSet({
    required this.deep,
    required this.base,
    required this.mid,
    required this.front,
    required this.accent,
    required this.warm,
    required this.glow,
  });

  /// Back layer — widest, softest.
  final Color deep;

  /// Second layer.
  final Color base;

  /// Mid layer — most visible.
  final Color mid;

  /// Front layer — vivid.
  final Color front;

  /// Accent — deepest tone.
  final Color accent;

  /// Warm contrast hint (yellow/amber family).
  final Color warm;

  /// Radial glow center color.
  final Color glow;
}

const _lightColors = WaveColorSet(
  deep: AppColors.waveLightDeep,
  base: AppColors.waveLightBase,
  mid: AppColors.waveLightMid,
  front: AppColors.waveLightFront,
  accent: AppColors.waveLightAccent,
  warm: AppColors.waveLightWarm,
  glow: AppColors.waveLightGlow,
);

const _darkColors = WaveColorSet(
  deep: AppColors.waveDarkDeep,
  base: AppColors.waveDarkBase,
  mid: AppColors.waveDarkMid,
  front: AppColors.waveDarkFront,
  accent: AppColors.waveDarkAccent,
  warm: AppColors.waveDarkWarm,
  glow: AppColors.waveDarkGlow,
);
