import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/data/auth_providers.dart';
import '../application/catalog_controller.dart';
import '../application/products_controller.dart';
import 'product_repository.dart';

import '../../../core/di/core_providers.dart';
import '../../../core/storage/cached_catalog_dao.dart';
import '../../../core/storage/sync_queue_dao.dart';
import '../../sales/data/sales_providers.dart';

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) {
    final db = ref.watch(localDatabaseProvider);
    final cache = ref.watch(offlineCacheDaoProvider);
    final identity = ref.watch(deviceIdentityProvider);
    return ProductRepository(
      apiClient: ref.watch(apiClientProvider),
      cache: cache,
      queue: SyncQueueDao(db),
      catalogDao: CachedCatalogDao(db),
      tenantIdOf: () async => ref.read(sessionContextProvider).$1,
      branchIdOf: () => ref.read(posBranchIdProvider)(),
      deviceIdOf: () => identity.get(),
    );
  },
);

final catalogControllerProvider =
    NotifierProvider<CatalogController, CatalogState>(
  CatalogController.new,
);

final productsControllerProvider =
    NotifierProvider<ProductsController, ProductsState>(
  ProductsController.new,
);
