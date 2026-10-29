import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_routes.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/storage/offline_cache_dao.dart';
import '../../../core/storage/sync_queue_dao.dart';

class SupplierRepository {
  SupplierRepository({
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

  static const _cacheKey = 'suppliers_list';

  Future<PagedSuppliers> list({
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
        ApiRoutes.v1('/suppliers'),
        query: query,
      );
      final paged = _decodePage(response);
      if (_cache != null && search == null && page == 1) {
        await _cache.save(_cacheKey, {
          'items': paged.items,
          'total': paged.total,
        });
        for (final s in paged.items) {
          final id = s['id']?.toString();
          if (id != null) {
            await _cache.save('supplier_$id', s);
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
              await _queue.listByOperationType('supplier.create');
          for (final op in pendingOps) {
            try {
              final decoded = jsonDecode(op.payload);
              if (decoded is Map<String, dynamic>) {
                final id = decoded['id']?.toString() ?? op.aggregateId;
                if (!items.any((s) => s['id']?.toString() == id)) {
                  items.insert(0, {
                    ...decoded,
                    'id': id,
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
        items = items.where((s) {
          final name = (s['name'] ?? '').toString().toLowerCase();
          final phone = (s['phone'] ?? '').toString().toLowerCase();
          return name.contains(term) || phone.contains(term);
        }).toList();
      }

      return PagedSuppliers(items: items, total: items.length);
    }
  }

  Future<Map<String, dynamic>> getById(String id) async {
    try {
      final response = await _apiClient.get<dynamic>(
        ApiRoutes.v1('/suppliers/$id'),
      );
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      final data = Map<String, dynamic>.from(response.data as Map);
      if (_cache != null) {
        await _cache.save('supplier_$id', data);
      }
      return data;
    } on AppException {
      if (_cache != null) {
        final cached = await _cache.load('supplier_$id');
        if (cached != null) return cached;
        final listCached = await _cache.load(_cacheKey);
        if (listCached != null) {
          final items = (listCached['items'] as List<dynamic>? ?? const [])
              .whereType<Map<dynamic, dynamic>>()
              .map((raw) => Map<String, dynamic>.from(raw));
          final found = items.where((s) => s['id']?.toString() == id);
          if (found.isNotEmpty) return found.first;
        }
      }

      if (_queue != null) {
        try {
          final pendingOps =
              await _queue.listByOperationType('supplier.create');
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

      return {'id': id, 'name': 'Msambazaji', 'isOfflinePending': true};
    }
  }

  Future<Map<String, dynamic>> create(
    Map<String, dynamic> body, {
    String? id,
    bool remoteOnly = false,
  }) async {
    final localId = id ?? body['id']?.toString() ?? _uuid.v4();
    final enrichedBody = Map<String, dynamic>.from(body)..['id'] = localId;

    try {
      final response = await _apiClient.post<dynamic>(
        ApiRoutes.v1('/suppliers'),
        body: enrichedBody,
        headers: {'Idempotency-Key': localId},
      );
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      final created = Map<String, dynamic>.from(response.data as Map);
      if (_cache != null) {
        await _cache.save('supplier_${created['id']}', created);
        await _appendSupplierToCache(created);
      }
      return created;
    } on AppException catch (e) {
      if (remoteOnly ||
          e is ValidationException ||
          e is ConflictException ||
          e is NotFoundException ||
          e is UnauthorizedException) {
        rethrow;
      }

      final localSupplier = {
        'id': localId,
        'name': body['name'] ?? '',
        'contactPerson': body['contactPerson'],
        'phone': body['phone'],
        'email': body['email'],
        'address': body['address'],
        'isOfflinePending': true,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      };

      if (_cache != null) {
        await _cache.save('supplier_$localId', localSupplier);
        await _appendSupplierToCache(localSupplier);
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
          operationType: 'supplier.create',
          aggregateType: 'supplier',
          aggregateId: localId,
          payload: jsonEncode(enrichedBody),
        );
      }

      return localSupplier;
    }
  }

  Future<void> _appendSupplierToCache(Map<String, dynamic> supplier) async {
    final cache = _cache;
    if (cache == null) return;
    try {
      final listCached = await cache.load(_cacheKey);
      final items = (listCached?['items'] as List<dynamic>? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((raw) => Map<String, dynamic>.from(raw))
          .toList();
      items.removeWhere((s) => s['id'] == supplier['id']);
      items.insert(0, supplier);
      await cache.save(_cacheKey, {
        'items': items,
        'total': items.length,
      });
    } catch (_) {}
  }

  Future<Map<String, dynamic>> update(
    String id,
    Map<String, dynamic> body, {
    bool remoteOnly = false,
  }) async {
    try {
      final response = await _apiClient.put<dynamic>(
        ApiRoutes.v1('/suppliers/$id'),
        body: body,
      );
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      final updated = Map<String, dynamic>.from(response.data as Map);
      if (_cache != null) {
        await _cache.save('supplier_$id', updated);
        await _appendSupplierToCache(updated);
      }
      return updated;
    } on AppException {
      if (remoteOnly) rethrow;

      final updated = {
        'id': id,
        ...body,
        'isOfflinePending': true,
      };

      if (_cache != null) {
        await _cache.save('supplier_$id', updated);
        await _appendSupplierToCache(updated);
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
          operationType: 'supplier.update',
          aggregateType: 'supplier',
          aggregateId: id,
          payload: jsonEncode({'id': id, ...body}),
        );
      }

      return updated;
    }
  }

  PagedSuppliers _decodePage(Response<dynamic> response) {
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

class PagedSuppliers {
  const PagedSuppliers({required this.items, required this.total});

  final List<Map<String, dynamic>> items;
  final int total;
}
