import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/config/app_config.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/core/network/api_client.dart';
import 'package:jolinx_app/core/storage/offline_cache_dao.dart';
import 'package:jolinx_app/core/storage/sync_queue_dao.dart';
import 'package:jolinx_app/features/customers/data/customer_repository.dart';
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

Map<String, dynamic> customerJson(String id, {String name = 'John Doe'}) => {
      'id': id,
      'tenantId': 't1',
      'name': name,
      'phone': '+255700000000',
      'email': 'john@example.com',
      'createdAt': '2026-08-23T10:00:00Z',
    };

void main() {
  group('CustomerRepository HTTP contract', () {
    test('list parses the paged envelope', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode({
              'items': [customerJson('c1'), customerJson('c2', name: 'Jane')],
              'page': 1,
              'pageSize': 20,
              'total': 2,
            })),
      ]);
      final repository = CustomerRepository(apiClient: clientWith(adapter));

      final page = await repository.list();

      expect(adapter.requests.single.path,
          'https://api.test.local/api/v1/customers?page=1&pageSize=20');
      expect(page.items, hasLength(2));
      expect(page.total, 2);
      expect(page.items[0]['name'], 'John Doe');
      expect(page.items[1]['name'], 'Jane');
    });

    test('list passes search parameter when provided', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode({
              'items': [customerJson('c1')],
              'total': 1,
            })),
      ]);
      final repository = CustomerRepository(apiClient: clientWith(adapter));

      await repository.list(search: 'John');

      expect(adapter.requests.single.path, contains('search=John'));
    });

    test('getById parses a single customer', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, jsonEncode(customerJson('c1'))),
      ]);
      final repository = CustomerRepository(apiClient: clientWith(adapter));

      final result = await repository.getById('c1');

      expect(adapter.requests.single.path,
          'https://api.test.local/api/v1/customers/c1');
      expect(result['id'], 'c1');
      expect(result['name'], 'John Doe');
    });

    test('create sends correct body', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, jsonEncode(customerJson('c3', name: 'New'))),
      ]);
      final repository = CustomerRepository(apiClient: clientWith(adapter));

      final body = {'name': 'New', 'phone': '+255711111111'};
      final result = await repository.create(body);

      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.path,
          'https://api.test.local/api/v1/customers');
      final sentBody =
          jsonDecode(adapter.requests.single.body!) as Map<String, dynamic>;
      expect(sentBody['name'], 'New');
      expect(sentBody['phone'], '+255711111111');
      expect(result['id'], 'c3');
    });

    test('update sends correct body with PUT', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, jsonEncode(customerJson('c1', name: 'Updated'))),
      ]);
      final repository = CustomerRepository(apiClient: clientWith(adapter));

      final body = {'name': 'Updated'};
      final result = await repository.update('c1', body);

      expect(adapter.requests.single.method, 'PUT');
      expect(adapter.requests.single.path,
          'https://api.test.local/api/v1/customers/c1');
      final sentBody =
          jsonDecode(adapter.requests.single.body!) as Map<String, dynamic>;
      expect(sentBody['name'], 'Updated');
      expect(result['name'], 'Updated');
    });

    test('bad response shape throws ServerException', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, '[]'),
      ]);
      final repository = CustomerRepository(apiClient: clientWith(adapter));

      await expectLater(
        repository.list(),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('CustomerRepository offline resilience', () {
    test('list falls back to cache on network failure and filters by search', () async {
      final cache = InMemoryOfflineCacheDao();
      await cache.save('customers_list', {
        'items': [
          customerJson('c1', name: 'Mussa Juma'),
          customerJson('c2', name: 'Baraka Pharmacy'),
        ],
        'total': 2,
      });

      // Network adapter that immediately throws NetworkException
      final adapter = ScriptedAdapter([
        ScriptedResponse(503, 'offline'),
      ]);
      final repository = CustomerRepository(
        apiClient: clientWith(adapter),
        cache: cache,
      );

      final paged = await repository.list(search: 'Baraka');
      expect(paged.items, hasLength(1));
      expect(paged.items.first['name'], 'Baraka Pharmacy');
      expect(paged.total, 1);
    });

    test('create generates provisional customer and saves locally when offline', () async {
      final cache = InMemoryOfflineCacheDao();
      final queue = InMemorySyncQueueDao();

      final adapter = ScriptedAdapter([
        ScriptedResponse(503, 'offline'),
      ]);
      final repository = CustomerRepository(
        apiClient: clientWith(adapter),
        cache: cache,
        queue: queue,
      );

      final created = await repository.create({
        'name': 'Hamisi Bakari',
        'phone': '+255755123456',
      });

      expect(created['name'], 'Hamisi Bakari');
      expect(created['phone'], '+255755123456');
      expect(created['isOfflinePending'], isTrue);
      expect(created['id'], isNotEmpty);

      // Verify cached
      final cached = await cache.load('customer_${created['id']}');
      expect(cached, isNotNull);
      expect(cached!['name'], 'Hamisi Bakari');
    });
  });
}

class InMemoryOfflineCacheDao implements OfflineCacheDao {
  final Map<String, Map<String, dynamic>> store = {};

  @override
  Future<void> save(String key, Map<String, dynamic> data) async {
    store[key] = Map<String, dynamic>.from(data);
  }

  @override
  Future<Map<String, dynamic>?> load(String key) async => store[key];

  @override
  Future<void> clear(String key) async {
    store.remove(key);
  }

  @override
  Future<DateTime?> getLastUpdated(String key) async => DateTime.now();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class InMemorySyncQueueDao implements SyncQueueDao {
  @override
  Future<void> enqueue({
    required String operationId,
    required String tenantId,
    required String branchId,
    required String deviceId,
    required String operationType,
    required String aggregateType,
    required String aggregateId,
    required String payload,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
