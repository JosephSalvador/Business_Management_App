import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_routes.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/storage/offline_cache_dao.dart';
import '../../../core/storage/sync_queue_dao.dart';
import '../domain/delivery_note.dart';

class DeliveryNoteRepository {
  DeliveryNoteRepository({
    required ApiClient apiClient,
    OfflineCacheDao? cache,
    SyncQueueDao? queue,
    Future<String?> Function()? tenantIdOf,
    Future<String?> Function()? branchIdOf,
    Future<String> Function()? deviceIdOf,
  })  : _apiClient = apiClient,
        _cache = cache,
        _queue = queue,
        _tenantIdOf = tenantIdOf,
        _branchIdOf = branchIdOf,
        _deviceIdOf = deviceIdOf;

  final ApiClient _apiClient;
  final OfflineCacheDao? _cache;
  final SyncQueueDao? _queue;
  final Future<String?> Function()? _tenantIdOf;
  final Future<String?> Function()? _branchIdOf;
  final Future<String> Function()? _deviceIdOf;
  static const _uuid = Uuid();
  static const _cacheKey = 'delivery_notes_list';

  Future<DeliveryNotePage> list({
    int page = 1,
    int pageSize = 20,
    DeliveryNoteStatus? status,
    String? search,
  }) async {
    final localList = await _loadOfflineList(status: status, search: search);

    try {
      final response = await _apiClient.get<dynamic>(
        ApiRoutes.v1('/delivery-notes'),
        query: <String, dynamic>{
          'page': page,
          'pageSize': pageSize,
          if (status != null) 'status': status.code,
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
        },
      );
      if (response.statusCode != 200 || response.data is! Map) {
        return localList;
      }
      final doc = Map<String, dynamic>.from(response.data as Map);
      final rawItems = doc['items'];
      final serverItems = rawItems is List
          ? rawItems
              .whereType<Map<dynamic, dynamic>>()
              .map((raw) => DeliveryNoteSummary.fromJson(
                  Map<String, dynamic>.from(raw)))
              .toList(growable: false)
          : <DeliveryNoteSummary>[];

      final mergedItems = await _mergeWithCachedList(
        serverItems,
        status: status,
        search: search,
      );

      final notePage = DeliveryNotePage(
        items: mergedItems,
        total: (doc['total'] as num?)?.toInt() ?? mergedItems.length,
        page: (doc['page'] as num?)?.toInt() ?? page,
      );
      if (_cache != null &&
          page == 1 &&
          (search == null || search.isEmpty) &&
          status == null) {
        await _cache.save(_cacheKey, {
          'items': mergedItems.map((i) => i.toJson()).toList(),
          'total': notePage.total,
        });
      }
      return notePage;
    } on AppException {
      return localList;
    } catch (_) {
      return localList;
    }
  }

