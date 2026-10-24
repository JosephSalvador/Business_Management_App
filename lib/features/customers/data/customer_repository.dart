import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/storage/offline_cache_dao.dart';
import '../../../core/storage/sync_queue_dao.dart';

class PagedCustomers {
  const PagedCustomers({required this.items, required this.total});

  final List<Map<String, dynamic>> items;
  final int total;
}

class CustomerRepository {
  CustomerRepository({
    required ApiClient apiClient,
    OfflineCacheDao? cache,
    SyncQueueDao? queue,
    Future<String?> Function()? tenantIdOf,
    Future<String?> Function()? branchIdOf,
    Future<String> Function()? deviceIdOf,
    Uuid uuid = const Uuid(),
  })  : _apiClient = apiClient,
        _cache = cache,
        _queue = queue,
        _tenantIdOf = tenantIdOf,
        _branchIdOf = branchIdOf,
        _deviceIdOf = deviceIdOf,
        _uuid = uuid;

  final ApiClient _apiClient;
  final OfflineCacheDao? _cache;
  final SyncQueueDao? _queue;
  final Future<String?> Function()? _tenantIdOf;
  final Future<String?> Function()? _branchIdOf;
  final Future<String> Function()? _deviceIdOf;
  final Uuid _uuid;

  static const _cacheKey = 'customers_list';

