import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/config/app_config.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/core/network/api_client.dart';
import 'package:jolinx_app/features/suppliers/data/supplier_repository.dart';
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

Map<String, dynamic> supplierJson(String id, {String name = 'Acme Supplies'}) =>
    {
      'id': id,
      'tenantId': 't1',
      'name': name,
      'phone': '+255700000000',
      'email': 'acme@example.com',
      'createdAt': '2026-08-23T10:00:00Z',
    };

void main() {
  group('SupplierRepository HTTP contract', () {
    test('list parses the paged envelope', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode({
              'items': [
                supplierJson('s1'),
                supplierJson('s2', name: 'Beta Co')
              ],
              'page': 1,
              'pageSize': 20,
              'total': 2,
            })),
      ]);
      final repository = SupplierRepository(apiClient: clientWith(adapter));

      final page = await repository.list();

      expect(adapter.requests.single.path,
          'https://api.test.local/api/v1/suppliers?page=1&pageSize=20');
      expect(page.items, hasLength(2));
      expect(page.total, 2);
      expect(page.items[0]['name'], 'Acme Supplies');
      expect(page.items[1]['name'], 'Beta Co');
    });

    test('list passes search parameter when provided', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode({
              'items': [supplierJson('s1')],
              'total': 1,
            })),
      ]);
      final repository = SupplierRepository(apiClient: clientWith(adapter));

      await repository.list(search: 'Acme');

      expect(adapter.requests.single.path, contains('search=Acme'));
    });

    test('getById parses a single supplier', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, jsonEncode(supplierJson('s1'))),
      ]);
      final repository = SupplierRepository(apiClient: clientWith(adapter));

      final result = await repository.getById('s1');

      expect(adapter.requests.single.path,
          'https://api.test.local/api/v1/suppliers/s1');
      expect(result['id'], 's1');
      expect(result['name'], 'Acme Supplies');
    });

    test('create sends correct body via POST', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200, jsonEncode(supplierJson('s3', name: 'New Supplier'))),
      ]);
      final repository = SupplierRepository(apiClient: clientWith(adapter));

      final body = {'name': 'New Supplier', 'phone': '+255722222222'};
      final result = await repository.create(body);

      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.path,
          'https://api.test.local/api/v1/suppliers');
      final sentBody =
          jsonDecode(adapter.requests.single.body!) as Map<String, dynamic>;
      expect(sentBody['name'], 'New Supplier');
      expect(sentBody['phone'], '+255722222222');
      expect(result['id'], 's3');
    });

    test('update sends correct body with PUT', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, jsonEncode(supplierJson('s1', name: 'Updated'))),
      ]);
      final repository = SupplierRepository(apiClient: clientWith(adapter));

      final body = {'name': 'Updated'};
      final result = await repository.update('s1', body);

      expect(adapter.requests.single.method, 'PUT');
      expect(adapter.requests.single.path,
          'https://api.test.local/api/v1/suppliers/s1');
      final sentBody =
          jsonDecode(adapter.requests.single.body!) as Map<String, dynamic>;
      expect(sentBody['name'], 'Updated');
      expect(result['name'], 'Updated');
    });

    test('bad response shape throws ServerException', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, '[]'),
      ]);
      final repository = SupplierRepository(apiClient: clientWith(adapter));

      await expectLater(
        repository.list(),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
