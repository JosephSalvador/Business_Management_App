import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/core_providers.dart';
import '../../../core/storage/local_receipt_dao.dart';
import '../../../core/storage/sync_queue_dao.dart';
import '../../authentication/data/auth_providers.dart';
import '../../sales/data/sales_providers.dart';
import '../application/customers_controller.dart';
import 'customer_repository.dart';
import 'offline_customer_debt_service.dart';

export '../application/customers_controller.dart'
    show CustomersState, CustomersLoading, CustomersLoaded, CustomersFailure;
export 'offline_customer_debt_service.dart';

final customerRepositoryProvider = Provider<CustomerRepository>(
  (ref) => CustomerRepository(apiClient: ref.watch(apiClientProvider)),
);

final offlineCustomerDebtServiceProvider =
    Provider<OfflineCustomerDebtService>((ref) {
  final db = ref.watch(localDatabaseProvider);
  final cache = ref.watch(offlineCacheDaoProvider);
  final identity = ref.watch(deviceIdentityProvider);
  return OfflineCustomerDebtService(
    queue: SyncQueueDao(db),
    cache: cache,
    receipts: LocalReceiptDao(db),
    tenantIdOf: () async => ref.read(sessionContextProvider).$1,
    branchIdOf: () => ref.read(posBranchIdProvider)(),
    deviceIdOf: () => identity.get(),
    userIdOf: () async => ref.read(sessionContextProvider).$2,
  );
});

final customersControllerProvider =
    NotifierProvider<CustomersController, CustomersState>(
  CustomersController.new,
);
