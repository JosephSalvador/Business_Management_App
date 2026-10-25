import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_routes.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/storage/offline_cache_dao.dart';
import '../../../core/storage/cached_catalog_dao.dart';
import '../../../core/storage/sync_queue_dao.dart';

class PurchaseRepository {
  PurchaseRepository({
    required ApiClient apiClient,
    OfflineCacheDao? cache,
    SyncQueueDao? queue,
    CachedCatalogDao? catalogDao,
    Future<String?> Function()? tenantIdOf,
    Future<String?> Function()? branchIdOf,
    Future<String> Function()? deviceIdOf,
    Uuid uuid = const Uuid(),
  })  : _apiClient = apiClient,
        _cache = cache,
        _queue = queue,
        _catalogDao = catalogDao,
        _tenantIdOf = tenantIdOf,
        _branchIdOf = branchIdOf,
        _deviceIdOf = deviceIdOf,
        _uuid = uuid;

  final ApiClient _apiClient;
  final OfflineCacheDao? _cache;
  final SyncQueueDao? _queue;
  final CachedCatalogDao? _catalogDao;
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
      if (_cache != null) {
        final cached = await _cache.load(_cacheKey);
        if (cached != null) {
          var items = (cached['items'] as List<dynamic>? ?? const [])
              .whereType<Map<dynamic, dynamic>>()
              .map((raw) => Map<String, dynamic>.from(raw))
              .toList();

          if (search != null && search.trim().isNotEmpty) {
            final term = search.trim().toLowerCase();
            items = items.where((p) {
              final number = (p['orderNumber'] ?? '').toString().toLowerCase();
              final supplier =
                  (p['supplierName'] ?? '').toString().toLowerCase();
              return number.contains(term) || supplier.contains(term);
            }).toList();
          }

          return PagedPurchases(items: items, total: items.length);
        }
      }
      rethrow;
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
      rethrow;
    }
  }

  Future<void> create(
    Map<String, dynamic> body, {
    bool remoteOnly = false,
  }) async {
    try {
      await _apiClient.post<dynamic>(
        ApiRoutes.v1('/purchase-orders'),
        body: body,
      );
    } on AppException {
      if (remoteOnly) rethrow;

      final localId = _uuid.v4();
      final localOrder = {
        'id': localId,
        'orderNumber': 'PO-OFFLINE-${localId.substring(0, 6).toUpperCase()}',
        'supplierId': body['supplierId'],
        'warehouseId': body['warehouseId'],
        'status': 0, // draft
        'orderDate': DateTime.now().toUtc().toIso8601String(),
        'lines': body['lines'] ?? [],
        'items': body['lines'] ?? [],
        'totalAmount': (body['lines'] as List<dynamic>? ?? const [])
            .whereType<Map<dynamic, dynamic>>()
            .fold<double>(
              0,
              (total, line) =>
                  total +
                  ((line['quantity'] as num?)?.toDouble() ?? 0) *
                      ((line['unitPrice'] as num?)?.toDouble() ?? 0),
            ),
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
          payload: jsonEncode(body),
        );
      }
      if (_catalogDao != null) {
        final tenantId = _tenantIdOf != null
            ? (await _tenantIdOf()) ?? 'unknown'
            : 'unknown';
        final warehouseId = body['warehouseId']?.toString() ?? '*';
        for (final rawLine in (body['lines'] as List<dynamic>? ?? const [])) {
          if (rawLine is! Map) continue;
          final productId = rawLine['productId']?.toString();
          final quantity = (rawLine['quantity'] as num?)?.toDouble();
          if (productId == null || quantity == null || quantity <= 0) continue;
          await _catalogDao.incrementCachedStock(
            tenantId: tenantId,
            productId: productId,
            warehouseId: warehouseId,
            quantity: quantity,
          );
        }
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

  Future<void> submit(String id) async {
    await _apiClient.post<dynamic>(
      ApiRoutes.v1('/purchase-orders/$id/submit'),
    );
  }

  Future<void> update(String id, Map<String, dynamic> body) async {
    await _apiClient.put<dynamic>(
      ApiRoutes.v1('/purchase-orders/$id'),
      body: body,
    );
  }

  Future<void> receive(String id) async {
    await _apiClient.post<dynamic>(
      ApiRoutes.v1('/purchase-orders/$id/receive'),
    );
  }

  Future<void> cancel(String id) async {
    await _apiClient.post<dynamic>(
      ApiRoutes.v1('/purchase-orders/$id/cancel'),
    );
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
      final pending = await _cachedPendingSuppliers();
      final serverIds = paged.items.map((item) => item['id']).toSet();
      final mergedItems = [
        ...pending.where((item) => !serverIds.contains(item['id'])),
        ...paged.items,
      ];
      if (_cache != null) {
        await _cache.save('suppliers_list', {
          'items': mergedItems,
          'total': mergedItems.length,
        });
      }
      return PagedSuppliers(items: mergedItems, total: mergedItems.length);
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

  Future<List<Map<String, dynamic>>> _cachedPendingSuppliers() async {
    if (_cache == null) return const [];
    final cached = await _cache.load('suppliers_list');
    final items = (cached?['items'] as List<dynamic>? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .where((item) => item['isOfflinePending'] == true)
        .toList(growable: false);
    return items;
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
