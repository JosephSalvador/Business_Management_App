import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/config/app_config.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/core/network/api_client.dart';
import 'package:jolinx_app/features/finance/data/money_account_repository.dart';
import '../../support/fakes.dart';

ApiClient clientWith(ScriptedAdapter adapter) => ApiClient(
      config: AppConfig.forTest(
        apiBaseUrl: Uri.parse('https://api.test.local'),
        environment: AppEnvironment.dev,
      ),
      tokenStore: InMemoryTokenStore(),
      refresher: (_) async => throw UnimplementedError(),
      dio: Dio(BaseOptions(baseUrl: 'https://api.test.local'))
        ..httpClientAdapter = adapter,
    );

Map<String, dynamic> sessionJson() => {
      'id': 's1',
      'accountId': 'a1',
      'openingCash': 100000,
      'status': 0,
      'openedAt': '2026-09-01T08:00:00Z',
    };

void main() {
  group('MoneyAccountRepository getCurrentSession HTTP contract', () {
    test('returns the session when the endpoint responds with a JSON body',
        () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, jsonEncode(sessionJson())),
      ]);
      final repository = MoneyAccountRepository(apiClient: clientWith(adapter));

      final session = await repository.getCurrentSession('a1');

      expect(adapter.requests.single.path,
          contains('/api/v1/cash-sessions/current'));
      expect(adapter.requests.single.path, contains('accountId=a1'));
      expect(session, isNotNull);
      expect(session!['accountId'], 'a1');
    });

    test(
        'returns null (no session) when the backend replies 200 with an EMPTY body',
        () async {
      // Backend returns 200 + empty body when no session is open (not 404).
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, ''),
      ]);
      final repository = MoneyAccountRepository(apiClient: clientWith(adapter));

      final session = await repository.getCurrentSession('a1');

      expect(session, isNull);
    });

    test('a 404 surfaces as an AppException through the real client', () async {
      // Through the real ApiClient a 404 raises a DioException (mapped to an AppException)
      // rather than returning a 404 Response. The live backend uses 200 + empty body for
      // "no session" (covered above); this documents the client-side 404 contract.
      final adapter = ScriptedAdapter([
        ScriptedResponse(404, jsonEncode({'title': 'No session'})),
      ]);
      final repository = MoneyAccountRepository(apiClient: clientWith(adapter));

      await expectLater(
        repository.getCurrentSession('a1'),
        throwsA(isA<AppException>()),
      );
    });

    test('throws ServerException when the body is not a Map', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, jsonEncode([1, 2, 3])),
      ]);
      final repository = MoneyAccountRepository(apiClient: clientWith(adapter));

      await expectLater(
        repository.getCurrentSession('a1'),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
