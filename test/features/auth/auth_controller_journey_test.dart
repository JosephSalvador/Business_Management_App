import 'package:flutter_test/flutter_test.dart';
import 'package:business_management_system/core/config/app_config.dart';
import 'package:business_management_system/core/network/api_client.dart';
import 'package:business_management_system/core/network/app_exception.dart';
import 'package:business_management_system/features/auth/application/auth_controller.dart';
import 'package:business_management_system/features/auth/data/auth_repository.dart';

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

  int registerCalls = 0;
  int verifyCalls = 0;
  int resendCalls = 0;
  int registerStaffCalls = 0;
  String? lastInvitationCode;
  String? lastVerifyCode;
  String? registeredEmail;

  Object? verifyError;

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
  Future<void> verifyEmail({required String email, required String code}) async {
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

void main() {
  group('AuthController verification journey', () {
    test('register transitions to needsVerification with normalized email',
        () async {
      final controller = AuthController(FakeAuthRepository());

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
      final controller = AuthController(repository);
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
      final controller = AuthController(repository);
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
      final controller = AuthController(repository);
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
      final controller = AuthController(repository);

      await controller.verifyEmail(code: '123456');

      expect(repository.verifyCalls, 0);
    });

    test('register never authenticates directly', () async {
      final repository = FakeAuthRepository();
      final controller = AuthController(repository);

      await controller.register(
        email: 'owner@test.local',
        password: 'Passw0rd!',
        fullName: 'Mama',
        phone: '+255712345678',
        organizationName: 'Duka',
      );

      expect(controller.state, isNot(isA<AuthAuthenticated>()));
    });

    test('registerStaff forwards the code and needs verification',
        () async {
      final repository = FakeAuthRepository();
      final controller = AuthController(repository);

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
  });
}
