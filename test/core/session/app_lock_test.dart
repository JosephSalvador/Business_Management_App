import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/session/app_lock.dart';

void main() {
  group('AppLockPolicy', () {
    test('idle locks only after the timeout has fully elapsed', () {
      const policy = AppLockPolicy(idleTimeout: Duration(minutes: 5));
      final interaction = DateTime.utc(2026, 9, 22, 8, 0);

      expect(
        policy.lockAfterIdle(
          lastInteraction: interaction,
          now: interaction.add(const Duration(minutes: 4, seconds: 59)),
        ),
        isFalse,
      );
      expect(
        policy.lockAfterIdle(
          lastInteraction: interaction,
          now: interaction.add(const Duration(minutes: 5)),
        ),
        isTrue,
      );
    });

    test('background grace: short absences do not lock, long ones do', () {
      const policy = AppLockPolicy(backgroundGrace: Duration(seconds: 45));
      final backgroundedAt = DateTime.utc(2026, 9, 22, 8, 0);

      expect(
        policy.lockAfterBackground(
          backgroundedAt: backgroundedAt,
          now: backgroundedAt.add(const Duration(seconds: 44)),
        ),
        isFalse,
      );
      expect(
        policy.lockAfterBackground(
          backgroundedAt: backgroundedAt,
          now: backgroundedAt.add(const Duration(seconds: 45)),
        ),
        isTrue,
      );
    });

    test('a never-backgrounded app is never locked on resume', () {
      const policy = AppLockPolicy();
      expect(
        policy.lockAfterBackground(
          backgroundedAt: null,
          now: DateTime.utc(2026, 9, 22, 9, 0),
        ),
        isFalse,
      );
    });
  });
}
