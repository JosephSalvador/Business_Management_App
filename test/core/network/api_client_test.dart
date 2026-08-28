import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'package:business_management_system/core/config/app_config.dart';
import 'package:business_management_system/core/network/api_client.dart';
import 'package:business_management_system/core/network/app_exception.dart';

import '../../support/fakes.dart';

export '../../support/fakes.dart' show InMemoryTokenStore;

AppConfig devConfig() => AppConfig.forTest(
      environment: AppEnvironment.dev,
      apiBaseUrl: Uri.parse('http://localhost:1'),
    );

void main() {
  late InMemoryTokenStore store;
  late Dio dio;
  late DioAdapter adapter;
  late ApiClient client;

  setUp(() {
    store = InMemoryTokenStore();
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:1'));
    adapter = DioAdapter(
      dio: dio,
      matcher: const UrlRequestMatcher(matchMethod: true),
    );
    client = ApiClient(
      config: devConfig(),
      tokenStore: store,
      refresher: (refreshToken) async {
        // Simulate the auth repository's exchange + persistence.
        if (refreshToken == 'valid-refresh') {
          const pair = (
            access: 'new-access',
            refresh: 'rotated-refresh',
          );
          await store.writeTokens(
            accessToken: pair.access,
            refreshToken: pair.refresh,
          );
          return TokenPair(
            accessToken: pair.access,
            refreshToken: pair.refresh,
            expiresAt: DateTime.now().add(const Duration(minutes: 5)),
          );
        }
        throw UnauthorizedException();
      },
      dio: dio,
    );
  });

  test('attaches bearer token from the store', () async {
    final capturedHeaders = <String, dynamic>{};
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          capturedHeaders.clear();
          capturedHeaders.addAll(options.headers);
          handler.next(options);
        },
      ),
    );

    await store.writeTokens(accessToken: 'access-1', refreshToken: 'r1');
    adapter.onGet(
      '/api/v1/ping',
      (server) => server.reply(200, {'ok': true}),
    );

    await client.get<dynamic>('/api/v1/ping');

    expect(capturedHeaders['Authorization'], 'Bearer access-1');
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('maps ProblemDetails to typed exceptions', () async {
    adapter.onPost(
      '/api/v1/auth/login',
      (server) => server.reply(
        401,
        {
          'title': 'Unauthorized',
          'detail': 'Barua pepe au neno la siri si sahihi.',
          'status': 401,
          'code': 'Unauthorized',
        },
      ),
    );

    await expectLater(
      client.post<dynamic>('/api/v1/auth/login', body: {}),
      throwsA(isA<UnauthorizedException>()),
    );
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('parses validation field errors', () async {
    adapter.onPut(
      '/api/v1/thing',
      (server) => server.reply(400, {
        'title': 'Validation Error',
        'detail': 'One or more validation errors occurred.',
        'status': 400,
        'errors': {'name': ['required']},
      }),
    );

    try {
      await client.put<dynamic>('/api/v1/thing', body: {});
      fail('should throw');
    } on ValidationException catch (error) {
      expect(error.fieldErrors['name'], isNotEmpty);
    }
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('network failures become NetworkException', () async {
    adapter.onGet(
      '/api/v1/offline',
      (server) => server.throws(
        0,
        DioException(
          requestOptions: RequestOptions(path: '/api/v1/offline'),
          type: DioExceptionType.connectionError,
        ),
      ),
    );

    await expectLater(
      client.get<dynamic>('/api/v1/offline'),
      throwsA(isA<NetworkException>()),
    );
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('single-flight refresh replays the original request once', () async {
    final adapter = ScriptedAdapter(const [
      ScriptedResponse(401, '{"title":"Unauthorized"}'),
      ScriptedResponse(200, '{"data":42}'),
    ]);
    dio.httpClientAdapter = adapter;
    await store.writeTokens(accessToken: 'stale', refreshToken: 'valid-refresh');

    final response = await client.get<dynamic>('/api/v1/protected');

    expect(response.statusCode, 200);
    expect(response.data, {'data': 42});
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests[0].headers['Authorization'], 'Bearer stale');
    expect(adapter.requests[1].headers['Authorization'], 'Bearer new-access');
    expect(store.accessToken, 'new-access');
    expect(store.refreshToken, 'rotated-refresh');
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('failed refresh clears the session and surfaces Unauthorized', () async {
    await store.writeTokens(accessToken: 'stale', refreshToken: 'dead-token');
    var sessionExpiredFired = false;
    client.onSessionExpired = () => sessionExpiredFired = true;

    adapter.onGet(
      '/api/v1/protected',
      (server) => server.reply(401, {'title': 'Unauthorized'}),
    );

    await expectLater(
      client.get<dynamic>('/api/v1/protected'),
      throwsA(isA<UnauthorizedException>()),
    );
    expect(sessionExpiredFired, isTrue);
    expect(await store.readAccessToken(), isNull);
    expect(await store.readRefreshToken(), isNull);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
