import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/data/auth_providers.dart';
import '../application/catalog_controller.dart';
import '../application/products_controller.dart';
import 'product_repository.dart';

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepository(apiClient: ref.watch(apiClientProvider)),
);

final catalogControllerProvider =
    NotifierProvider<CatalogController, CatalogState>(
  CatalogController.new,
);

final productsControllerProvider =
    NotifierProvider<ProductsController, ProductsState>(
  ProductsController.new,
);
