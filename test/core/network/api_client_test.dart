import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'package:jolinx_app/core/config/app_config.dart';
import 'package:jolinx_app/core/network/api_client.dart';
import 'package:jolinx_app/core/network/app_exception.dart';

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
    // The refresh token is deliberately withheld from ordinary traffic.
    expect(capturedHeaders.containsKey('X-Refresh-Token'), isFalse);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('sends the refresh token only on the session list', () async {
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
      '/api/v1/me/security/sessions',
      (server) => server.reply(200, <dynamic>[]),
    );
    adapter.onGet(
      '/api/v1/products',
      (server) => server.reply(200, <dynamic>[]),
    );

    await client.get<dynamic>('/api/v1/me/security/sessions');
    expect(capturedHeaders['X-Refresh-Token'], 'r1');

    await client.get<dynamic>('/api/v1/products');
    expect(capturedHeaders.containsKey('X-Refresh-Token'), isFalse);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('sends no session header before a session exists', () async {
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

    adapter.onGet(
      '/api/v1/me/security/sessions',
      (server) => server.reply(200, <dynamic>[]),
    );

    await client.get<dynamic>('/api/v1/me/security/sessions');

    expect(capturedHeaders.containsKey('Authorization'), isFalse);
    expect(capturedHeaders.containsKey('X-Refresh-Token'), isFalse);
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
        'errors': {
          'name': ['required']
        },
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
    await store.writeTokens(
        accessToken: 'stale', refreshToken: 'valid-refresh');

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

  test('402 notifies the payment callback and maps to PaymentRequiredException',
      () async {
    const problem = '{"title":"BillingRequired",'
        '"detail":"Renew to restore full access.",'
        '"status":402,"code":"BillingRequired"}';
    final scripted = ScriptedAdapter(const [ScriptedResponse(402, problem)]);
    dio.httpClientAdapter = scripted;
    var notified = 0;
    client.onPaymentRequired = () async => notified++;

    try {
      await client.post<dynamic>('/api/v1/thing', body: {});
      fail('should throw');
    } on PaymentRequiredException catch (error) {
      expect(error.message, 'Renew to restore full access.');
    }
    expect(notified, 1);
    expect(scripted.requests, hasLength(1));
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('concurrent 402s share a single payment-required notification',
      () async {
    const problem = '{"title":"BillingRequired",'
        '"detail":"Debt lock.",'
        '"status":402,"code":"BillingRequired"}';
    final scripted = ScriptedAdapter(const [
      ScriptedResponse(402, problem),
      ScriptedResponse(402, problem),
    ]);
    dio.httpClientAdapter = scripted;
    var notified = 0;
    client.onPaymentRequired = () async {
      notified++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    };

    Future<Object> capture(Future<Response<dynamic>> call) async {
      try {
        await call;
        return StateError('expected a failure');
      } on Object catch (error) {
        return error;
      }
    }

    final errors = await Future.wait([
      capture(client.get<dynamic>('/api/v1/a')),
      capture(client.get<dynamic>('/api/v1/b')),
    ]);

    expect(errors[0], isA<PaymentRequiredException>());
    expect(errors[1], isA<PaymentRequiredException>());
    expect(notified, 1, reason: 'the 402 notification must be single-flight');
    expect(scripted.requests, hasLength(2));
  }, timeout: const Timeout(Duration(seconds: 30)));
}
