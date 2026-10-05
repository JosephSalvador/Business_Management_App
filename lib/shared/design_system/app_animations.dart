import 'package:flutter/material.dart';

/// Subtle, professional animation utilities.
///
/// Design principles:
/// - Fast (200-300ms) — never slow down the user
/// - Subtle — fades and slight movement, not flashy
/// - Accessible — respect `MediaQuery.disableAnimations`
class AppAnimations {
  AppAnimations._();

  // ── Durations ───────────────────────────────────────────────────
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);

  // ── Curves ──────────────────────────────────────────────────────
  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve enterCurve = Curves.easeOut;
  static const Curve exitCurve = Curves.easeIn;
  static const Curve springCurve = Curves.easeOutBack;

  // ── Fade Transitions ────────────────────────────────────────────
  static Widget fadeIn({
    required Widget child,
    Duration duration = const Duration(milliseconds: 250),
    double begin = 0.0,
    double end = 1.0,
  }) {
    return TweenAnimationWidget<double>(
      tween: Tween(begin: begin, end: end),
      duration: duration,
      curve: enterCurve,
      builder: (_, value, __) => Opacity(opacity: value, child: child),
    );
  }

  // ── Slide Transitions ───────────────────────────────────────────
  static Widget slideUp({
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
    double offset = 20,
  }) {
    return TweenAnimationWidget<Offset>(
      tween: Tween(begin: Offset(0, offset / 100), end: Offset.zero),
      duration: duration,
      curve: enterCurve,
      builder: (_, value, __) => FractionalTranslation(
        translation: value,
        child: Opacity(
          opacity: 1.0 - value.dy.abs().clamp(0.0, 1.0),
          child: child,
        ),
      ),
    );
  }

  static Widget slideInFromRight({
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
    double offset = 30,
  }) {
    return TweenAnimationWidget<Offset>(
      tween: Tween(begin: Offset(offset / 100, 0), end: Offset.zero),
      duration: duration,
      curve: enterCurve,
      builder: (_, value, __) => FractionalTranslation(
        translation: value,
        child: Opacity(
          opacity: 1.0 - value.dx.abs().clamp(0.0, 1.0),
          child: child,
        ),
      ),
    );
  }

  // ── Scale Transition ────────────────────────────────────────────
  static Widget scaleIn({
    required Widget child,
    Duration duration = const Duration(milliseconds: 250),
    double begin = 0.92,
    double end = 1.0,
  }) {
    return TweenAnimationWidget<double>(
      tween: Tween(begin: begin, end: end),
      duration: duration,
      curve: springCurve,
      builder: (_, value, child) => Transform.scale(
        scale: value,
        child: child,
      ),
      child: child,
    );
  }

  // ── Staggered List ──────────────────────────────────────────────
  /// Returns a list of widgets with staggered fade-in + slide-up animations.
  static List<Widget> staggeredList({
    required List<Widget> children,
    Duration duration = const Duration(milliseconds: 250),
    Duration stagger = const Duration(milliseconds: 50),
  }) {
    return List.generate(children.length, (index) {
      return TweenAnimationWidget<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: duration + (stagger * index),
        curve: enterCurve,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 12 * (1 - value)),
              child: child,
            ),
          );
        },
        child: children[index],
      );
    });
  }

  // ── Number Counter ──────────────────────────────────────────────
  static Widget countUp({
    required double value,
    required Widget Function(String) builder,
    Duration duration = const Duration(milliseconds: 600),
  }) {
    return TweenAnimationWidget<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, animatedValue, __) =>
          builder(animatedValue.toStringAsFixed(0)),
    );
  }
}

/// Internal generic tween animation widget.
class TweenAnimationWidget<T> extends StatefulWidget {
  const TweenAnimationWidget({
    required this.tween,
    required this.duration,
    required this.builder,
    this.curve = Curves.easeInOut,
    this.onEnd,
    this.child,
    super.key,
  });

  final Tween<T> tween;
  final Duration duration;
  final Widget Function(BuildContext, T, Widget?) builder;
  final Curve curve;
  final VoidCallback? onEnd;
  final Widget? child;

  @override
  State<TweenAnimationWidget<T>> createState() =>
      _TweenAnimationWidgetState<T>();
}

class _TweenAnimationWidgetState<T> extends State<TweenAnimationWidget<T>> {
  @override
  Widget build(BuildContext context) {
    // Respect accessibility: skip animation if disabled.
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced) {
      return widget.builder(context, widget.tween.end as T, widget.child);
    }

    return TweenAnimationBuilder<T>(
      tween: widget.tween,
      duration: widget.duration,
      curve: widget.curve,
      onEnd: widget.onEnd,
      builder: widget.builder,
      child: widget.child,
    );
  }
}

/// Animated page transition forPageRoute.
PageRouteBuilder<void> slideUpPageRoute(Widget child) {
  return PageRouteBuilder(
    transitionDuration: AppAnimations.normal,
    reverseTransitionDuration: AppAnimations.fast,
    pageBuilder: (_, __, ___) => child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppAnimations.enterCurve,
        reverseCurve: AppAnimations.exitCurve,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
