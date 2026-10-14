import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../application/workspace_controller.dart';
import '../../data/workspace_providers.dart';

/// Splash screen — shown while session/workspace resolves.
///
/// Features a tier-1 multimedia design:
/// - Breathing radial background aura
/// - Specular glass light sweep over the brand badge
/// - Kinetic vector choreography (3-stage rising growth J with neon-emerald glow)
/// - Modern typography with kinetic kerning expansion
/// - Zero boring linear spinners
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceControllerProvider);

    return Scaffold(
      body: WaveBackground(
        child: Center(
          child: switch (workspace) {
            WorkspaceFailure(:final message) => _FailureView(
                message: message,
                onRetry: () =>
                    ref.read(workspaceControllerProvider.notifier).load(),
              ),
            _ => const _ProSplashHero(),
          },
        ),
      ),
    );
  }
}

class _ProSplashHero extends StatefulWidget {
  const _ProSplashHero();

  @override
  State<_ProSplashHero> createState() => _ProSplashHeroState();
}

class _ProSplashHeroState extends State<_ProSplashHero>
    with TickerProviderStateMixin {
  late final AnimationController _choreographyController;
  late final AnimationController _ambientGlowController;
  late final AnimationController _shimmerController;

  late final Animation<double> _badgeScale;
  late final Animation<double> _bar1Progress;
  late final Animation<double> _bar2Progress;
  late final Animation<double> _jArrowProgress;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _letterSpacing;

  @override
  void initState() {
    super.initState();

    // 1. Choreographed entry (1200ms)
    _choreographyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    );

    // 2. Continuous ambient specular breathing glow
    _ambientGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    // 3. Specular glass diagonal light sweep
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    // Elastic spring entrance for emblem badge
    _badgeScale = CurvedAnimation(
      parent: _choreographyController,
      curve: const Interval(0.0, 0.40, curve: Curves.easeOutBack),
    );

    // Bar 1 rising curve
    _bar1Progress = CurvedAnimation(
      parent: _choreographyController,
      curve: const Interval(0.15, 0.52, curve: Curves.easeOutCubic),
    );

    // Bar 2 rising curve
    _bar2Progress = CurvedAnimation(
      parent: _choreographyController,
      curve: const Interval(0.28, 0.65, curve: Curves.easeOutCubic),
    );

    // Sweeping J arrow path drawing
    _jArrowProgress = CurvedAnimation(
      parent: _choreographyController,
      curve: const Interval(0.40, 0.88, curve: Curves.easeInOutCubic),
    );

    // Typography fade & slide
    _textOpacity = CurvedAnimation(
      parent: _choreographyController,
      curve: const Interval(0.60, 1.0, curve: Curves.easeOut),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.20),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _choreographyController,
        curve: const Interval(0.60, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _letterSpacing = Tween<double>(begin: 1.5, end: 3.5).animate(
      CurvedAnimation(
        parent: _choreographyController,
        curve: const Interval(0.60, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _choreographyController.forward();
  }

  @override
  void dispose() {
    _choreographyController.dispose();
    _ambientGlowController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _choreographyController,
        _ambientGlowController,
        _shimmerController,
      ]),
      builder: (context, _) {
        final glowPulse = _ambientGlowController.value;
        final shimmerValue = _shimmerController.value;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Emblem Badge with ambient aura and glass specular sweep
            Stack(
              alignment: Alignment.center,
              children: [
                // 1. Ambient Breathing Radial Aura behind emblem
                Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withValues(
                          alpha: 0.35 + (glowPulse * 0.25),
                        ),
                        const Color(0xFF00C99B).withValues(
                          alpha: 0.15 + (glowPulse * 0.15),
                        ),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),

                // 2. Emblem Badging Container
                Transform.scale(
                  scale: _badgeScale.value,
                  child: Container(
                    width: 114,
                    height: 114,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF2272FF),
                          Color(0xFF0052CC),
                          Color(0xFF003080),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary
                              .withValues(alpha: 0.38 + (glowPulse * 0.16)),
                          blurRadius: 30 + (glowPulse * 12),
                          spreadRadius: 2,
                          offset: const Offset(0, 12),
                        ),
                        BoxShadow(
                          color: const Color(0xFF38F9D4).withValues(
                            alpha: 0.22 * _jArrowProgress.value,
                          ),
                          blurRadius: 22,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        // Specular Light Sweep diagonal shimmer
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _SpecularSweepPainter(
                              progress: shimmerValue,
                            ),
                          ),
                        ),

                        // Vector kinetic artwork
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _RisingGrowthJLogoPainter(
                              bar1Progress: _bar1Progress.value,
                              bar2Progress: _bar2Progress.value,
                              jArrowProgress: _jArrowProgress.value,
                              pulse: glowPulse,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Kinetic Wordmark & Slogan
            FadeTransition(
              opacity: _textOpacity,
              child: SlideTransition(
                position: _textSlide,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'JOLINX',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        letterSpacing: _letterSpacing.value,
                        color: AppColors.resolveTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Simamia biashara yako yote sehemu moja',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                        color: AppColors.resolveTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Renders a diagonal specular light shimmer across the badge surface.
class _SpecularSweepPainter extends CustomPainter {
  const _SpecularSweepPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Sweeps from left (-w) to right (2*w)
    final sweepX = -w + (3 * w * progress);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.15),
          Colors.white.withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0.15),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.4, 0.5, 0.6, 1.0],
      ).createShader(Rect.fromLTWH(sweepX - 40, 0, 80, h));

    final rect = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _SpecularSweepPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Vector choreography of Option 2 ("Rising Growth J") with neon-emerald glow.
class _RisingGrowthJLogoPainter extends CustomPainter {
  const _RisingGrowthJLogoPainter({
    required this.bar1Progress,
    required this.bar2Progress,
    required this.jArrowProgress,
    required this.pulse,
  });

  final double bar1Progress;
  final double bar2Progress;
  final double jArrowProgress;
  final double pulse;

  static const Color _teal = Color(0xFF00C99B);
  static const Color _tealGlow = Color(0xFF38F9D4);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final tealPaint = Paint()
      ..color = _teal
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // ── 1. Left Short Bar (x: 0.28..0.40, y: 0.45..0.60) ──────────────
    if (bar1Progress > 0) {
      final left = w * 0.28;
      final right = w * 0.395;
      final bottom = h * 0.595;
      final fullTop = h * 0.455;
      final currentTop = bottom - (bottom - fullTop) * bar1Progress;

      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(left, currentTop, right, bottom),
        const Radius.circular(2.5),
      );

      canvas.save();
      canvas.clipRRect(barRect);
      canvas.drawRect(barRect.outerRect, tealPaint);

      // Left white facet with diagonal bevel at top-right
      final whiteFacet = Path()
        ..moveTo(left, currentTop)
        ..lineTo(right - (right - left) * 0.15, currentTop)
        ..lineTo(
          left + (right - left) * 0.52,
          currentTop + (bottom - fullTop) * 0.36,
        )
        ..lineTo(left + (right - left) * 0.52, bottom)
        ..lineTo(left, bottom)
        ..close();
      canvas.drawPath(whiteFacet, whitePaint);
      canvas.restore();
    }

    // ── 2. Middle Medium Bar (x: 0.435..0.55, y: 0.355..0.675) ────────
    if (bar2Progress > 0) {
      final left = w * 0.435;
      final right = w * 0.548;
      final bottom = h * 0.675;
      final fullTop = h * 0.355;
      final currentTop = bottom - (bottom - fullTop) * bar2Progress;
      final radius = (right - left) * 0.48;

      final barRRect = RRect.fromRectAndCorners(
        Rect.fromLTRB(left, currentTop, right, bottom),
        topLeft: const Radius.circular(2.5),
        topRight: const Radius.circular(2.5),
        bottomLeft: Radius.circular(radius),
        bottomRight: Radius.circular(radius),
      );

      canvas.save();
      canvas.clipRRect(barRRect);
      canvas.drawRect(barRRect.outerRect, tealPaint);

      final midX = left + (right - left) * 0.50;
      final whiteFacet = Path()
        ..moveTo(left, currentTop)
        ..lineTo(right - (right - left) * 0.12, currentTop)
        ..lineTo(midX, currentTop + (right - left) * 0.65)
        ..lineTo(midX, bottom)
        ..lineTo(left, bottom)
        ..close();
      canvas.drawPath(whiteFacet, whitePaint);
      canvas.restore();
    }

    // ── 3. Sweeping "J" Curve + Tall Ascending Arrow ──────────────────
    if (jArrowProgress > 0) {
      final jCenter = Offset(w * 0.485, h * 0.635);
      final outerR = w * 0.195;
      final innerR = w * 0.088;
      final stemMidX = jCenter.dx + (outerR + innerR) / 2;
      final stemWidth = outerR - innerR;

      // Full centerline path from left tail -> bottom U-curve -> up to arrow base
      final centerline = Path()
        ..moveTo(jCenter.dx - (outerR + innerR) / 2, jCenter.dy - h * 0.01)
        ..arcTo(
          Rect.fromCircle(
            center: jCenter,
            radius: (outerR + innerR) / 2,
          ),
          math.pi,
          -math.pi,
          false,
        )
        ..lineTo(stemMidX, h * 0.30);

      final metrics = centerline.computeMetrics().first;
      final drawLen = metrics.length * (jArrowProgress.clamp(0.0, 0.85) / 0.85);
      final extracted = metrics.extractPath(0, drawLen);

      // Subtle outer emerald glow on the J stroke
      final glowStroke = Paint()
        ..color = _tealGlow.withValues(alpha: 0.28 + 0.18 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stemWidth + 6
        ..strokeCap = StrokeCap.butt
        ..isAntiAlias = true;
      canvas.drawPath(extracted, glowStroke);

      // Main teal body of the J
      final tealStroke = Paint()
        ..color = _teal
        ..style = PaintingStyle.stroke
        ..strokeWidth = stemWidth
        ..strokeCap = StrokeCap.butt
        ..isAntiAlias = true;
      canvas.drawPath(extracted, tealStroke);

      // Inner white highlight ribbon along the inner side of the J curve + left half of stem
      final innerHighlightPath = Path()
        ..moveTo(jCenter.dx - innerR - stemWidth * 0.24, jCenter.dy - h * 0.01)
        ..arcTo(
          Rect.fromCircle(
            center: jCenter,
            radius: innerR + stemWidth * 0.24,
          ),
          math.pi,
          -math.pi,
          false,
        )
        ..lineTo(stemMidX - stemWidth * 0.24, h * 0.30);

      final highlightMetrics = innerHighlightPath.computeMetrics().first;
      final highlightLen =
          highlightMetrics.length * (jArrowProgress.clamp(0.0, 0.85) / 0.85);
      final highlightExtracted = highlightMetrics.extractPath(0, highlightLen);

      final whiteStroke = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = stemWidth * 0.46
        ..strokeCap = StrokeCap.butt
        ..isAntiAlias = true;
      canvas.drawPath(highlightExtracted, whiteStroke);

      // ── Arrowhead at top of the J stem (appears in final 35% of jArrowProgress)
      if (jArrowProgress > 0.65) {
        final arrowT = ((jArrowProgress - 0.65) / 0.35).clamp(0.0, 1.0);
        final easeArrow = Curves.easeOutBack.transform(arrowT);

        final tipY = h * 0.175;
        final baseY = h * 0.315;
        final halfWing = (w * 0.105) * easeArrow;

        canvas.save();
        final tip = Offset(stemMidX, baseY - (baseY - tipY) * easeArrow);
        final leftWing = Offset(stemMidX - halfWing, baseY);
        final rightWing = Offset(stemMidX + halfWing, baseY);

        final fullArrow = Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(rightWing.dx, rightWing.dy)
          ..lineTo(leftWing.dx, leftWing.dy)
          ..close();

        // Glow behind arrow tip
        canvas.drawPath(
          fullArrow,
          Paint()
            ..color = _tealGlow.withValues(alpha: 0.35 * arrowT)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );

        canvas.drawPath(fullArrow, tealPaint);

        final leftArrowHalf = Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(stemMidX, baseY)
          ..lineTo(leftWing.dx, leftWing.dy)
          ..close();
        canvas.drawPath(leftArrowHalf, whitePaint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RisingGrowthJLogoPainter oldDelegate) {
    return oldDelegate.bar1Progress != bar1Progress ||
        oldDelegate.bar2Progress != bar2Progress ||
        oldDelegate.jArrowProgress != jArrowProgress ||
        oldDelegate.pulse != pulse;
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.errorContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 36,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Hitilafu ya Mtandao',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.resolveTextPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.resolveTextSecondary(context),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Jaribu tena'),
          ),
        ],
      ),
    );
  }
}
