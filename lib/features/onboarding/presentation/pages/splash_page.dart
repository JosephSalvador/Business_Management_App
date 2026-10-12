import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../application/workspace_controller.dart';

/// Splash screen — shown while session/workspace resolves.
/// Features a choreographed vector animation of the Jolinx "Rising Growth J" emblem.
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
            _ => const _AnimatedSplashView(),
          },
        ),
      ),
    );
  }
}

class _AnimatedSplashView extends StatefulWidget {
  const _AnimatedSplashView();

  @override
  State<_AnimatedSplashView> createState() => _AnimatedSplashViewState();
}

class _AnimatedSplashViewState extends State<_AnimatedSplashView>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _pulseController;

  late final Animation<double> _cardScale;
  late final Animation<double> _bar1Progress;
  late final Animation<double> _bar2Progress;
  late final Animation<double> _jArrowProgress;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _cardScale = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.42, curve: Curves.easeOutBack),
    );

    _bar1Progress = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.18, 0.56, curve: Curves.easeOutCubic),
    );

    _bar2Progress = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.30, 0.68, curve: Curves.easeOutCubic),
    );

    _jArrowProgress = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.42, 0.92, curve: Curves.easeInOutCubic),
    );

    _textOpacity = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.66, 1.0, curve: Curves.easeOut),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.66, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _introController.forward();
  }

  @override
  void dispose() {
    _introController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_introController, _pulseController]),
      builder: (context, _) {
        final pulse = _pulseController.value;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: _cardScale.value,
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1A6DFF),
                      Color(0xFF0055D4),
                      Color(0xFF003B99),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary
                          .withValues(alpha: 0.28 + (pulse * 0.14)),
                      blurRadius: 24 + (pulse * 10),
                      spreadRadius: 1 + (pulse * 2),
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: AppColors.secondary.withValues(
                        alpha: 0.16 * _jArrowProgress.value,
                      ),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: CustomPaint(
                  painter: _RisingGrowthJLogoPainter(
                    bar1Progress: _bar1Progress.value,
                    bar2Progress: _bar2Progress.value,
                    jArrowProgress: _jArrowProgress.value,
                    pulse: pulse,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
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
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3.0,
                        color: AppColors.resolveTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Simamia biashara yako yote sehemu moja',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                        color: AppColors.resolveTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 120,
              height: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color.lerp(
                      AppColors.primary,
                      AppColors.secondary,
                      pulse,
                    )!,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Vector recreation of Option 2 ("Rising Growth J") with per-element progress.
class _RisingGrowthJLogoPainter extends CustomPainter {
  _RisingGrowthJLogoPainter({
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
        ..lineTo(left + (right - left) * 0.52,
            currentTop + (bottom - fullTop) * 0.36)
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
        ..color = _tealGlow.withValues(alpha: 0.25 + 0.15 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stemWidth + 5
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
            ..color = _tealGlow.withValues(alpha: 0.30 * arrowT)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
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
