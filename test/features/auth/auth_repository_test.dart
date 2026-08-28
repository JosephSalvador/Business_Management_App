import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:business_management_system/core/network/api_client.dart';
import 'package:business_management_system/core/network/app_exception.dart';
import 'package:business_management_system/core/network/error_mapper.dart';
import 'package:business_management_system/features/auth/data/auth_repository.dart';
import 'package:business_management_system/features/auth/domain/session.dart';

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

Response<dynamic> _json(int status, Map<String, dynamic> body) =>
    Response<dynamic>(
      data: body,
      statusCode: status,
      requestOptions: RequestOptions(path: '/test'),
    );

void main() {
  group('AuthRepository', () {
    late InMemoryTokenStore store;
    late _FakeApiClient api;

    setUp(() {
      store = InMemoryTokenStore();
      api = _FakeApiClient();
    });

    AuthRepository repo() => AuthRepository(apiClient: api, tokenStore: store);

    test('login stores tokens and returns the session', () async {
      api.onPost = (path, {Object? body}) {
        expect(path, '/api/v1/auth/login');
        return _json(200, {
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
            'permissions': ['Sales.Create'],
          },
        });
      };

      final session = await repo().login(identifier: 'owner@duka.tz', password: 'secret');

      expect(session.user.email, 'owner@duka.tz');
      expect(session.accessTokenExpiresAt.year, 2026);
      expect(await store.readAccessToken(), 'access-1');
      expect(await store.readRefreshToken(), 'refresh-1');
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

    test('logout clears local tokens even when revoke fails', () async {
      await store.writeTokens(accessToken: 'a', refreshToken: 'r');
      api.onPost = (path, {Object? body}) => throw NetworkException();

      await repo().logout();

      expect(api.postCalls, 1);
      expect(await store.readAccessToken(), isNull);
      expect(await store.readRefreshToken(), isNull);
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