  Future<DeliveryNote> getById(String id) async {
    if (_cache != null) {
      final cached = await _cache.load('delivery_note_$id');
      if (cached != null) {
        _backgroundRefresh(id);
        return DeliveryNote.fromJson(cached);
      }
    }

    try {
      final response =
          await _apiClient.get<dynamic>(ApiRoutes.v1('/delivery-notes/$id'));
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Waraka wa usafirishaji haupatikani.');
      }
      final note = DeliveryNote.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      if (_cache != null) {
        await _cache.save('delivery_note_$id', note.toJson());
      }
      return note;
    } on AppException {
      if (_cache != null) {
        final cached = await _cache.load('delivery_note_$id');
        if (cached != null) {
          return DeliveryNote.fromJson(cached);
        }
      }
      rethrow;
    }
  }

  void _backgroundRefresh(String id) async {
    try {
      final response =
          await _apiClient.get<dynamic>(ApiRoutes.v1('/delivery-notes/$id'));
      if (response.statusCode == 200 && response.data is Map) {
        final note = DeliveryNote.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
        if (_cache != null) {
          await _cache.save('delivery_note_$id', note.toJson());
        }
      }
    } catch (_) {}
  }

  Future<DeliveryNote> create({
    required String customerName,
    required List<DeliveryNoteItem> items,
    String? invoiceId,
    String? customerId,
    String? customerPhone,
    String? customerAddress,
    String? deliveryAddress,
    String? carrierName,
    String? trackingNumber,
    String? vehicleNumber,
    String? driverName,
    String? driverPhone,
    String? notes,
    DateTime? issueDate,
  }) async {
    final clientId = _uuid.v4();
    final now = DateTime.now();
    final issued = issueDate ?? now;

    final localNumberSeq =
        'DN-${issued.year}${issued.month.toString().padLeft(2, '0')}-${(now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0')}';

    final localNote = DeliveryNote(
      id: clientId,
      number: localNumberSeq,
      customerName: customerName.trim(),
      issueDate: issued,
      status: DeliveryNoteStatus.draft,
      items: items,
      invoiceId: invoiceId,
      customerId: customerId,
      customerPhone: customerPhone?.trim(),
      customerAddress: customerAddress?.trim(),
      deliveryAddress: deliveryAddress?.trim(),
      carrierName: carrierName?.trim(),
      trackingNumber: trackingNumber?.trim(),
      vehicleNumber: vehicleNumber?.trim(),
      driverName: driverName?.trim(),
      driverPhone: driverPhone?.trim(),
      notes: notes?.trim(),
      isSynced: false,
    );

    // 1. Persist locally to Drift SQLite storage immediately
    await _persistLocally(localNote);

    // 2. Prepare payload
    final payload = <String, dynamic>{
      'id': clientId,
      'customerName': customerName.trim(),
      'issueDate': issued.toUtc().toIso8601String(),
      if (invoiceId != null && invoiceId.isNotEmpty) 'invoiceId': invoiceId,
      if (customerId != null && customerId.isNotEmpty) 'customerId': customerId,
      if (customerPhone != null && customerPhone.trim().isNotEmpty)
        'customerPhone': customerPhone.trim(),
      if (customerAddress != null && customerAddress.trim().isNotEmpty)
        'customerAddress': customerAddress.trim(),
      if (deliveryAddress != null && deliveryAddress.trim().isNotEmpty)
        'deliveryAddress': deliveryAddress.trim(),
      if (carrierName != null && carrierName.trim().isNotEmpty)
        'carrierName': carrierName.trim(),
      if (trackingNumber != null && trackingNumber.trim().isNotEmpty)
        'trackingNumber': trackingNumber.trim(),
      if (vehicleNumber != null && vehicleNumber.trim().isNotEmpty)
        'vehicleNumber': vehicleNumber.trim(),
      if (driverName != null && driverName.trim().isNotEmpty)
        'driverName': driverName.trim(),
      if (driverPhone != null && driverPhone.trim().isNotEmpty)
        'driverPhone': driverPhone.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'items': [for (final item in items) item.toJson()],
    };

    // 3. Enqueue into persistent SyncQueue
    if (_queue != null) {
      try {
        final tenantId = (await _tenantIdOf?.call()) ?? 'tenant';
        final branchId = (await _branchIdOf?.call()) ?? 'branch';
        final deviceId = (await _deviceIdOf?.call()) ?? 'device';

        await _queue.enqueue(
          operationId: clientId,
          tenantId: tenantId,
          branchId: branchId,
          deviceId: deviceId,
          operationType: 'delivery_note.create',
          aggregateType: 'DeliveryNote',
          aggregateId: clientId,
          payload: jsonEncode(payload),
        );
      } catch (_) {}
    }

    // 4. Asynchronously attempt remote sync
    try {
      final response = await _apiClient.post<dynamic>(
        ApiRoutes.v1('/delivery-notes'),
        body: payload,
        headers: {'Idempotency-Key': clientId},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data is Map) {
          final serverNote = DeliveryNote.fromJson(
            Map<String, dynamic>.from(response.data as Map),
          );
          final syncedNote = serverNote.copyWith(isSynced: true);
          await _persistLocally(syncedNote);
          if (_queue != null) {
            await _queue.markSynced(clientId, serverNote.number);
          }
          return syncedNote;
        }
      }
    } catch (_) {
      // Offline fallback: returns local immediately
    }

    return localNote;
  }

  Future<DeliveryNote> dispatch(
    String id, {
    String? carrierName,
    String? trackingNumber,
    String? vehicleNumber,
    String? driverName,
    String? driverPhone,
  }) async {
    DeliveryNote? localCurrent;
    if (_cache != null) {
      final cached = await _cache.load('delivery_note_$id');
      if (cached != null) {
        localCurrent = DeliveryNote.fromJson(cached);
        final updated = localCurrent.copyWith(
          status: DeliveryNoteStatus.dispatched,
          dispatchedAt: DateTime.now(),
          isSynced: false,
        );
        await _persistLocally(updated);
      }
    }

    try {
      final response = await _apiClient.post<dynamic>(
        ApiRoutes.v1('/delivery-notes/$id/dispatch'),
        body: <String, dynamic>{
          if (carrierName != null) 'carrierName': carrierName,
          if (trackingNumber != null) 'trackingNumber': trackingNumber,
          if (vehicleNumber != null) 'vehicleNumber': vehicleNumber,
          if (driverName != null) 'driverName': driverName,
          if (driverPhone != null) 'driverPhone': driverPhone,
        },
      );
      if (response.statusCode == 200 && response.data is Map) {
        final serverUpdated = DeliveryNote.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        ).copyWith(isSynced: true);
        await _persistLocally(serverUpdated);
        return serverUpdated;
      }
    } catch (_) {}

    if (localCurrent != null) {
      final cached = await _cache?.load('delivery_note_$id');
      if (cached != null) return DeliveryNote.fromJson(cached);
    }
    throw ServerException('Waraka haukuweza kusafirishwa.');
  }

  Future<DeliveryNote> deliver(
    String id, {
    String? recipientName,
    String? recipientSignature,
  }) async {
    DeliveryNote? localCurrent;
    if (_cache != null) {
      final cached = await _cache.load('delivery_note_$id');
      if (cached != null) {
        localCurrent = DeliveryNote.fromJson(cached);
        final updated = localCurrent.copyWith(
          status: DeliveryNoteStatus.delivered,
          deliveredAt: DateTime.now(),
          recipientName: recipientName,
          recipientSignature: recipientSignature,
          isSynced: false,
        );
        await _persistLocally(updated);
      }
    }

    try {
      final response = await _apiClient.post<dynamic>(
        ApiRoutes.v1('/delivery-notes/$id/deliver'),
        body: <String, dynamic>{
          if (recipientName != null) 'recipientName': recipientName,
          if (recipientSignature != null)
            'recipientSignature': recipientSignature,
        },
      );
      if (response.statusCode == 200 && response.data is Map) {
        final serverUpdated = DeliveryNote.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        ).copyWith(isSynced: true);
        await _persistLocally(serverUpdated);
        return serverUpdated;
      }
    } catch (_) {}

    if (localCurrent != null) {
      final cached = await _cache?.load('delivery_note_$id');
      if (cached != null) return DeliveryNote.fromJson(cached);
    }
    throw ServerException('Waraka haukuweza kuthibitishwa kufika.');
  }

  Future<DeliveryNote> cancel(String id) async {
    DeliveryNote? localCurrent;
    if (_cache != null) {
      final cached = await _cache.load('delivery_note_$id');
      if (cached != null) {
        localCurrent = DeliveryNote.fromJson(cached);
        final updated = localCurrent.copyWith(
          status: DeliveryNoteStatus.cancelled,
          isSynced: false,
        );
        await _persistLocally(updated);
      }
    }

    try {
      final response = await _apiClient.post<dynamic>(
        ApiRoutes.v1('/delivery-notes/$id/cancel'),
      );
      if (response.statusCode == 200 && response.data is Map) {
        final serverUpdated = DeliveryNote.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        ).copyWith(isSynced: true);
        await _persistLocally(serverUpdated);
        return serverUpdated;
      }
    } catch (_) {}

    if (localCurrent != null) {
      final cached = await _cache?.load('delivery_note_$id');
      if (cached != null) return DeliveryNote.fromJson(cached);
    }
    throw ServerException('Waraka haukuweza kufutwa.');
  }

  Future<List<DeliveryNote>> listUnsynced() async {
    if (_cache == null) return [];
    final listDoc = await _cache.load(_cacheKey);
    if (listDoc == null || listDoc['items'] is! List) return [];
    final unsynced = <DeliveryNote>[];
    for (final raw in (listDoc['items'] as List)) {
      if (raw is Map) {
        try {
          final summary =
              DeliveryNoteSummary.fromJson(Map<String, dynamic>.from(raw));
          if (!summary.isSynced) {
            final full = await _cache.load('delivery_note_${summary.id}');
            if (full != null) {
              unsynced.add(DeliveryNote.fromJson(full));
            }
          }
        } catch (_) {}
      }
    }
    return unsynced;
  }

  Future<void> markSynced(String id, {String? serverNumber}) async {
    if (_cache == null) return;
    final cached = await _cache.load('delivery_note_$id');
    if (cached != null) {
      final current = DeliveryNote.fromJson(cached);
      final updated = DeliveryNote(
        id: current.id,
        number: serverNumber ?? current.number,
        customerName: current.customerName,
        issueDate: current.issueDate,
        status: current.status,
        items: current.items,
        tenantId: current.tenantId,
        invoiceId: current.invoiceId,
        customerId: current.customerId,
        customerPhone: current.customerPhone,
        customerAddress: current.customerAddress,
        deliveryAddress: current.deliveryAddress,
        carrierName: current.carrierName,
        trackingNumber: current.trackingNumber,
        vehicleNumber: current.vehicleNumber,
        driverName: current.driverName,
        driverPhone: current.driverPhone,
        dispatchedAt: current.dispatchedAt,
        deliveredAt: current.deliveredAt,
        notes: current.notes,
        recipientName: current.recipientName,
        recipientSignature: current.recipientSignature,
        isSynced: true,
      );
      await _persistLocally(updated);
    }
  }

  Future<void> _persistLocally(DeliveryNote note) async {
    if (_cache == null) return;
    await _cache.save('delivery_note_${note.id}', note.toJson());
    final listDoc = await _cache.load(_cacheKey);
    final existing = <DeliveryNoteSummary>[];
    if (listDoc != null && listDoc['items'] is List) {
      for (final raw in (listDoc['items'] as List)) {
        if (raw is Map) {
          try {
            existing.add(
              DeliveryNoteSummary.fromJson(Map<String, dynamic>.from(raw)),
            );
          } catch (_) {}
        }
      }
    }
    final summary = note.toSummary();
    final idx = existing.indexWhere((n) => n.id == note.id);
    if (idx >= 0) {
      existing[idx] = summary;
    } else {
      existing.insert(0, summary);
    }
    await _cache.save(_cacheKey, {
      'items': existing.map((n) => n.toJson()).toList(),
      'total': existing.length,
    });
  }

  Future<List<DeliveryNoteSummary>> _mergeWithCachedList(
    List<DeliveryNoteSummary> serverItems, {
    DeliveryNoteStatus? status,
    String? search,
  }) async {
    if (_cache == null) return serverItems;
    final listDoc = await _cache.load(_cacheKey);
    if (listDoc == null || listDoc['items'] is! List) return serverItems;
    final serverIds = {for (final item in serverItems) item.id};
    final localOnly = <DeliveryNoteSummary>[];
    for (final raw in (listDoc['items'] as List)) {
      if (raw is Map) {
        try {
          final item =
              DeliveryNoteSummary.fromJson(Map<String, dynamic>.from(raw));
          if (!serverIds.contains(item.id)) {
            localOnly.add(item);
          }
        } catch (_) {}
      }
    }
    final combined = [...localOnly, ...serverItems];
    return _filterList(combined, status: status, search: search);
  }

  Future<DeliveryNotePage> _loadOfflineList({
    DeliveryNoteStatus? status,
    String? search,
  }) async {
    if (_cache != null) {
      final cached = await _cache.load(_cacheKey);
      if (cached != null && cached['items'] is List) {
        final items = (cached['items'] as List)
            .whereType<Map<dynamic, dynamic>>()
            .map((raw) =>
                DeliveryNoteSummary.fromJson(Map<String, dynamic>.from(raw)))
            .toList(growable: false);
        final filtered = _filterList(items, status: status, search: search);
        return DeliveryNotePage(items: filtered, total: filtered.length, page: 1);
      }
    }
    return const DeliveryNotePage(items: [], total: 0, page: 1);
  }

  List<DeliveryNoteSummary> _filterList(
    List<DeliveryNoteSummary> items, {
    DeliveryNoteStatus? status,
    String? search,
  }) {
    var result = items;
    if (status != null) {
      result = result.where((n) => n.status == status).toList();
    }
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      result = result
          .where((n) =>
              n.number.toLowerCase().contains(q) ||
              n.customerName.toLowerCase().contains(q) ||
              (n.carrierName?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return result;
  }
}
