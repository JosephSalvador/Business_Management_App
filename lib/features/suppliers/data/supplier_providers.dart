import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/data/auth_providers.dart';
import '../application/suppliers_controller.dart';
import 'supplier_repository.dart';

final supplierRepositoryProvider = Provider<SupplierRepository>(
  (ref) => SupplierRepository(apiClient: ref.watch(apiClientProvider)),
);

final suppliersControllerProvider =
    NotifierProvider<SuppliersController, SuppliersState>(
  SuppliersController.new,
);
