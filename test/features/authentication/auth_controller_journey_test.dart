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

/// Deterministic in-memory [AuthRepository] recording calls and scripted
/// outcomes — no network, no secure storage.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository();

  /// Real client shell so [AuthController] can wire its expiry callback;
  /// every repository method is overridden below and never touches it.
  final ApiClient _clientShell = ApiClient(
    config: AppConfig.forTest(
      apiBaseUrl: Uri.parse('https://api.test.local'),
      environment: AppEnvironment.dev,
    ),
    tokenStore: _UnusedTokenStore(),
    refresher: (_) => throw UnimplementedError(),
  );

  @override
  ApiClient get apiClient => _clientShell;

  /// Persistent fake store shared across calls (the real one is too).
  final offlineStore = _FakeOfflineCredentialStore();

  @override
  OfflineCredentialStore get offlineCredentialStore => offlineStore;

  int registerCalls = 0;
  int verifyCalls = 0;
  int resendCalls = 0;
  int registerStaffCalls = 0;
  String? lastInvitationCode;
  String? lastVerifyCode;
  String? registeredEmail;

  Object? verifyError;

  Object? loginError;
  String? loginIdentifier;

  /// When set, [login] returns this instead of throwing, so the two-factor
  /// branch of the flow can be driven.
  LoginOutcome? loginOutcome;

  int twoFactorCalls = 0;
  String? lastTwoFactorCode;
  bool lastTwoFactorUsedRecoveryCode = false;
  Session? twoFactorResult;
  Object? twoFactorError;

  int biometricLoginCalls = 0;
  Session? biometricResult;
  Object? biometricError;
  bool throwOnBiometric = false;

  int offlineLoginCalls = 0;
  Session? loginOfflineResult;
  Object? loginOfflineError;

  int pinUnlockCalls = 0;
  Session? unlockWithPinResult;
  Object? unlockWithPinError;

  int pinSetupCalls = 0;
  Session? setupPinResult;
  Object? setupPinError;

  @override
  Future<Session?> restore() async => null;

  @override
  Future<void> logout() async {}

  @override
  Future<TokenPair> refresh(String refreshToken) async => TokenPair(
        accessToken: '',
        refreshToken: '',
        expiresAt: DateTime.fromMicrosecondsSinceEpoch(0),
      );

  @override
  Future<({String code, DateTime expiresAtUtc})> issueInvitation() async =>
      (code: 'FAKE', expiresAtUtc: DateTime.now().toUtc());

  @override
  Future<RegisteredUser> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    String? organizationName,
  }) async {
    registerCalls++;
    registeredEmail = email.trim().toLowerCase();
    return RegisteredUser(
      id: 'u1',
      tenantId: 't1',
      email: registeredEmail!,
      fullName: fullName,
      emailVerified: false,
    );
  }

  @override
  Future<RegisteredUser> registerStaff({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String invitationCode,
  }) async {
    registerStaffCalls++;
    lastInvitationCode = invitationCode;
    registeredEmail = email.trim().toLowerCase();
    return RegisteredUser(
      id: 'u2',
      tenantId: 't1',
      email: registeredEmail!,
      fullName: fullName,
      emailVerified: false,
    );
  }

  @override
  Future<void> verifyEmail(
      {required String email, required String code}) async {
    verifyCalls++;
    lastVerifyCode = code;
    final error = verifyError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> resendVerificationCode({required String email}) async {
    resendCalls++;
  }

  @override
  Future<LoginOutcome> login({
    required String identifier,
    required String password,
  }) async {
    loginIdentifier = identifier;
    final error = loginError;
    if (error != null) {
      throw error;
    }
    final outcome = loginOutcome;
    if (outcome != null) {
      return outcome;
    }
    throw UnimplementedError('No fake success session configured.');
  }

  @override
  Future<Session> completeTwoFactorChallenge({
    required String challengeToken,
    required String code,
    required bool useRecoveryCode,
  }) async {
    twoFactorCalls++;
    lastTwoFactorCode = code;
    lastTwoFactorUsedRecoveryCode = useRecoveryCode;
    final error = twoFactorError;
    if (error != null) {
      throw error;
    }
    return twoFactorResult!;
  }

  @override
  Future<Session?> loginOffline({
    required String password,
    BiometricAuthGate? biometricGate,
  }) async {
    offlineLoginCalls++;
    final error = loginOfflineError;
    if (error != null) {
      throw error;
    }
    return loginOfflineResult;
  }

  @override
  Future<Session?> loginWithBiometric({
    required BiometricAuthGate biometricGate,
  }) async {
    biometricLoginCalls++;
    if (throwOnBiometric) {
      throw ValidationException('Biometric rejected.');
    }
    return biometricResult;
  }

  @override
  Future<Session?> unlockWithPin({required String pin}) async {
    pinUnlockCalls++;
    final error = unlockWithPinError;
    if (error != null) {
      throw error;
    }
    return unlockWithPinResult;
  }

  @override
  Future<Session?> setupPinAndUnlock({required String pin}) async {
    pinSetupCalls++;
    final error = setupPinError;
    if (error != null) {
      throw error;
    }
    return setupPinResult;
  }

  @override
  Future<void> enableQuickPin({
    required String pin,
    bool enableBiometric = false,
  }) async {
    await offlineStore.setUnlockPin(pin);
  }

  @override
  Future<void> disableQuickPin() async {
    await offlineStore.clearUnlockPin();
  }

  @override
  Future<void> setBiometricEnabled(bool enabled) async {}

  @override
  Future<void> requestPasswordReset({required String email}) async {}

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {}
}

