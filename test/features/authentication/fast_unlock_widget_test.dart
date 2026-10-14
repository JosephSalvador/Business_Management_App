import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/config/app_config.dart';
import 'package:jolinx_app/app/providers.dart';
import 'package:jolinx_app/core/network/api_client.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/features/authentication/application/auth_controller.dart';
import 'package:jolinx_app/features/authentication/data/auth_repository.dart';
import 'package:jolinx_app/features/authentication/data/biometric_auth_gate.dart';
import 'package:jolinx_app/features/authentication/data/offline_credential_store.dart';
import 'package:jolinx_app/features/authentication/domain/session.dart';
import 'package:jolinx_app/features/authentication/presentation/pages/lock_page.dart';
import 'package:jolinx_app/features/authentication/presentation/pages/login_page.dart';
import 'package:jolinx_app/features/authentication/presentation/widgets/pin_pad.dart';

final _session = Session(
  user: AuthUser(
    id: 'u1',
    tenantId: 't1',
    email: 'owner@test.local',
    fullName: 'Mama Duka',
    phone: null,
    isActive: true,
    emailVerified: true,
    permissions: const ['ANALYST_VIEW', 'SALES_CREATE'],
  ),
  accessTokenExpiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
);

/// In-memory [OfflineCredentialStore] controlling the trusted-device state.
class FakeOfflineCredentialStore implements OfflineCredentialStore {
  FakeOfflineCredentialStore({
    this.trusted = false,
    this.hasPin = false,
    this.biometricAvailable = false,
    this.verifyPin = false,
    this.fullName = 'Mama Duka',
    this.pin = '',
  });

  bool trusted;
  bool hasPin;
  bool biometricAvailable;
  bool verifyPin;
  String fullName;
  String pin;
  String? lastPin;
  bool quickUnlockRenewed = false;

  @override
  Future<bool> hasValidQuickUnlock() async => trusted;

  @override
  Future<bool> isOfflineAuthAvailable() async => trusted;

  @override
  Future<bool> hasUnlockPin() async => hasPin;

  @override
  Future<bool> isBiometricEnabled() async => biometricAvailable;

  @override
  Future<void> setBiometricEnabled(bool enabled) async {
    biometricAvailable = enabled;
  }

  @override
  Future<bool> isQuickPinEnabled() async => hasPin;

  @override
  Future<void> setQuickPinEnabled(bool enabled) async {
    hasPin = enabled;
  }

  @override
  Future<void> setUnlockPin(String value) async {
    pin = value;
    hasPin = true;
  }

  @override
  Future<bool> verifyUnlockPin(String value) async {
    lastPin = value;
    return verifyPin;
  }

  @override
  Future<String?> getCachedFullName() async => fullName;

  @override
  Future<void> enableQuickUnlock(dynamic user) async {
    quickUnlockRenewed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopTokenStore implements TokenStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> readAccessToken() async => null;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}
}

