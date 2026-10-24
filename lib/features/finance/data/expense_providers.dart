import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/core_providers.dart';
import '../../../core/storage/sync_queue_dao.dart';
import '../../sales/data/sales_providers.dart';
import '../application/expenses_controller.dart';
import 'expense_repository.dart';
import 'offline_expense_service.dart';

export '../application/expenses_controller.dart'
    show ExpensesState, ExpensesLoading, ExpensesLoaded, ExpensesFailure;
export 'offline_expense_service.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) {
    final cache = ref.watch(offlineCacheDaoProvider);
    final offlineService = ref.watch(offlineExpenseServiceProvider);
    return ExpenseRepository(
      apiClient: ref.watch(apiClientProvider),
      cache: cache,
      offlineService: offlineService,
    );
  },
);

final offlineExpenseServiceProvider = Provider<OfflineExpenseService>((ref) {
  final db = ref.watch(localDatabaseProvider);
  final cache = ref.watch(offlineCacheDaoProvider);
  final identity = ref.watch(deviceIdentityProvider);
  return OfflineExpenseService(
    queue: SyncQueueDao(db),
    cache: cache,
    tenantIdOf: () async => ref.read(sessionContextProvider).$1,
    branchIdOf: () => ref.read(posBranchIdProvider)(),
    deviceIdOf: () => identity.get(),
    userIdOf: () async => ref.read(sessionContextProvider).$2,
  );
});

final expenseCategoriesProvider = FutureProvider<List<ExpenseCategory>>(
  (ref) {
    final offlineService = ref.watch(offlineExpenseServiceProvider);
    final repo = ref.watch(expenseRepositoryProvider);
    return offlineService.getCategoriesWithCache(() => repo.listCategories());
  },
);

final expensesControllerProvider =
    NotifierProvider<ExpensesController, ExpensesState>(
  ExpensesController.new,
);