class _FakeOfflineCredentialStore implements OfflineCredentialStore {
  String? cachedEmail;
  bool _hasUnlockPin = false;
  bool verifyUnlockPinResult = false;

  @override
  Future<void> setUnlockPin(String pin) async {
    _hasUnlockPin = true;
  }

  @override
  Future<bool> hasUnlockPin() async => _hasUnlockPin;

  @override
  Future<bool> verifyUnlockPin(String pin) async => verifyUnlockPinResult;

  @override
  Future<bool> isOfflineAuthAvailable() async => cachedEmail != null;

  @override
  Future<bool> verifyPassword(String password) async => false;

  @override
  Future<void> storeCredentials(
      {required String password, required dynamic user}) async {}

  @override
  Future<String?> generateOfflineToken(dynamic user) async => null;

  @override
  Future<void> enableQuickUnlock(dynamic user) async {}

  @override
  Future<bool> hasValidQuickUnlock() async => false;

  @override
  Future<Session?> restoreQuickUnlock() async => null;

  @override
  Future<void> disableQuickUnlock() async {}

  @override
  Future<Session?> restoreOfflineSession() async => null;

  @override
  Future<String?> getCachedUserId() async => null;

  @override
  Future<String?> getCachedTenantId() async => null;

  @override
  Future<List<String>> getCachedPermissions() async => const [];

  @override
  Future<String?> getCachedEmail() async => cachedEmail;

  @override
  Future<String?> getCachedFullName() async => null;

