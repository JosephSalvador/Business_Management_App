import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/data/auth_providers.dart';
import '../application/purchases_controller.dart';
import 'purchase_repository.dart';

final purchaseRepositoryProvider = Provider<PurchaseRepository>(
  (ref) => PurchaseRepository(apiClient: ref.watch(apiClientProvider)),
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
