import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../../../core/storage/cached_catalog_dao.dart';
import '../../../core/storage/sync_queue_dao.dart';

/// Handles offline stock receiving ("Kupokea Mzigo") so that stock
/// is immediately available for selling on the POS without waiting for cloud sync.
class OfflineInventoryService {
  OfflineInventoryService({
    required CachedCatalogDao catalogDao,
    required SyncQueueDao queue,
    required Future<String?> Function() tenantIdOf,
    required Future<String?> Function() branchIdOf,
    required Future<String> Function() deviceIdOf,
    required Future<String?> Function() userIdOf,
    Uuid uuid = const Uuid(),
  })  : _catalogDao = catalogDao,
        _queue = queue,
        _tenantIdOf = tenantIdOf,
        _branchIdOf = branchIdOf,
        _deviceIdOf = deviceIdOf,
        _userIdOf = userIdOf,
        _uuid = uuid;

  final CachedCatalogDao _catalogDao;
  final SyncQueueDao _queue;
  final Future<String?> Function() _tenantIdOf;
  final Future<String?> Function() _branchIdOf;
  final Future<String> Function() _deviceIdOf;
  final Future<String?> Function() _userIdOf;
  final Uuid _uuid;

  /// Records inbound stock arrival locally:
  /// 1. Increments product balance in SQLite cached stock immediately.
  /// 2. Enqueues an `inventory.receive` operation for replay when online.
  Future<Map<String, dynamic>> recordOfflineInboundReceiving({
    required String productId,
    required String productName,
    required double quantity,
    String? warehouseId,
    String? notes,
  }) async {
    final tenantId = (await _tenantIdOf()) ?? 'unknown';
    final branchId = (await _branchIdOf()) ?? tenantId;
    final deviceId = await _deviceIdOf();
    final effectiveWarehouseId = warehouseId ?? '*';
    final operationId = _uuid.v4();
    final now = DateTime.now().toUtc();

    // 1. Immediately bump local cached stock so the POS can sell it right away
    await _catalogDao.incrementCachedStock(
      tenantId: tenantId,
      productId: productId,
      warehouseId: effectiveWarehouseId,
      quantity: quantity,
    );

    // 2. Queue for background cloud sync
    final payload = {
      'operationId': operationId,
      'productId': productId,
      'productName': productName,
      'warehouseId': effectiveWarehouseId,
      'adjustmentQuantity': quantity,
      'reason': 'Kupokea Mzigo Nje ya Mtandao (Inbound)',
      'notes': notes,
      'createdAt': now.toIso8601String(),
    };

    await _queue.enqueue(
      operationId: operationId,
      tenantId: tenantId,
      branchId: branchId,
      deviceId: deviceId,
      operationType: 'inventory.receive',
      aggregateType: 'inventory',
      aggregateId: productId,
      payload: jsonEncode(payload),
    );

    return {
      ...payload,
      'pendingLocally': true,
    };
  }

  /// Lists pending inbound stock operations awaiting delivery.
  Future<List<Map<String, dynamic>>> listPendingReceivings() async {
    final ops = await _queue.listByOperationType('inventory.receive');
    final result = <Map<String, dynamic>>[];
    for (final op in ops) {
      try {
        final decoded = jsonDecode(op.payload);
        if (decoded is Map<String, dynamic>) {
          result.add({
            ...decoded,
            'pendingLocally': true,
          });
        }
      } catch (_) {}
    }
    return result;
  }
}
