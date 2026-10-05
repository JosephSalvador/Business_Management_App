import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/data/auth_providers.dart';
import '../application/stock_controller.dart';
import 'inventory_repository.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => InventoryRepository(apiClient: ref.watch(apiClientProvider)),
);

final stockControllerProvider = NotifierProvider<StockController, StockState>(
  StockController.new,
);
