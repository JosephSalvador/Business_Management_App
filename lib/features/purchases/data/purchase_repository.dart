import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_routes.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/storage/offline_cache_dao.dart';
import '../../../core/storage/sync_queue_dao.dart';

class PurchaseRepository {
  PurchaseRepository({
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

  static const _cacheKey = 'purchases_list';

  Future<PagedPurchases> list({
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
        ApiRoutes.v1('/purchase-orders'),
        query: query,
      );
      final paged = _decodePage(response);
      if (_cache != null && search == null && page == 1) {
        await _cache.save(_cacheKey, {
          'items': paged.items,
          'total': paged.total,
        });
        for (final p in paged.items) {
          final id = p['id']?.toString();
          if (id != null) {
            await _cache.save('purchase_$id', p);
          }
        }
      }
      return paged;
    } on AppException {
      var items = <Map<String, dynamic>>[];

      if (_cache != null) {
        final cached = await _cache.load(_cacheKey);
        if (cached != null) {
          items = (cached['items'] as List<dynamic>? ?? const [])
              .whereType<Map<dynamic, dynamic>>()
              .map((raw) => Map<String, dynamic>.from(raw))
              .toList();
        }
      }

      if (_queue != null) {
        try {
          final pendingOps =
              await _queue.listByOperationType('purchase.create');
          for (final op in pendingOps) {
            try {
              final decoded = jsonDecode(op.payload);
              if (decoded is Map<String, dynamic>) {
                final id = decoded['id']?.toString() ?? op.aggregateId;
                if (!items.any((p) => p['id']?.toString() == id)) {
                  items.insert(0, {
                    ...decoded,
                    'id': id,
                    'orderNumber': decoded['orderNumber'] ??
                        'PO-OFFLINE-${id.substring(0, 6).toUpperCase()}',
                    'status': 0,
                    'isOfflinePending': true,
                  });
                }
              }
            } catch (_) {}
          }
        } catch (_) {}
      }

      if (search != null && search.trim().isNotEmpty) {
        final term = search.trim().toLowerCase();
        items = items.where((p) {
          final number = (p['orderNumber'] ?? '').toString().toLowerCase();
          final supplier = (p['supplierName'] ?? '').toString().toLowerCase();
          return number.contains(term) || supplier.contains(term);
        }).toList();
      }

      return PagedPurchases(items: items, total: items.length);
    }
  }

  Future<Map<String, dynamic>> getById(String id) async {
    try {
      final response = await _apiClient.get<dynamic>(
        ApiRoutes.v1('/purchase-orders/$id'),
      );
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      final data = Map<String, dynamic>.from(response.data as Map);
      if (_cache != null) {
        await _cache.save('purchase_$id', data);
      }
      return data;
    } on AppException {
      if (_cache != null) {
        final cached = await _cache.load('purchase_$id');
        if (cached != null) return cached;
        final listCached = await _cache.load(_cacheKey);
        if (listCached != null) {
          final items = (listCached['items'] as List<dynamic>? ?? const [])
              .whereType<Map<dynamic, dynamic>>()
              .map((raw) => Map<String, dynamic>.from(raw));
          final found = items.where((p) => p['id']?.toString() == id);
          if (found.isNotEmpty) return found.first;
        }
      }

      if (_queue != null) {
        try {
          final pendingOps =
              await _queue.listByOperationType('purchase.create');
          for (final op in pendingOps) {
            try {
              final decoded = jsonDecode(op.payload);
              if (decoded is Map<String, dynamic> &&
                  (decoded['id'] == id || op.aggregateId == id)) {
                return {...decoded, 'id': id, 'isOfflinePending': true};
              }
            } catch (_) {}
          }
        } catch (_) {}
      }

      return {'id': id, 'orderNumber': 'PO-$id', 'isOfflinePending': true};
    }
  }

  Future<void> create(
    Map<String, dynamic> body, {
    String? id,
    bool remoteOnly = false,
  }) async {
    final localId = id ?? body['id']?.toString() ?? _uuid.v4();
    final enrichedBody = Map<String, dynamic>.from(body)..['id'] = localId;

    try {
      await _apiClient.post<dynamic>(
        ApiRoutes.v1('/purchase-orders'),
        body: enrichedBody,
        headers: {'Idempotency-Key': localId},
      );
    } on AppException {
      if (remoteOnly) rethrow;

      final localOrder = {
        'id': localId,
        'orderNumber': 'PO-OFFLINE-${localId.substring(0, 6).toUpperCase()}',
        'supplierId': body['supplierId'],
        'warehouseId': body['warehouseId'],
        'status': 0, // draft
        'orderDate': DateTime.now().toUtc().toIso8601String(),
        'items': body['items'] ?? [],
        'isOfflinePending': true,
      };

      if (_cache != null) {
        await _cache.save('purchase_$localId', localOrder);
        await _appendPurchaseToCache(localOrder);
      }

      if (_queue != null) {
        final tenantId = _tenantIdOf != null
            ? (await _tenantIdOf()) ?? 'unknown'
            : 'unknown';
        final branchId =
            _branchIdOf != null ? (await _branchIdOf()) ?? tenantId : tenantId;
        final deviceId = _deviceIdOf != null ? await _deviceIdOf() : '';

        await _queue.enqueue(
          operationId: localId,
          tenantId: tenantId,
          branchId: branchId,
          deviceId: deviceId,
          operationType: 'purchase.create',
          aggregateType: 'purchase',
          aggregateId: localId,
          payload: jsonEncode(enrichedBody),
        );
      }
    }
  }

  Future<void> _appendPurchaseToCache(Map<String, dynamic> order) async {
    if (_cache == null) return;
    try {
      final listCached = await _cache.load(_cacheKey);
      final items = (listCached?['items'] as List<dynamic>? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((raw) => Map<String, dynamic>.from(raw))
          .toList();
      items.removeWhere((p) => p['id'] == order['id']);
      items.insert(0, order);
      await _cache.save(_cacheKey, {
        'items': items,
        'total': items.length,
      });
    } catch (_) {}
  }

  Future<void> submit(String id, {bool remoteOnly = false}) async {
    try {
      await _apiClient.post<dynamic>(
        ApiRoutes.v1('/purchase-orders/$id/submit'),
      );
    } on AppException {
      if (remoteOnly) rethrow;
      if (_cache != null) {
        final cached = await _cache.load('purchase_$id');
        if (cached != null) {
          final updated = Map<String, dynamic>.from(cached)..['status'] = 1;
          await _cache.save('purchase_$id', updated);
          await _appendPurchaseToCache(updated);
        }
      }
      if (_queue != null) {
        final tenantId = _tenantIdOf != null
            ? (await _tenantIdOf()) ?? 'unknown'
            : 'unknown';
        final branchId =
            _branchIdOf != null ? (await _branchIdOf()) ?? tenantId : tenantId;
        final deviceId = _deviceIdOf != null ? await _deviceIdOf() : '';
        await _queue.enqueue(
          operationId: _uuid.v4(),
          tenantId: tenantId,
          branchId: branchId,
          deviceId: deviceId,
          operationType: 'purchase.submit',
          aggregateType: 'purchase',
          aggregateId: id,
          payload: jsonEncode({'id': id}),
        );
      }
    }
  }

  Future<void> cancel(String id, {bool remoteOnly = false}) async {
    try {
      await _apiClient.post<dynamic>(
        ApiRoutes.v1('/purchase-orders/$id/cancel'),
      );
    } on AppException {
      if (remoteOnly) rethrow;
      if (_cache != null) {
        final cached = await _cache.load('purchase_$id');
        if (cached != null) {
          final updated = Map<String, dynamic>.from(cached)..['status'] = 3;
          await _cache.save('purchase_$id', updated);
          await _appendPurchaseToCache(updated);
        }
      }
      if (_queue != null) {
        final tenantId = _tenantIdOf != null
            ? (await _tenantIdOf()) ?? 'unknown'
            : 'unknown';
        final branchId =
            _branchIdOf != null ? (await _branchIdOf()) ?? tenantId : tenantId;
        final deviceId = _deviceIdOf != null ? await _deviceIdOf() : '';
        await _queue.enqueue(
          operationId: _uuid.v4(),
          tenantId: tenantId,
          branchId: branchId,
          deviceId: deviceId,
          operationType: 'purchase.cancel',
          aggregateType: 'purchase',
          aggregateId: id,
          payload: jsonEncode({'id': id}),
        );
      }
    }
  }

  Future<PagedSuppliers> suppliers({
    int page = 1,
    int pageSize = 100,
  }) async {
    try {
      final response = await _apiClient.get<dynamic>(
        ApiRoutes.v1('/suppliers'),
        query: {'page': page, 'pageSize': pageSize},
      );
      final paged = _decodeSuppliers(response);
      if (_cache != null) {
        await _cache.save('suppliers_list', {
          'items': paged.items,
          'total': paged.total,
        });
      }
      return paged;
    } on AppException {
      if (_cache != null) {
        final cached = await _cache.load('suppliers_list');
        if (cached != null) {
          final items = (cached['items'] as List<dynamic>? ?? const [])
              .whereType<Map<dynamic, dynamic>>()
              .map((raw) => Map<String, dynamic>.from(raw))
              .toList();
          return PagedSuppliers(items: items, total: items.length);
        }
      }
      return const PagedSuppliers(items: [], total: 0);
    }
  }

  Future<List<Map<String, dynamic>>> warehouses() async {
    try {
      final response = await _apiClient.get<dynamic>(
        ApiRoutes.v1('/warehouses'),
      );
      if (response.statusCode != 200 || response.data is! List) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      final list = (response.data as List<dynamic>)
          .whereType<Map<dynamic, dynamic>>()
          .map((raw) => Map<String, dynamic>.from(raw))
          .toList(growable: false);
      if (_cache != null) {
        await _cache.save('warehouses_list', {'items': list});
      }
      return list;
    } on AppException {
      if (_cache != null) {
        final cached = await _cache.load('warehouses_list');
        if (cached != null) {
          final items = (cached['items'] as List<dynamic>? ?? const [])
              .whereType<Map<dynamic, dynamic>>()
              .map((raw) => Map<String, dynamic>.from(raw))
              .toList(growable: false);
          if (items.isNotEmpty) return items;
        }
      }
      return const [
        {'id': 'default', 'name': 'Stoo Kuu'}
      ];
    }
  }

  PagedPurchases _decodePage(dynamic response) {
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    final doc = Map<String, dynamic>.from(response.data as Map);
    final items = (doc['items'] as List<dynamic>? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .toList(growable: false);
    return PagedPurchases(
      items: items,
      total: (doc['total'] as num?)?.toInt() ?? items.length,
    );
  }

  PagedSuppliers _decodeSuppliers(dynamic response) {
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    final doc = Map<String, dynamic>.from(response.data as Map);
    final items = (doc['items'] as List<dynamic>? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .toList(growable: false);
    return PagedSuppliers(
      items: items,
      total: (doc['total'] as num?)?.toInt() ?? items.length,
    );
  }
}

class PagedPurchases {
  const PagedPurchases({required this.items, required this.total});

  final List<Map<String, dynamic>> items;
  final int total;
}

class PagedSuppliers {
  const PagedSuppliers({required this.items, required this.total});

  final List<Map<String, dynamic>> items;
  final int total;
}
