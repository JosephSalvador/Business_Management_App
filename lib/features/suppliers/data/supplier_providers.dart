import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/data/auth_providers.dart';
import '../application/suppliers_controller.dart';
import 'supplier_repository.dart';

import '../../../core/di/core_providers.dart'
    show localDatabaseProvider, offlineCacheDaoProvider, deviceIdentityProvider;
import '../../../core/storage/sync_queue_dao.dart';
import '../../sales/data/sales_providers.dart';

final supplierRepositoryProvider = Provider<SupplierRepository>(
  (ref) {
    final db = ref.watch(localDatabaseProvider);
    final cache = ref.watch(offlineCacheDaoProvider);
    final identity = ref.watch(deviceIdentityProvider);
    return SupplierRepository(
      apiClient: ref.watch(apiClientProvider),
      cache: cache,
      queue: SyncQueueDao(db),
      tenantIdOf: () async => ref.read(sessionContextProvider).$1,
      branchIdOf: () => ref.read(posBranchIdProvider)(),
      deviceIdOf: () => identity.get(),
    );
  },
);

final suppliersControllerProvider =
    NotifierProvider<SuppliersController, SuppliersState>(
  SuppliersController.new,
);