/// In-memory repository with scriptable fast-unlock outcomes.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({FakeOfflineCredentialStore? store})
      : store = store ?? FakeOfflineCredentialStore();

  final FakeOfflineCredentialStore store;

  final ApiClient _clientShell = ApiClient(
    config: AppConfig.forTest(
      apiBaseUrl: Uri.parse('https://api.test.local'),
      environment: AppEnvironment.dev,
    ),
    tokenStore: _NoopTokenStore(),
    refresher: (_) => throw UnimplementedError(),
  );

  int biometricCalls = 0;
  Session? biometricResult;
  Object? biometricError;

  int pinUnlockCalls = 0;
  Session? pinUnlockResult;
  Object? pinUnlockError;

  int offlineLoginCalls = 0;
  Session? offlineLoginResult;

  @override
  ApiClient get apiClient => _clientShell;

  @override
  OfflineCredentialStore get offlineCredentialStore => store;

  @override
  Future<Session?> restore() async => null;

  @override
  Future<Session?> loginOffline({
    required String password,
    BiometricAuthGate? biometricGate,
  }) async {
    offlineLoginCalls++;
    return offlineLoginResult;
  }

  @override
  Future<Session?> loginWithBiometric({
    required BiometricAuthGate biometricGate,
  }) async {
    biometricCalls++;
    final error = biometricError;
    if (error != null) throw error;
    return biometricResult;
  }

  @override
  Future<Session?> unlockWithPin({required String pin}) async {
    pinUnlockCalls++;
    final error = pinUnlockError;
    if (error != null) throw error;
    await store.verifyUnlockPin(pin);
    return pinUnlockResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBiometricGate extends BiometricAuthGate {
  _FakeBiometricGate({this.available = false});

  final bool available;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate({required String reason}) async => true;
}

({
  ProviderContainer container,
  FakeAuthRepository repository,
  _FakeBiometricGate gate
}) _overrides({
  required FakeAuthRepository repository,
  required FakeOfflineCredentialStore store,
  required _FakeBiometricGate gate,
}) {
  final container = ProviderContainer(overrides: [
    authRepositoryProvider.overrideWithValue(repository),
    offlineCredentialStoreProvider.overrideWithValue(store),
    biometricAuthGateProvider.overrideWithValue(gate),
  ]);
  addTearDown(container.dispose);
  return (container: container, repository: repository, gate: gate);
}

Future<FakeAuthRepository> _pumpLogin(
  WidgetTester tester, {
  required bool trusted,
  required bool hasPin,
  required bool biometric,
  bool verifyPin = false,
  Object? pinError,
  Session? biometricResult,
}) async {
  final store = FakeOfflineCredentialStore(
    trusted: trusted,
    hasPin: hasPin,
    biometricAvailable: biometric,
    verifyPin: verifyPin,
  );
  final repository = FakeAuthRepository(store: store)
    ..pinUnlockResult = _session
    ..pinUnlockError = pinError
    ..biometricResult = biometricResult;
  final gate = _FakeBiometricGate(available: biometric);
  final overrides = _overrides(
    repository: repository,
    store: store,
    gate: gate,
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: overrides.container,
      child: const MaterialApp(home: LoginPage()),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  group('LoginPage fast unlock (trusted device)', () {
    testWidgets('shows PinPad and switches to standard form with Ingia kwa nenosiri',
        (tester) async {
      await _pumpLogin(
        tester,
        trusted: true,
        hasPin: true,
        biometric: false,
      );

      expect(find.text('Habari, Mama!'), findsOneWidget);
      expect(find.byType(PinPad), findsOneWidget);
      expect(find.text('Ingia kwa nenosiri'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);

      await tester.tap(find.text('Ingia kwa nenosiri'));
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Tumia Kidole au PIN'), findsOneWidget);
    });

    testWidgets('biometric-enabled trusted device auto-prompts biometric',
        (tester) async {
      final repository = await _pumpLogin(
        tester,
        trusted: true,
        hasPin: true,
        biometric: true,
        biometricResult: _session,
      );

      // Auto-prompt post frame callback fires:
      expect(repository.biometricCalls, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('valid PIN submit auto-submits on 4th digit', (tester) async {
      final repository = await _pumpLogin(
        tester,
        trusted: true,
        hasPin: true,
        biometric: false,
      );

      for (final digit in ['1', '2', '3', '4']) {
        await tester.tap(find.descendant(
          of: find.byType(PinPad),
          matching: find.text(digit),
        ));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(repository.store.lastPin, '1234');
      expect(repository.pinUnlockCalls, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rejected PIN surfaces the error inline on the panel',
        (tester) async {
      await _pumpLogin(
        tester,
        trusted: true,
        hasPin: true,
        biometric: false,
        pinError: ValidationException('PIN si sahihi. Jaribu tena.'),
      );

      for (final digit in ['1', '2', '3', '4']) {
        await tester.tap(find.descendant(
          of: find.byType(PinPad),
          matching: find.text(digit),
        ));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.text('PIN si sahihi. Jaribu tena.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('LoginPage account form (untrusted device)', () {
    testWidgets('shows the classic form without any fast-factor controls',
        (tester) async {
      await _pumpLogin(
        tester,
        trusted: false,
        hasPin: false,
        biometric: false,
      );

      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.byType(PinPad), findsNothing);
      expect(find.byIcon(Icons.fingerprint), findsNothing);
      expect(find.text('Tumia Kidole au PIN'), findsNothing);
    });
  });

  group('LockPage inline fast unlock', () {
    testWidgets('shows the PIN pad and wrong-pin error while locked',
        (tester) async {
      final store = FakeOfflineCredentialStore(
        trusted: true,
        hasPin: true,
        biometricAvailable: false,
        verifyPin: false,
      );
      final repository = FakeAuthRepository(store: store)
        ..offlineLoginResult = _session;
      final gate = _FakeBiometricGate(available: false);

      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        offlineCredentialStoreProvider.overrideWithValue(store),
        biometricAuthGateProvider.overrideWithValue(gate),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: LockPage()),
        ),
      );
      await tester.pumpAndSettle();

      final notifier = container.read(authControllerProvider.notifier);
      await tester.pump();
      await notifier.loginOffline(password: 'x');
      notifier.lock();
      await tester.pumpAndSettle();

      expect(find.byType(PinPad), findsOneWidget);
      expect(find.text('Ingia kwa nenosiri'), findsOneWidget);

      for (final digit in ['1', '2', '3', '4']) {
        await tester.tap(find.descendant(
          of: find.byType(PinPad),
          matching: find.text(digit),
        ));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(store.lastPin, '1234');
      expect(find.text('PIN si sahihi. Jaribu tena.'), findsOneWidget);
      expect(container.read(authControllerProvider), isA<AuthLocked>());
      expect(tester.takeException(), isNull);
    });

    testWidgets('correct PIN unlocks the locked session on 4th digit',
        (tester) async {
      final store = FakeOfflineCredentialStore(
        trusted: true,
        hasPin: true,
        biometricAvailable: false,
        verifyPin: true,
      );
      final repository = FakeAuthRepository(store: store)
        ..offlineLoginResult = _session;
      final gate = _FakeBiometricGate(available: false);

      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        offlineCredentialStoreProvider.overrideWithValue(store),
        biometricAuthGateProvider.overrideWithValue(gate),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: LockPage()),
        ),
      );
      await tester.pumpAndSettle();

      final notifier = container.read(authControllerProvider.notifier);
      await tester.pump();
      await notifier.loginOffline(password: 'x');
      notifier.lock();
      await tester.pumpAndSettle();

      for (final digit in ['1', '2', '3', '4']) {
        await tester.tap(find.descendant(
          of: find.byType(PinPad),
          matching: find.text(digit),
        ));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
      expect(find.text('PIN si sahihi. Jaribu tena.'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