  @override
  Future<void> clearOfflineToken() async {}

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> clearPasswordHash() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedTokenStore implements TokenStore {
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

class _FakeBiometricGate extends BiometricAuthGate {
  _FakeBiometricGate({this.available = true, this.allowed = true});

  final bool available;
  final bool allowed;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate({required String reason}) async => allowed;
}

ProviderContainer _container({
  FakeAuthRepository? repository,
  BiometricAuthGate? gate,
}) {
  final repo = repository ?? FakeAuthRepository();
  return ProviderContainer(overrides: [
    authRepositoryProvider.overrideWithValue(repo),
    if (gate != null) biometricAuthGateProvider.overrideWithValue(gate),
  ]);
}

void main() {
  group('AuthController verification journey', () {
    test('register transitions to needsVerification with normalized email',
        () async {
      final container = _container();
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future.microtask(() {});

      await controller.register(
        email: '  Owner@Test.Local ',
        password: 'Passw0rd!',
        fullName: 'Mama',
        phone: '+255712345678',
        organizationName: 'Duka',
      );

      expect(controller.state, isA<AuthNeedsVerification>());
      final state = controller.state as AuthNeedsVerification;
      expect(state.email, 'owner@test.local');
    });

    test('verifyEmail consumes the code then returns to unauthenticated',
        () async {
      final repository = FakeAuthRepository();
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future.microtask(() {});

      await controller.register(
        email: 'owner@test.local',
        password: 'Passw0rd!',
        fullName: 'Mama',
        phone: '+255712345678',
        organizationName: 'Duka',
      );

      await controller.verifyEmail(code: '123456');

      expect(repository.verifyCalls, 1);
      expect(repository.lastVerifyCode, '123456');
      final state = controller.state;
      expect(state, isA<AuthUnauthenticated>());
      expect((state as AuthUnauthenticated).message, isNotNull);
    });

    test('verifyEmail surfaces backend errors and keeps the pending state',
        () async {
      final repository = FakeAuthRepository()
        ..verifyError = ValidationException('Namba si sahihi.');
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future.microtask(() {});

      await controller.register(
        email: 'owner@test.local',
        password: 'Passw0rd!',
        fullName: 'Mama',
        phone: '+255712345678',
        organizationName: 'Duka',
      );

      await expectLater(
        controller.verifyEmail(code: '000000'),
        throwsA(isA<ValidationException>()),
      );
      expect(controller.state, isA<AuthNeedsVerification>());
    });

    test('resendVerificationCode forwards the pending email', () async {
      final repository = FakeAuthRepository();
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future.microtask(() {});

      await controller.register(
        email: 'owner@test.local',
        password: 'Passw0rd!',
        fullName: 'Mama',
        phone: '+255712345678',
        organizationName: 'Duka',
      );

      await controller.resendVerificationCode();

      expect(repository.resendCalls, 1);
      expect(controller.state, isA<AuthNeedsVerification>());
    });

    test('verifyEmail without a pending registration is a no-op', () async {
      final repository = FakeAuthRepository();
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future.microtask(() {});

      await controller.verifyEmail(code: '123456');

      expect(repository.verifyCalls, 0);
    });

    test('register never authenticates directly', () async {
      final container = _container();
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future.microtask(() {});

      await controller.register(
        email: 'owner@test.local',
        password: 'Passw0rd!',
        fullName: 'Mama',
        phone: '+255712345678',
        organizationName: 'Duka',
      );

      expect(controller.state, isNot(isA<AuthAuthenticated>()));
    });

    test('registerStaff forwards the code and needs verification', () async {
      final repository = FakeAuthRepository();
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future.microtask(() {});

      await controller.registerStaff(
        email: '  Staff@Test.Local ',
        password: 'Passw0rd!',
        fullName: 'Juma',
        phone: '+255712345678',
        invitationCode: 'ABCD1234',
      );

      expect(repository.registerStaffCalls, 1);
      expect(repository.lastInvitationCode, 'ABCD1234');
      expect(repository.registeredEmail, 'staff@test.local');
      final state = controller.state;
      expect(state, isA<AuthNeedsVerification>());
      expect((state as AuthNeedsVerification).email, 'staff@test.local');
    });

    test(
        'login on an unverified account routes back to verification with the email',
        () async {
      final repository = FakeAuthRepository()
        ..loginError = AccountNotVerifiedException(
          'Verify your email address before signing in.',
          email: 'owner@test.local',
        );
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future.microtask(() {});

      await controller.login(identifier: 'owner@test.local', password: 'x');

      expect(repository.loginIdentifier, 'owner@test.local');
      final state = controller.state;
      expect(state, isA<AuthNeedsVerification>());
      expect((state as AuthNeedsVerification).email, 'owner@test.local');
    });

    test('login by phone still recovers the email from the backend error',
        () async {
      final repository = FakeAuthRepository()
        ..loginError = AccountNotVerifiedException(
          'Verify your email address before signing in.',
          email: 'owner@test.local',
        );
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future.microtask(() {});

      await controller.login(identifier: '+255712345678', password: 'x');

      final state = controller.state;
      expect(state, isA<AuthNeedsVerification>());
      expect((state as AuthNeedsVerification).email, 'owner@test.local');
    });

    test('login without a recoverable email rethrows and keeps unauthenticated',
        () async {
      final repository = FakeAuthRepository()
        ..loginError = AccountNotVerifiedException(
          'Verify your email address before signing in.',
          email: '',
        );
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future.microtask(() {});

      await expectLater(
        controller.login(identifier: '+255712345678', password: 'x'),
        throwsA(isA<AccountNotVerifiedException>()),
      );
      expect(controller.state, isNot(isA<AuthNeedsVerification>()));
    });

    test('a two-factor login parks in AuthNeedsTwoFactor without a session',
        () async {
      final repository = FakeAuthRepository()
        ..loginOutcome = const MfaChallenge(
          challengeToken: 'challenge-abc',
          email: 'owner@test.local',
        );
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future.microtask(() {});

      await controller.login(identifier: 'owner@test.local', password: 'x');

      final state = controller.state;
      expect(state, isA<AuthNeedsTwoFactor>());
      final pending = state as AuthNeedsTwoFactor;
      expect(pending.challengeToken, 'challenge-abc');
      expect(pending.email, 'owner@test.local');
      expect(repository.twoFactorCalls, 0);
    });

    test('a phone login with MFA falls back to the typed identifier as email',
        () async {
      // The backend echoes the email, but a client must not render a phone number
      // as an email address.
      final repository = FakeAuthRepository()
        ..loginOutcome = const MfaChallenge(
          challengeToken: 'challenge-abc',
          email: '',
        );
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future.microtask(() {});

      await controller.login(identifier: '+255712345678', password: 'x');

      expect((controller.state as AuthNeedsTwoFactor).email, '+255712345678');
    });

    test('a valid code completes the sign-in', () async {
      final repository = FakeAuthRepository()
        ..loginOutcome = const MfaChallenge(
          challengeToken: 'challenge-abc',
          email: 'owner@test.local',
        )
        ..twoFactorResult = Session(
          user: const AuthUser(
            id: 'u1',
            tenantId: 't1',
            email: 'owner@test.local',
            fullName: 'Mmiliki',
            phone: null,
            isActive: true,
            emailVerified: true,
            permissions: ['sale.create'],
          ),
          accessTokenExpiresAt:
              DateTime.now().toUtc().add(const Duration(minutes: 15)),
        );
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future.microtask(() {});
      await controller.login(identifier: 'owner@test.local', password: 'x');

      await controller.verifyTwoFactor(code: '123456');

      expect(repository.lastTwoFactorCode, '123456');
      expect(repository.lastTwoFactorUsedRecoveryCode, isFalse);
      expect(controller.state, isA<AuthAuthenticated>());
    });

    test('a recovery code is submitted on its own path', () async {
      final repository = FakeAuthRepository()
        ..loginOutcome = const MfaChallenge(
          challengeToken: 'challenge-abc',
          email: 'owner@test.local',
        )
        ..twoFactorResult = Session(
          user: const AuthUser(
            id: 'u1',
            tenantId: 't1',
            email: 'owner@test.local',
            fullName: 'Mmiliki',
            phone: null,
            isActive: true,
            emailVerified: true,
            permissions: ['sale.create'],
          ),
          accessTokenExpiresAt:
              DateTime.now().toUtc().add(const Duration(minutes: 15)),
        );
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future.microtask(() {});
      await controller.login(identifier: 'owner@test.local', password: 'x');

      await controller.verifyTwoFactor(
          code: 'ABCD2345EF', useRecoveryCode: true);

      expect(repository.lastTwoFactorUsedRecoveryCode, isTrue);
      expect(controller.state, isA<AuthAuthenticated>());
    });

    test('a wrong code keeps the challenge alive so the user can retry',
        () async {
      final repository = FakeAuthRepository()
        ..loginOutcome = const MfaChallenge(
          challengeToken: 'challenge-abc',
          email: 'owner@test.local',
        )
        ..twoFactorError = ValidationException('Msimamizi si sahihi.');
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future.microtask(() {});
      await controller.login(identifier: 'owner@test.local', password: 'x');

      await expectLater(
        controller.verifyTwoFactor(code: '000000'),
        throwsA(isA<ValidationException>()),
      );

      final state = controller.state;
      expect(state, isA<AuthNeedsTwoFactor>());
      expect((state as AuthNeedsTwoFactor).challengeToken, 'challenge-abc');
    });

    test('an expired challenge sends the user back to a fresh sign-in',
        () async {
      final repository = FakeAuthRepository()
        ..loginOutcome = const MfaChallenge(
          challengeToken: 'challenge-abc',
          email: 'owner@test.local',
        )
        ..twoFactorError = UnauthorizedException();
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future.microtask(() {});
      await controller.login(identifier: 'owner@test.local', password: 'x');

      await controller.verifyTwoFactor(code: '123456');

      final state = controller.state;
      expect(state, isA<AuthUnauthenticated>());
      expect((state as AuthUnauthenticated).message, isNotNull);
    });

    test('cancelling the challenge returns to the login screen', () async {
      final repository = FakeAuthRepository()
        ..loginOutcome = const MfaChallenge(
          challengeToken: 'challenge-abc',
          email: 'owner@test.local',
        );
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future.microtask(() {});
      await controller.login(identifier: 'owner@test.local', password: 'x');

      await controller.cancelTwoFactor();

      expect(controller.state, isA<AuthUnauthenticated>());
    });

    test('loginWithBiometric authenticates without a password', () async {
      final repository = FakeAuthRepository()
        ..biometricResult = Session(
          user: const AuthUser(
            id: 'u1',
            tenantId: 't1',
            email: 'owner@test.local',
            fullName: 'Owner',
            phone: null,
            isActive: true,
            emailVerified: true,
            permissions: ['sale.create'],
          ),
          accessTokenExpiresAt: DateTime.now().toUtc().add(
                const Duration(hours: 24),
              ),
        );
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future.microtask(() {});

      await controller.loginWithBiometric();

      expect(repository.biometricLoginCalls, 1);
      expect(controller.state, isA<AuthAuthenticated>());
      expect((controller.state as AuthAuthenticated).isOffline, isTrue);
    });

    test('loginWithBiometric without a quick session stays unauthenticated',
        () async {
      final repository = FakeAuthRepository();
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future.microtask(() {});

      await controller.loginWithBiometric();

      expect(repository.biometricLoginCalls, 1);
      expect(controller.state, isA<AuthUnauthenticated>());
      expect(
        (controller.state as AuthUnauthenticated).message,
        contains('Ingia kwa nenosiri'),
      );
    });

    test('loginWithBiometric surfaces biometric rejection', () async {
      final repository = FakeAuthRepository()..throwOnBiometric = true;
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future.microtask(() {});

      await controller.loginWithBiometric();

      expect(controller.state, isA<AuthUnauthenticated>());
      expect(
        (controller.state as AuthUnauthenticated).message,
        contains('Biometric rejected'),
      );
    });
  });

  group('AuthController offline-invisible login and device lock', () {
    Session offlineSession() => Session(
          user: const AuthUser(
            id: 'u1',
            tenantId: 't1',
            email: 'owner@test.local',
            fullName: 'Owner',
            phone: null,
            isActive: true,
            emailVerified: true,
            permissions: ['sale.create'],
          ),
          accessTokenExpiresAt: DateTime.now().toUtc().add(
                const Duration(hours: 72),
              ),
        );

    test(
        'network failure silently falls back to offline when the identifier matches',
        () async {
      final repository = FakeAuthRepository()
        ..loginError = NetworkException()
        ..loginOfflineResult = offlineSession();
      repository.offlineStore.cachedEmail = 'owner@test.local';
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future.microtask(() {});

      await controller.login(
        identifier: '  Owner@Test.Local ',
        password: 'secret',
      );

      expect(repository.offlineLoginCalls, 1);
      final state = controller.state;
      expect(state, isA<AuthAuthenticated>());
      expect((state as AuthAuthenticated).isOffline, isTrue);
    });

    test('network failure without a matching cached account stays on login',
        () async {
      final repository = FakeAuthRepository()..loginError = NetworkException();
      repository.offlineStore.cachedEmail = 'owner@test.local';
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future.microtask(() {});

      await controller.login(
        identifier: 'stranger@test.local',
        password: 'secret',
      );

      expect(repository.offlineLoginCalls, 0,
          reason: 'a different account must never unlock cached offline data');
      expect(controller.state, isA<AuthUnauthenticated>());
    });

    test('wrong password on a silent fallback rethrows the neutral message',
        () async {
      final repository = FakeAuthRepository()
        ..loginError = NetworkException()
        ..loginOfflineError =
            ValidationException('Nenosiri si sahihi. Jaribu tena.');
      repository.offlineStore.cachedEmail = 'owner@test.local';
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future.microtask(() {});

      await expectLater(
        controller.login(identifier: 'owner@test.local', password: 'wrong'),
        throwsA(isA<ValidationException>()),
      );
      expect(repository.offlineLoginCalls, 1);
    });

    test('lock() is a no-op before any session exists', () async {
      final container = _container();
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future.microtask(() {});

      controller.lock();

      expect(controller.state, isNot(isA<AuthLocked>()));
    });

    test(
        'lock() freezes an authenticated session; unlock() with a fresh '
        'biometric restores it exactly', () async {
      final repository = FakeAuthRepository()
        ..loginOfflineResult = offlineSession();
      final container = _container(
        repository: repository,
        gate: _FakeBiometricGate(available: true, allowed: true),
      );
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future.microtask(() {});

      await controller.loginOffline(password: 'secret');
      expect(controller.state, isA<AuthAuthenticated>());

      controller.lock();
      final locked = controller.state;
      expect(locked, isA<AuthLocked>());
      expect((locked as AuthLocked).session.user.email, 'owner@test.local');

      await controller.unlock();
      final restored = controller.state;
      expect(restored, isA<AuthAuthenticated>());
      expect((restored as AuthAuthenticated).session.user.email,
          'owner@test.local');
    });

    test('unlock() without a usable fast factor ends the locked session',
        () async {
      final repository = FakeAuthRepository()
        ..loginOfflineResult = offlineSession();
      final container = _container(
        repository: repository,
        gate: _FakeBiometricGate(available: false, allowed: false),
      );
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future.microtask(() {});

      await controller.loginOffline(password: 'secret');
      controller.lock();
      await controller.unlock();

      expect(controller.state, isA<AuthUnauthenticated>());
    });

    test('unlockWithPin restores a locked session after a valid PIN', () async {
      final repository = FakeAuthRepository()
        ..loginOfflineResult = offlineSession();
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future.microtask(() {});

      await controller.loginOffline(password: 'secret');
      controller.lock();
      repository.offlineStore.verifyUnlockPinResult = true;

      await controller.unlockWithPin(pin: '1234');

      final state = controller.state;
      expect(state, isA<AuthAuthenticated>());
      expect((state as AuthAuthenticated).isOffline, isTrue);
    });

    test('unlockWithPin with a wrong PIN throws and keeps the lock', () async {
      final repository = FakeAuthRepository()
        ..loginOfflineResult = offlineSession();
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future.microtask(() {});

      await controller.loginOffline(password: 'secret');
      controller.lock();

      await expectLater(
        controller.unlockWithPin(pin: '0000'),
        throwsA(isA<ValidationException>()),
      );
      expect(controller.state, isA<AuthLocked>());
    });

    test('loginWithPin releases a trusted session on a no-biometric device',
        () async {
      final repository = FakeAuthRepository()
        ..unlockWithPinResult = offlineSession();
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future.microtask(() {});

      await controller.loginWithPin(pin: '1234');

      expect(repository.pinUnlockCalls, 1);
      expect(controller.state, isA<AuthAuthenticated>());
    });

    test('setupPin configures the device PIN and releases the trusted session',
        () async {
      final repository = FakeAuthRepository()
        ..setupPinResult = offlineSession();
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future.microtask(() {});

      await controller.setupPin(pin: '5678');

      expect(repository.pinSetupCalls, 1);
      expect(controller.state, isA<AuthAuthenticated>());
    });
  });
}
