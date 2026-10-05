import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jolinx_app/core/network/api_client.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/core/network/error_mapper.dart';
import 'package:jolinx_app/features/authentication/data/auth_repository.dart';
import 'package:jolinx_app/features/authentication/data/offline_credential_store.dart';
import 'package:jolinx_app/features/authentication/domain/session.dart';

import '../../support/fakes.dart';

class _FakeApiClient implements ApiClient {
  Response<dynamic> Function(String path, {Object? body}) onPost =
      (_, {Object? body}) => throw UnimplementedError();
  int postCalls = 0;

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String> headers = const {},
    Map<String, dynamic> extra = const {},
    dynamic cancelToken,
  }) async {
    postCalls++;
    final result = onPost(path, body: body);
    // Mirror real ApiClient behaviour: non-2xx becomes a typed AppException.
    if ((result.statusCode ?? 0) >= 400) {
      throw mapErrorResponse(result.statusCode, result.data);
    }
    return Response<T>(
      data: result.data as T,
      statusCode: result.statusCode,
      requestOptions: RequestOptions(path: path),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeOfflineCredentialStore implements OfflineCredentialStore {
  bool _hasQuickUnlock = false;
  Session? quickUnlockSession;
  String? acceptedPin;
  String? lastSetPin;

  @override
  Future<bool> isOfflineAuthAvailable() async => false;

  @override
  Future<bool> verifyPassword(String password) async => false;

  @override
  Future<void> storeCredentials(
      {required String password, required dynamic user}) async {}

  @override
  Future<Session?> restoreOfflineSession() async => null;

  @override
  Future<String?> generateOfflineToken(dynamic user) async => null;

  @override
  Future<void> enableQuickUnlock(dynamic user) async {
    _hasQuickUnlock = true;
  }

  @override
  Future<bool> hasValidQuickUnlock() async => _hasQuickUnlock;

  @override
  Future<Session?> restoreQuickUnlock() async => quickUnlockSession;

  @override
  Future<void> disableQuickUnlock() async {
    _hasQuickUnlock = false;
  }

  @override
  Future<bool> verifyUnlockPin(String pin) async =>
      acceptedPin != null && pin == acceptedPin;

  @override
  Future<void> setUnlockPin(String pin) async {
    lastSetPin = pin;
  }

  @override
  Future<bool> hasUnlockPin() async => lastSetPin != null;

  @override
  Future<void> clearOfflineToken() async {}

  @override
  Future<void> clearAll() async {
    _hasQuickUnlock = false;
  }

  @override
  Future<void> clearPasswordHash() async {
    _hasQuickUnlock = false;
  }

  @override
  Future<String?> getCachedUserId() async => null;

  @override
  Future<String?> getCachedTenantId() async => null;

  @override
  Future<List<String>> getCachedPermissions() async => const [];

  @override
  Future<String?> getCachedEmail() async => null;

  @override
  Future<String?> getCachedFullName() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Response<dynamic> _json(int status, Map<String, dynamic> body) =>
    Response<dynamic>(
      data: body,
      statusCode: status,
      requestOptions: RequestOptions(path: '/test'),
    );

/// The token payload the backend nests under `tokens`.
Map<String, dynamic> _authPayload() => {
      'accessToken': 'access-1',
      'refreshToken': 'refresh-1',
      'accessTokenExpiresAt': '2026-08-21T12:00:00Z',
      'user': {
        'id': 'u1',
        'tenantId': 't1',
        'email': 'owner@duka.tz',
        'fullName': 'Mmiliki',
        'phone': null,
        'isActive': true,
        'emailVerified': false,
        'twoFactorEnabled': true,
        'permissions': ['Sales.Create'],
      },
    };

void main() {
  late InMemoryTokenStore store;
  late _FakeApiClient api;
  late _FakeOfflineCredentialStore offlineStore;

  setUp(() {
    store = InMemoryTokenStore();
    api = _FakeApiClient();
    offlineStore = _FakeOfflineCredentialStore();
  });

  AuthRepository repo() => AuthRepository(
        apiClient: api,
        tokenStore: store,
        offlineCredentialStore: offlineStore,
      );

  group('AuthRepository', () {
    test('login stores tokens and returns the session', () async {
      api.onPost = (path, {Object? body}) {
        expect(path, '/api/v1/auth/login');
        // Login is always the discriminated envelope; tokens are never top-level.
        return _json(200, {
          'status': 'authenticated',
          'tokens': _authPayload(),
          'challengeToken': null,
          'email': 'owner@duka.tz',
        });
      };

      final outcome =
          await repo().login(identifier: 'owner@duka.tz', password: 'secret');

      expect(outcome, isA<AuthenticatedLogin>());
      final session = (outcome as AuthenticatedLogin).session;
      expect(session.user.email, 'owner@duka.tz');
      expect(session.accessTokenExpiresAt.year, 2026);
      expect(await store.readAccessToken(), 'access-1');
      expect(await store.readRefreshToken(), 'refresh-1');
    });

    test('a two-factor login stores no tokens and returns the challenge',
        () async {
      api.onPost = (path, {Object? body}) => _json(200, {
            'status': 'two_factor_required',
            'tokens': null,
            'challengeToken': 'challenge-abc',
            'email': 'owner@duka.tz',
          });

      final outcome =
          await repo().login(identifier: 'owner@duka.tz', password: 'secret');

      expect(outcome, isA<MfaChallenge>());
      final challenge = outcome as MfaChallenge;
      expect(challenge.challengeToken, 'challenge-abc');
      expect(challenge.email, 'owner@duka.tz');
      // Nothing is persisted: a correct password is not yet a session.
      expect(await store.readAccessToken(), isNull);
      expect(await store.readRefreshToken(), isNull);
    });

    test('completing a TOTP challenge stores the tokens', () async {
      api.onPost = (path, {Object? body}) {
        expect(path, '/api/v1/auth/two-factor/verify');
        expect((body! as Map)['useRecoveryCode'], false);
        // The verify endpoint answers with the tokens directly: no envelope, because
        // reaching it already means the factor was proven.
        return _json(200, _authPayload());
      };

      final session = await repo().completeTwoFactorChallenge(
        challengeToken: 'challenge-abc',
        code: '123456',
        useRecoveryCode: false,
      );

      expect(session.user.email, 'owner@duka.tz');
      expect(await store.readAccessToken(), 'access-1');
    });

    test(
        'completing with a recovery code tells the backend which path was used',
        () async {
      api.onPost = (path, {Object? body}) {
        expect((body! as Map)['useRecoveryCode'], true);
        return _json(200, _authPayload());
      };

      await repo().completeTwoFactorChallenge(
        challengeToken: 'challenge-abc',
        code: 'ABCD2345EF',
        useRecoveryCode: true,
      );

      expect(await store.readAccessToken(), 'access-1');
    });

    test('an expired challenge is reported rather than retried silently',
        () async {
      api.onPost = (path, {Object? body}) => _json(401, {
            'title': 'Unauthorized',
            'detail': 'This sign-in attempt has expired. Sign in again.',
          });

      await expectLater(
        repo().completeTwoFactorChallenge(
          challengeToken: 'challenge-abc',
          code: '123456',
          useRecoveryCode: false,
        ),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(await store.readAccessToken(), isNull);
    });

    test('a verify response without tokens is treated as a bad shape',
        () async {
      api.onPost = (path, {Object? body}) => _json(200, {
            'user': _authPayload()['user'],
          });

      await expectLater(
        repo().completeTwoFactorChallenge(
          challengeToken: 'challenge-abc',
          code: '123456',
          useRecoveryCode: false,
        ),
        throwsA(isA<ServerException>()),
      );
      expect(await store.readAccessToken(), isNull);
    });

    test('invalid credentials surface UnauthorizedException and store nothing',
        () async {
      api.onPost = (path, {Object? body}) => _json(401, {
            'title': 'Unauthorized',
            'detail': 'Barua pepe au neno la siri si sahihi.',
          });

      await expectLater(
        repo().login(identifier: 'x@y.z', password: 'bad'),
        throwsA(isA<UnauthorizedException>()),
      );
      // Wait a tick so the unawaited persistence (never called) is observed.
      expect(await store.readAccessToken(), isNull);
    });

    test(
        'login 403 AccountNotVerified maps to a typed exception with the email',
        () async {
      api.onPost = (path, {Object? body}) => _json(403, {
            'title': 'AccountNotVerified',
            'code': 'AccountNotVerified',
            'detail': 'Verify your email address before signing in.',
            'email': 'owner@duka.tz',
          });

      await expectLater(
        repo().login(identifier: '+255712345678', password: 'x'),
        throwsA(
          isA<AccountNotVerifiedException>()
              .having((e) => e.email, 'email', 'owner@duka.tz'),
        ),
      );
      expect(await store.readAccessToken(), isNull);
    });

    test('login 403 without a code still maps to ForbiddenException', () async {
      api.onPost = (path, {Object? body}) => _json(403, {
            'title': 'Forbidden',
            'code': 'Forbidden',
            'detail': 'Not allowed.',
          });

      await expectLater(
        repo().login(identifier: 'x@y.z', password: 'x'),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('logout clears local tokens even when revoke fails', () async {
      await store.writeTokens(accessToken: 'a', refreshToken: 'r');
      api.onPost = (path, {Object? body}) => throw NetworkException();

      await repo().logout();

      expect(api.postCalls, 1);
      expect(await store.readAccessToken(), isNull);
      expect(await store.readRefreshToken(), isNull);
    });
  });

  group('Trusted-device PIN unlock', () {
    Session trustedSession() => Session(
          user: const AuthUser(
            id: 'u1',
            tenantId: 't1',
            email: 'owner@duka.tz',
            fullName: 'Mmiliki',
            phone: null,
            isActive: true,
            emailVerified: true,
            permissions: ['sale.create'],
          ),
          accessTokenExpiresAt: DateTime.now().toUtc().add(
                const Duration(days: 7),
              ),
        );

    test('unlockWithPin returns null when the device is not trusted', () async {
      offlineStore.acceptedPin = '1234';
      expect(await repo().unlockWithPin(pin: '1234'), isNull);
    });

    test('unlockWithPin verifies the PIN then releases the quick session',
        () async {
      await offlineStore.enableQuickUnlock(const AuthUser(
        id: 'u1',
        tenantId: 't1',
        email: 'owner@duka.tz',
        fullName: 'Mmiliki',
        phone: null,
        isActive: true,
        emailVerified: true,
        permissions: ['sale.create'],
      ));
      offlineStore.acceptedPin = '1234';
      offlineStore.quickUnlockSession = trustedSession();

      final session = await repo().unlockWithPin(pin: '1234');

      expect(session, isNotNull);
      expect(session!.user.email, 'owner@duka.tz');
      expect(offlineStore._hasQuickUnlock, isTrue,
          reason: 'a successful unlock must slide the trusted window');
    });

    test('unlockWithPin rejects a wrong PIN', () async {
      await offlineStore.enableQuickUnlock(const AuthUser(
        id: 'u1',
        tenantId: 't1',
        email: 'owner@duka.tz',
        fullName: 'Mmiliki',
        phone: null,
        isActive: true,
        emailVerified: true,
        permissions: ['sale.create'],
      ));
      offlineStore.acceptedPin = '1234';
      offlineStore.quickUnlockSession = trustedSession();

      await expectLater(
        repo().unlockWithPin(pin: '0000'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('setupPinAndUnlock is a no-op without a trusted device', () async {
      expect(await repo().setupPinAndUnlock(pin: '1234'), isNull);
    });

    test('setupPinAndUnlock stores the PIN then releases the quick session',
        () async {
      await offlineStore.enableQuickUnlock(const AuthUser(
        id: 'u1',
        tenantId: 't1',
        email: 'owner@duka.tz',
        fullName: 'Mmiliki',
        phone: null,
        isActive: true,
        emailVerified: true,
        permissions: ['sale.create'],
      ));
      offlineStore.quickUnlockSession = trustedSession();

      final session = await repo().setupPinAndUnlock(pin: '5678');

      expect(offlineStore.lastSetPin, '5678');
      expect(session, isNotNull);
      expect(session!.user.email, 'owner@duka.tz');
    });
  });

  group('Session parsing', () {
    test('fromAuthResponse parses user and expiry', () {
      final session = Session.fromAuthResponse({
        'accessToken': 'a',
        'refreshToken': 'r',
        'accessTokenExpiresAt': '2026-08-21T10:00:00Z',
        'user': {
          'id': 'u1',
          'tenantId': 't1',
          'email': 'e@x.y',
          'permissions': ['p'],
        },
      });
      expect(session.user.id, 'u1');
      expect(session.isAccessTokenExpired, isTrue); // date in the past
    });

    test('parseDate falls back to epoch for garbage input', () {
      expect(
        Session.parseDate('not-a-date').millisecondsSinceEpoch,
        0,
      );
    });
  });
}