  Future<PagedCustomers> list({
    int page = 1,
    int pageSize = 20,
    String? search,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    };

    try {
      final response = await _apiClient.get<dynamic>(
        '/api/v1/customers',
        query: query,
      );
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      final doc = Map<String, dynamic>.from(response.data as Map);
      final items = (doc['items'] as List<dynamic>? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((raw) => Map<String, dynamic>.from(raw))
          .toList(growable: false);

      // Cache online customer catalog for offline use
      if (_cache != null && search == null) {
        await _cache!.save(_cacheKey, {
          'items': items,
          'total': doc['total'] ?? items.length,
        });
        for (final item in items) {
          final id = item['id']?.toString();
          if (id != null && id.isNotEmpty) {
            await _cache!.save('customer_$id', item);
          }
        }
      }

      return PagedCustomers(
        items: items,
        total: (doc['total'] as num?)?.toInt() ?? items.length,
      );
    } on AppException {
      // 100% Offline fallback
      if (_cache != null) {
        final cached = await _cache!.load(_cacheKey);
        if (cached != null) {
          var items = (cached['items'] as List<dynamic>? ?? const [])
              .whereType<Map<dynamic, dynamic>>()
              .map((raw) => Map<String, dynamic>.from(raw))
              .toList();

          if (search != null && search.trim().isNotEmpty) {
            final term = search.trim().toLowerCase();
            items = items.where((c) {
              final name = (c['name'] ?? '').toString().toLowerCase();
              final phone = (c['phone'] ?? '').toString().toLowerCase();
              return name.contains(term) || phone.contains(term);
            }).toList();
          }

          return PagedCustomers(items: items, total: items.length);
        }
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getById(String id) async {
    try {
      final response = await _apiClient.get<dynamic>('/api/v1/customers/$id');
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      final data = Map<String, dynamic>.from(response.data as Map);
      if (_cache != null) {
        await _cache!.save('customer_$id', data);
      }
      return data;
    } on AppException {
      if (_cache != null) {
        final cached = await _cache!.load('customer_$id');
        if (cached != null) return cached;

        final listCached = await _cache!.load(_cacheKey);
        if (listCached != null) {
          final items = (listCached['items'] as List<dynamic>? ?? const [])
              .whereType<Map<dynamic, dynamic>>()
              .map((raw) => Map<String, dynamic>.from(raw));
          final found = items.where((c) => c['id']?.toString() == id);
          if (found.isNotEmpty) return found.first;
        }
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> create(
    Map<String, dynamic> body, {
    bool remoteOnly = false,
  }) async {
    try {
      final response = await _apiClient.post<dynamic>(
        '/api/v1/customers',
        body: body,
      );
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      final created = Map<String, dynamic>.from(response.data as Map);
      if (_cache != null) {
        await _cache!.save('customer_${created['id']}', created);
        await _appendCustomerToCache(created);
      }
      return created;
    } on AppException {
      if (remoteOnly) rethrow;
      // Offline customer creation
      if (_cache != null && _queue != null) {
        final localId = _uuid.v4();
        final localCustomer = {
          'id': localId,
          'name': body['name'] ?? '',
          'phone': body['phone'],
          'email': body['email'],
          'currentDebtBalance': 0.0,
          'creditLimit': body['creditLimit'] ?? 0.0,
          'isOfflinePending': true,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        };

        // Cache locally immediately so POS can use it
        await _cache!.save('customer_$localId', localCustomer);
        await _appendCustomerToCache(localCustomer);

        // Queue for background sync
        final tenantId = _tenantIdOf != null
            ? (await _tenantIdOf!()) ?? 'unknown'
            : 'unknown';
        final branchId =
            _branchIdOf != null ? (await _branchIdOf!()) ?? tenantId : tenantId;
        final deviceId = _deviceIdOf != null ? await _deviceIdOf!() : '';

        await _queue!.enqueue(
          operationId: localId,
          tenantId: tenantId,
          branchId: branchId,
          deviceId: deviceId,
          operationType: 'customer.create',
          aggregateType: 'customer',
          aggregateId: localId,
          payload: jsonEncode(body),
        );

        return localCustomer;
      }
      rethrow;
    }
  }

  Future<void> _appendCustomerToCache(Map<String, dynamic> customer) async {
    if (_cache == null) return;
    try {
      final listCached = await _cache!.load(_cacheKey);
      final items = (listCached?['items'] as List<dynamic>? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((raw) => Map<String, dynamic>.from(raw))
          .toList();
      items.removeWhere((c) => c['id'] == customer['id']);
      items.insert(0, customer);
      await _cache!.save(_cacheKey, {
        'items': items,
        'total': items.length,
      });
    } catch (_) {}
  }

  Future<Map<String, dynamic>> update(
      String id, Map<String, dynamic> body) async {
    final response = await _apiClient.put<dynamic>(
      '/api/v1/customers/$id',
      body: body,
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    final updated = Map<String, dynamic>.from(response.data as Map);
    if (_cache != null) {
      await _cache!.save('customer_$id', updated);
      await _appendCustomerToCache(updated);
    }
    return updated;
  }

  Future<Map<String, dynamic>?> getCredit(String customerId) async {
    try {
      final response = await _apiClient.get<dynamic>(
        '/api/v1/customers/$customerId/credit',
      );
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      final data = Map<String, dynamic>.from(response.data as Map);
      if (_cache != null) {
        await _cache!.save('customer_credit_$customerId', data);
      }
      return data;
    } on AppException {
      if (_cache != null) {
        final cached = await _cache!.load('customer_credit_$customerId');
        if (cached != null) return cached;

        final cust = await _cache!.load('customer_$customerId');
        if (cust != null) {
          return {
            'customerId': customerId,
            'currentDebtBalance': cust['currentDebtBalance'] ?? 0.0,
            'creditLimit': cust['creditLimit'] ?? 0.0,
          };
        }
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getOutstandingCredit() async {
    try {
      final response = await _apiClient.get<dynamic>(
        '/api/v1/credit/outstanding',
      );
      if (response.statusCode != 200 || response.data is! List) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      final list = (response.data as List)
          .whereType<Map<dynamic, dynamic>>()
          .map((raw) => Map<String, dynamic>.from(raw))
          .toList();
      if (_cache != null) {
        await _cache!.save('outstanding_credit_list', {'items': list});
      }
      return list;
    } on AppException {
      if (_cache != null) {
        final cached = await _cache!.load('outstanding_credit_list');
        if (cached != null) {
          return (cached['items'] as List<dynamic>? ?? const [])
              .whereType<Map<dynamic, dynamic>>()
              .map((raw) => Map<String, dynamic>.from(raw))
              .toList();
        }
        final listCached = await _cache!.load(_cacheKey);
        if (listCached != null) {
          final items = (listCached['items'] as List<dynamic>? ?? const [])
              .whereType<Map<dynamic, dynamic>>()
              .map((raw) => Map<String, dynamic>.from(raw));
          return items
              .where(
                  (c) => ((c['currentDebtBalance'] as num?)?.toDouble() ?? 0) > 0)
              .toList();
        }
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> recordPayment(
    String customerId,
    double amount,
    String description, {
    bool remoteOnly = false,
  }) async {
    try {
      final response = await _apiClient.post<dynamic>(
        '/api/v1/customers/$customerId/credit/payment',
        body: {'amount': amount, 'description': description},
      );
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      return Map<String, dynamic>.from(response.data as Map);
    } on AppException {
      if (remoteOnly) rethrow;
      // Offline debt payment fallback
      if (_queue != null) {
        final paymentId = _uuid.v4();
        final tenantId = _tenantIdOf != null
            ? (await _tenantIdOf!()) ?? 'unknown'
            : 'unknown';
        final branchId =
            _branchIdOf != null ? (await _branchIdOf!()) ?? tenantId : tenantId;
        final deviceId = _deviceIdOf != null ? await _deviceIdOf!() : '';

        await _queue!.enqueue(
          operationId: paymentId,
          tenantId: tenantId,
          branchId: branchId,
          deviceId: deviceId,
          operationType: 'customer.debt_payment',
          aggregateType: 'customer',
          aggregateId: customerId,
          payload: jsonEncode({
            'customerId': customerId,
            'amount': amount,
            'description': description,
            'recordedAt': DateTime.now().toUtc().toIso8601String(),
          }),
        );

        if (_cache != null) {
          final cust = await _cache!.load('customer_$customerId');
          if (cust != null) {
            final currentDebt =
                (cust['currentDebtBalance'] as num?)?.toDouble() ?? 0.0;
            cust['currentDebtBalance'] =
                (currentDebt - amount).clamp(0.0, double.infinity);
            await _cache!.save('customer_$customerId', cust);
            await _appendCustomerToCache(cust);
          }
        }

        return {
          'id': paymentId,
          'customerId': customerId,
          'amount': amount,
          'description': description,
          'status': 'offline_pending',
        };
      }
      rethrow;
    }
  }
}
