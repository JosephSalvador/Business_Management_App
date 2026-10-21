import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/core_providers.dart';
import '../../../core/storage/cached_catalog_dao.dart';
import '../../../core/storage/sync_queue_dao.dart';
import '../../authentication/data/auth_providers.dart';
import '../../sales/data/sales_providers.dart';
import '../application/stock_controller.dart';
import 'inventory_repository.dart';
import 'offline_inventory_service.dart';

export 'offline_inventory_service.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => InventoryRepository(apiClient: ref.watch(apiClientProvider)),
);

final offlineInventoryServiceProvider =
    Provider<OfflineInventoryService>((ref) {
  final db = ref.watch(localDatabaseProvider);
  final catalogDao = CachedCatalogDao(db);
  final queue = SyncQueueDao(db);
  final identity = ref.watch(deviceIdentityProvider);

  return OfflineInventoryService(
    catalogDao: catalogDao,
    queue: queue,
    tenantIdOf: () async => ref.read(sessionContextProvider).$1,
    branchIdOf: () => ref.read(posBranchIdProvider)(),
    deviceIdOf: () => identity.get(),
    userIdOf: () async => ref.read(sessionContextProvider).$2,
  );
});

final stockControllerProvider = NotifierProvider<StockController, StockState>(
  StockController.new,
);
