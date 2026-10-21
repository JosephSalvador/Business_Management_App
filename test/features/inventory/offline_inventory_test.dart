import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/storage/cached_catalog_dao.dart';
import 'package:jolinx_app/core/storage/local_database.dart';
import 'package:jolinx_app/core/storage/sync_queue_dao.dart';
import 'package:jolinx_app/features/inventory/data/offline_inventory_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalDatabase db;
  late CachedCatalogDao catalogDao;
  late SyncQueueDao queue;
  late OfflineInventoryService service;

  setUp(() {
    db = LocalDatabase(NativeDatabase.memory());
    catalogDao = CachedCatalogDao(db);
    queue = SyncQueueDao(db);

    service = OfflineInventoryService(
      catalogDao: catalogDao,
      queue: queue,
      tenantIdOf: () async => 'tenant-1',
      branchIdOf: () async => 'branch-1',
      deviceIdOf: () async => 'dev-1',
      userIdOf: () async => 'user-1',
    );
  });

  tearDown(() async => db.close());

  test(
      'recordOfflineInboundReceiving immediately bumps local stock and queues sync operation',
      () async {
    // Initial stock is 0
    final initialStock = await catalogDao.projectedQuantity('tenant-1', 'prod-100');
    expect(initialStock, 0.0);

    // Inbound receiving of 25 units offline
    final result = await service.recordOfflineInboundReceiving(
      productId: 'prod-100',
      productName: 'Mchele Super',
      quantity: 25.0,
      warehouseId: 'wh-main',
      notes: 'Mzigo kutoka kwa muuzaji',
    );

    expect(result['pendingLocally'], isTrue);
    expect(result['adjustmentQuantity'], 25.0);

    // Immediate stock bump verified
    final updatedStock =
        await catalogDao.projectedQuantity('tenant-1', 'prod-100');
    expect(updatedStock, 25.0);

    // SyncQueue has the pending operation
    final ops = await queue.listByOperationType('inventory.receive');
    expect(ops, hasLength(1));
    expect(ops.single.aggregateId, 'prod-100');
  });
}
