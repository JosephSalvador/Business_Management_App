import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/config/app_config.dart';
import 'package:jolinx_app/core/network/api_client.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/features/purchases/data/purchase_repository.dart';
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

Map<String, dynamic> purchaseJson(String id, {String number = 'PO-001'}) => {
      'id': id,
      'number': number,
      'supplierId': 's1',
      'warehouseId': 'w1',
      'status': 0,
      'lines': [
        {
          'id': 'l1',
          'productName': 'Mchele',
          'quantity': 10,
          'unitPrice': 1000,
        },
      ],
    };

void main() {
  group('PurchaseRepository HTTP contract', () {
    test('list parses paged envelope', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode({
              'items': [
                purchaseJson('po1'),
                purchaseJson('po2', number: 'PO-002')
              ],
              'total': 2,
            })),
      ]);
      final repository = PurchaseRepository(apiClient: clientWith(adapter));

      final page = await repository.list();

      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.path, contains('/api/v1/purchase-orders'));
      expect(page.items.length, 2);
      expect(page.total, 2);
      expect(page.items.first['id'], 'po1');
    });

    test('list passes search param when provided', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode({
              'items': [purchaseJson('po1')],
              'total': 1,
            })),
      ]);
      final repository = PurchaseRepository(apiClient: clientWith(adapter));

      await repository.list(search: 'mchele');

      final path = adapter.requests.single.path;
      expect(path, contains('search=mchele'));
    });

    test('getById parses single purchase with lines', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, jsonEncode(purchaseJson('po5'))),
      ]);
      final repository = PurchaseRepository(apiClient: clientWith(adapter));

      final purchase = await repository.getById('po5');

      expect(
        adapter.requests.single.path,
        contains('/api/v1/purchase-orders/po5'),
      );
      expect(purchase['id'], 'po5');
      expect(purchase['lines'], isA<List>());
    });

    test('create sends correct body', () async {
      final adapter = ScriptedAdapter([
        const ScriptedResponse(201, '{}'),
      ]);
      final repository = PurchaseRepository(apiClient: clientWith(adapter));

      final body = {
        'supplierId': 's1',
        'warehouseId': 'w1',
        'lines': [
          {'productName': 'Mchele', 'quantity': 10}
        ],
      };
      await repository.create(body);

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, contains('/api/v1/purchase-orders'));
      expect(jsonDecode(request.body!), body);
    });

    test('submit sends POST', () async {
      final adapter = ScriptedAdapter([
        const ScriptedResponse(200, '{}'),
      ]);
      final repository = PurchaseRepository(apiClient: clientWith(adapter));

      await repository.submit('po1');

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, contains('/api/v1/purchase-orders/po1/submit'));
    });

    test('cancel sends POST', () async {
      final adapter = ScriptedAdapter([
        const ScriptedResponse(200, '{}'),
      ]);
      final repository = PurchaseRepository(apiClient: clientWith(adapter));

      await repository.cancel('po2');

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, contains('/api/v1/purchase-orders/po2/cancel'));
    });

    test('suppliers parses paged suppliers', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode({
              'items': [
                {'id': 's1', 'name': 'Mama Ntilie'},
                {'id': 's2', 'name': 'Bwana Mchele'},
              ],
              'total': 2,
            })),
      ]);
      final repository = PurchaseRepository(apiClient: clientWith(adapter));

      final page = await repository.suppliers();

      expect(adapter.requests.single.path, contains('/api/v1/suppliers'));
      expect(page.items.length, 2);
      expect(page.total, 2);
    });

    test('warehouses parses warehouses list', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode([
              {'id': 'w1', 'name': 'Main Store'},
              {'id': 'w2', 'name': 'Branch Store'},
            ])),
      ]);
      final repository = PurchaseRepository(apiClient: clientWith(adapter));

      final list = await repository.warehouses();

      expect(adapter.requests.single.path, contains('/api/v1/warehouses'));
      expect(list.length, 2);
      expect(list.first['name'], 'Main Store');
    });

    test('getById throws ServerException on bad response', () async {
      final adapter = ScriptedAdapter([
        const ScriptedResponse(500, '{}'),
      ]);
      final repository = PurchaseRepository(apiClient: clientWith(adapter));

      expectLater(repository.getById('po1'), throwsA(isA<ServerException>()));
    });
  });
}
