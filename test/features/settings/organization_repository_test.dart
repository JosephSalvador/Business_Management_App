import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/config/app_config.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/core/network/api_client.dart';
import 'package:jolinx_app/features/settings/data/organization_repository.dart';
import '../../support/fakes.dart';

ApiClient clientWith(ScriptedAdapter adapter) => ApiClient(
      config: AppConfig.forTest(
        apiBaseUrl: Uri.parse('https://api.test.local'),
        environment: AppEnvironment.dev,
      ),
      tokenStore: InMemoryTokenStore(),
      refresher: (_) async => TokenPair(
        accessToken: 'a',
        refreshToken: 'r',
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 15)),
      ),
      dio: Dio(BaseOptions(baseUrl: 'https://api.test.local'))
        ..httpClientAdapter = adapter,
    );

void main() {
  group('OrganizationRepository HTTP contract', () {
    test('get parses organization fields', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode({
              'name': 'JolinX Ltd',
              'address': '123 Main St, Dar es Salaam',
              'phone': '+255700000000',
              'email': 'info@jolinx.co.tz',
              'taxId': 'TZ-123456',
              'countryCode': 'TZ',
              'currency': 'TZS',
            })),
      ]);
      final repository = OrganizationRepository(apiClient: clientWith(adapter));

      final org = await repository.get();

      expect(adapter.requests.single.path, contains('/api/v1/organization'));
      expect(org.name, 'JolinX Ltd');
      expect(org.address, '123 Main St, Dar es Salaam');
      expect(org.phone, '+255700000000');
      expect(org.email, 'info@jolinx.co.tz');
      expect(org.taxId, 'TZ-123456');
      expect(org.countryCode, 'TZ');
      expect(org.currency, 'TZS');
    });

    test('get returns null fields when absent from response', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, jsonEncode(<String, dynamic>{})),
      ]);
      final repository = OrganizationRepository(apiClient: clientWith(adapter));

      final org = await repository.get();

      expect(org.name, isNull);
      expect(org.email, isNull);
      expect(org.currency, isNull);
    });

    test('update sends correct body with PUT', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode({
              'name': 'Updated Name',
              'address': 'New Address',
            })),
      ]);
      final repository = OrganizationRepository(apiClient: clientWith(adapter));

      final org = await repository.update({
        'name': 'Updated Name',
        'address': 'New Address',
      });

      expect(adapter.requests.single.method, 'PUT');
      expect(adapter.requests.single.path, contains('/api/v1/organization'));
      final body =
          jsonDecode(adapter.requests.single.body!) as Map<String, dynamic>;
      expect(body['name'], 'Updated Name');
      expect(body['address'], 'New Address');
      expect(org.name, 'Updated Name');
    });

    test('get throws ServerException on 500', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            500,
            jsonEncode({
              'title': 'Server',
              'detail': 'Something broke.',
              'code': 'Server',
            })),
      ]);
      final repository = OrganizationRepository(apiClient: clientWith(adapter));

      await expectLater(
        repository.get(),
        throwsA(isA<ServerException>()),
      );
    });

    test('update throws ServerException on 500', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            500,
            jsonEncode({
              'title': 'Server',
              'detail': 'Something broke.',
              'code': 'Server',
            })),
      ]);
      final repository = OrganizationRepository(apiClient: clientWith(adapter));

      await expectLater(
        repository.update({'name': 'X'}),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
