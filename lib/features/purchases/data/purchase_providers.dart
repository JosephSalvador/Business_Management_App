import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/data/auth_providers.dart';
import '../application/purchases_controller.dart';
import 'purchase_repository.dart';

import '../../../core/di/core_providers.dart';
import '../../../core/storage/sync_queue_dao.dart';
import '../../sales/data/sales_providers.dart';

final purchaseRepositoryProvider = Provider<PurchaseRepository>(
  (ref) {
    final db = ref.watch(localDatabaseProvider);
    final cache = ref.watch(offlineCacheDaoProvider);
    final identity = ref.watch(deviceIdentityProvider);
    return PurchaseRepository(
      apiClient: ref.watch(apiClientProvider),
      cache: cache,
      queue: SyncQueueDao(db),
      tenantIdOf: () async => ref.read(sessionContextProvider).$1,
      branchIdOf: () => ref.read(posBranchIdProvider)(),
      deviceIdOf: () => identity.get(),
    );
  },
);

final purchasesControllerProvider =
    NotifierProvider<PurchasesController, PurchasesState>(
  PurchasesController.new,
);

final suppliersProvider = FutureProvider<PagedSuppliers>((ref) async {
  final repository = ref.watch(purchaseRepositoryProvider);
  return repository.suppliers();
});

final warehousesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(purchaseRepositoryProvider);
  return repository.warehouses();
});
