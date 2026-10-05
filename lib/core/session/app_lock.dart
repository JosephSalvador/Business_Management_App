/// Pure, testable policy for the idle/background auto-lock (theft
/// mitigation: a POS left unlocked on the counter must not stay open).
///
/// Two triggers lock the app, both non-destructive (the session is retained
/// and re-opened by the fast factor):
///
/// 1. **Idle timeout** — no user interaction for [idleTimeout] while the app
///    is in the foreground.
/// 2. **Background grace** — the app was put in the background (paused) for
///    longer than [backgroundGrace]; on return it locks.
///
/// Cold starts are unaffected: restoring a stored session never passes
/// through this policy.
class AppLockPolicy {
  const AppLockPolicy({
    this.idleTimeout = const Duration(minutes: 5),
    this.backgroundGrace = const Duration(seconds: 45),
  });

  /// Foreground idle duration before the app locks.
  final Duration idleTimeout;

  /// How long the app may stay backgrounded before it locks on return.
  final Duration backgroundGrace;

  /// Whether resuming from [backgroundedAt] should lock the app.
  bool lockAfterBackground({
    required DateTime? backgroundedAt,
    required DateTime now,
  }) {
    if (backgroundedAt == null) return false;
    return now.difference(backgroundedAt) >= backgroundGrace;
  }

  /// Whether the app should lock after being idle since [lastInteraction].
  bool lockAfterIdle({
    required DateTime lastInteraction,
    required DateTime now,
  }) {
    return now.difference(lastInteraction) >= idleTimeout;
  }
}
