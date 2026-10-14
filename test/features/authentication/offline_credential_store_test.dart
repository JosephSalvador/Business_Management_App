import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/features/authentication/data/offline_credential_store.dart';
import 'package:jolinx_app/features/authentication/domain/session.dart';

class InMemorySecureStoragePlatform extends FlutterSecureStoragePlatform {
  final Map<String, String> values = {};

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async =>
      values.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async =>
      values.remove(key);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      values.clear();

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async =>
      values[key];

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async =>
      Map.of(values);

  @override
  Future<void> write({
    required String key,
    required String? value,
    required Map<String, String> options,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

AuthUser owner() => const AuthUser(
      id: 'u1',
      tenantId: 't1',
      email: 'owner@test.local',
      fullName: 'Owner',
      phone: null,
      isActive: true,
      emailVerified: true,
      permissions: ['sale.create'],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late InMemorySecureStoragePlatform platform;

  setUp(() {
    platform = InMemorySecureStoragePlatform();
    FlutterSecureStoragePlatform.instance = platform;
  });

  OfflineCredentialStore store() =>
      OfflineCredentialStore(storage: const FlutterSecureStorage());

  group('device unlock PIN', () {
    test('hasUnlockPin reports false until a PIN is set', () async {
      final offline = store();
      expect(await offline.hasUnlockPin(), isFalse);

      await offline.setUnlockPin('1234');

      expect(await offline.hasUnlockPin(), isTrue);
    });

    test('accepts exactly 4 to 6 digits', () async {
      final offline = store();
      for (final valid in ['1234', '12345', '123456']) {
        await offline.setUnlockPin(valid);
        expect(await offline.hasUnlockPin(), isTrue,
            reason: '$valid must be accepted');
      }
    });

    test('rejects non-numeric pins', () async {
      final offline = store();
      await expectLater(
        offline.setUnlockPin('12a4'),
        throwsA(isA<ValidationException>()),
      );
      expect(await offline.hasUnlockPin(), isFalse);
    });

    test('rejects out-of-range lengths', () async {
      final offline = store();
      for (final pin in ['123', '1234567', '']) {
        await expectLater(
          offline.setUnlockPin(pin),
          throwsA(isA<ValidationException>()),
          reason: '$pin must be rejected',
        );
      }
    });

    test('verifies a matching PIN and rejects a wrong one', () async {
      final offline = store();
      await offline.setUnlockPin('4821');

      expect(await offline.verifyUnlockPin('4821'), isTrue);
      expect(await offline.verifyUnlockPin('0000'), isFalse);
      // The correct PIN still verifies afterwards (no lockout from one miss).
      expect(await offline.verifyUnlockPin('4821'), isTrue);
    });

    test('locks out after the shared failed-attempt ceiling', () async {
      final offline = store();
      await offline.setUnlockPin('4821');

      for (var i = 0; i < 5; i++) {
        expect(await offline.verifyUnlockPin('0000'), isFalse);
      }
      // Locked out — even the correct PIN is rejected until the window ends.
      expect(await offline.verifyUnlockPin('4821'), isFalse);
    });

    test('clearAll removes the PIN', () async {
      final offline = store();
      await offline.setUnlockPin('4821');
      expect(await offline.hasUnlockPin(), isTrue);

      await offline.clearAll();

      expect(await offline.hasUnlockPin(), isFalse);
    });
  });

  group('quick unlock trusted window', () {
    test('a fresh unlock token is valid and restorable', () async {
      final offline = store();
      expect(await offline.hasValidQuickUnlock(), isFalse);

      await offline.enableQuickUnlock(owner());

      expect(await offline.hasValidQuickUnlock(), isTrue);
      final session = await offline.restoreQuickUnlock();
      expect(session, isNotNull);
      expect(session!.user.email, 'owner@test.local');
    });

    test('sliding renewal overwrites the expiry on re-arm', () async {
      final offline = store();
      await offline.enableQuickUnlock(owner());
      expect(await offline.hasValidQuickUnlock(), isTrue);

      await offline.disableQuickUnlock();
      expect(await offline.hasValidQuickUnlock(), isFalse);

      await offline.enableQuickUnlock(owner());
      expect(await offline.hasValidQuickUnlock(), isTrue);
    });

    test('biometric preference is false by default and toggles correctly', () async {
      final offline = store();
      expect(await offline.isBiometricEnabled(), isFalse);

      await offline.setBiometricEnabled(true);
      expect(await offline.isBiometricEnabled(), isTrue);

      await offline.setBiometricEnabled(false);
      expect(await offline.isBiometricEnabled(), isFalse);
    });

    test('isQuickPinEnabled requires unlock PIN to be set', () async {
      final offline = store();
      expect(await offline.isQuickPinEnabled(), isFalse);

      await offline.setUnlockPin('1234');
      expect(await offline.isQuickPinEnabled(), isTrue);

      await offline.setQuickPinEnabled(false);
      expect(await offline.isQuickPinEnabled(), isFalse);

      await offline.setQuickPinEnabled(true);
      expect(await offline.isQuickPinEnabled(), isTrue);

      await offline.clearUnlockPin();
      expect(await offline.isQuickPinEnabled(), isFalse);
    });
  });
}
