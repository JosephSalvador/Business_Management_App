import 'package:flutter/material.dart';

/// Draws rich layered wave curves with gradient fills, decorative lines,
/// and floating accent dots for depth and polish.
class WavePainter extends CustomPainter {
  const WavePainter({
    required this.waves,
    this.topAccents = const [],
    this.floatingDots = const [],
    this.radialGlow,
  });

  /// Bottom wave layers, ordered from back (index 0) to front.
  final List<WaveData> waves;

  /// Optional top-corner accent waves.
  final List<TopAccentData> topAccents;

  /// Small floating decorative dots scattered in the wave area.
  final List<FloatingDot> floatingDots;

  /// Optional radial glow centered near the top.
  final RadialGlowData? radialGlow;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Radial glow (behind everything)
    if (radialGlow != null) {
      _drawRadialGlow(canvas, size, radialGlow!);
    }

    // 2. Bottom waves
    for (final wave in waves) {
      _drawWave(canvas, size, wave);
    }

    // 3. Decorative lines tracing wave edges
    for (final wave in waves) {
      if (wave.showLine) {
        _drawWaveLine(canvas, size, wave);
      }
    }

    // 4. Top corner accents
    for (final accent in topAccents) {
      _drawTopAccent(canvas, size, accent);
    }

    // 5. Floating dots
    for (final dot in floatingDots) {
      _drawFloatingDot(canvas, size, dot);
    }
  }

  // ── Radial glow ───────────────────────────────────────────────
  void _drawRadialGlow(Canvas canvas, Size size, RadialGlowData glow) {
    final center = Offset(
      size.width * glow.position.dx,
      size.height * glow.position.dy,
    );
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          glow.color.withValues(alpha: glow.intensity),
          glow.color.withValues(alpha: 0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(
        Rect.fromCircle(center: center, radius: glow.radius),
      );
    canvas.drawCircle(center, glow.radius, paint);
  }

  // ── Wave fill ─────────────────────────────────────────────────
  void _drawWave(Canvas canvas, Size size, WaveData wave) {
    final path = _buildWavePath(size, wave);

    // Gradient fill following wave curvature
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          wave.color.withValues(alpha: 0),
          wave.color.withValues(alpha: wave.opacity * 0.5),
          wave.color.withValues(alpha: wave.opacity),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(path.getBounds());

    canvas.drawPath(path, gradientPaint);
  }

  // ── Decorative line ───────────────────────────────────────────
  void _drawWaveLine(Canvas canvas, Size size, WaveData wave) {
    final path = _buildWavePath(size, wave);
    final paint = Paint()
      ..color = wave.lineColor.withValues(alpha: wave.lineOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = wave.lineWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
  }

  // ── Wave path builder ─────────────────────────────────────────
  Path _buildWavePath(Size size, WaveData wave) {
    final path = Path();
    final waveHeight = size.height * wave.heightRatio;
    final baseY = size.height - waveHeight;
    final amp = wave.amplitude;
    final w = size.width;

    // Start at bottom-left
    path.moveTo(0, size.height);

    // Rise to first valley
    path.cubicTo(
      0,
      baseY + amp * 0.2,
      w * 0.08,
      baseY + amp * 0.6,
      w * 0.15,
      baseY + amp * 0.3,
    );

    // First peak
    path.cubicTo(
      w * 0.22,
      baseY - amp * 0.1,
      w * 0.28,
      baseY - amp * 0.9,
      w * 0.38,
      baseY - amp * 0.4,
    );

    // Second valley
    path.cubicTo(
      w * 0.45,
      baseY + amp * 0.1,
      w * 0.50,
      baseY + amp * 0.5,
      w * 0.55,
      baseY + amp * 0.2,
    );

    // Second peak
    path.cubicTo(
      w * 0.62,
      baseY - amp * 0.6,
      w * 0.72,
      baseY - amp * 0.8,
      w * 0.80,
      baseY - amp * 0.3,
    );

    // Final descent
    path.cubicTo(
      w * 0.88,
      baseY + amp * 0.2,
      w * 0.95,
      baseY + amp * 0.5,
      w,
      baseY + amp * 0.15,
    );

    // Close along bottom
    path.lineTo(w, size.height);
    path.close();

    return path;
  }

  // ── Top corner accent ─────────────────────────────────────────
  void _drawTopAccent(Canvas canvas, Size size, TopAccentData accent) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    if (accent.side == AccentSide.left) {
      path.moveTo(0, 0);
      path.cubicTo(
        w * 0.05,
        h * accent.heightRatio,
        w * accent.widthRatio,
        h * 0.02,
        w * accent.widthRatio * 0.8,
        0,
      );
    } else {
      path.moveTo(w, 0);
      path.cubicTo(
        w * (1 - 0.05),
        h * accent.heightRatio,
        w * (1 - accent.widthRatio),
        h * 0.02,
        w * (1 - accent.widthRatio * 0.8),
        0,
      );
    }

    path.close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: accent.side == AccentSide.left
            ? Alignment.topLeft
            : Alignment.topRight,
        end: accent.side == AccentSide.left
            ? Alignment.bottomRight
            : Alignment.bottomLeft,
        colors: [
          accent.color.withValues(alpha: accent.opacity),
          accent.color.withValues(alpha: 0),
        ],
      ).createShader(path.getBounds());

    canvas.drawPath(path, paint);
  }

  // ── Floating dot ──────────────────────────────────────────────
  void _drawFloatingDot(Canvas canvas, Size size, FloatingDot dot) {
    final center = Offset(
      size.width * dot.position.dx,
      size.height * dot.position.dy,
    );
    final paint = Paint()
      ..color = dot.color.withValues(alpha: dot.opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, dot.radius, paint);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) {
    return oldDelegate.waves != waves ||
        oldDelegate.topAccents != topAccents ||
        oldDelegate.floatingDots != floatingDots ||
        oldDelegate.radialGlow != radialGlow;
  }
}

// ── Data classes ─────────────────────────────────────────────────

/// Defines a single bottom wave layer.
class WaveData {
  const WaveData({
    required this.color,
    required this.opacity,
    required this.heightRatio,
    required this.amplitude,
    this.showLine = false,
    this.lineColor = Colors.white,
    this.lineOpacity = 0.15,
    this.lineWidth = 1.0,
  });

  final Color color;
  final double opacity;
  final double heightRatio;
  final double amplitude;
  final bool showLine;
  final Color lineColor;
  final double lineOpacity;
  final double lineWidth;
}

/// Defines a top-corner accent wave.
class TopAccentData {
  const TopAccentData({
    required this.color,
    required this.opacity,
    required this.heightRatio,
    required this.widthRatio,
    required this.side,
  });

  final Color color;
  final double opacity;
  final double heightRatio;
  final double widthRatio;
  final AccentSide side;
}

enum AccentSide { left, right }

/// A small decorative floating dot.
class FloatingDot {
  const FloatingDot({
    required this.position,
    required this.color,
    required this.opacity,
    required this.radius,
  });

  /// Normalized position (0.0–1.0) relative to canvas size.
  final Offset position;
  final Color color;
  final double opacity;
  final double radius;
}

/// Radial glow data for atmospheric center lighting.
class RadialGlowData {
  const RadialGlowData({
    required this.position,
    required this.color,
    required this.radius,
    required this.intensity,
  });

  final Offset position;
  final Color color;
  final double radius;
  final double intensity;
}
