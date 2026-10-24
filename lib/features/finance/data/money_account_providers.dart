import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/data/auth_providers.dart' show sessionContextProvider;
import '../application/money_accounts_controller.dart';
import '../application/cash_session_controller.dart';
import 'money_account_repository.dart';

export '../application/money_accounts_controller.dart'
    show
        MoneyAccountsState,
        MoneyAccountsLoading,
        MoneyAccountsLoaded,
        MoneyAccountsFailure;
export '../application/cash_session_controller.dart'
    show
        CashSessionState,
        CashSessionLoading,
        CashSessionLoaded,
        CashSessionFailure;

import '../../../core/di/core_providers.dart';
import '../../../core/storage/sync_queue_dao.dart';
import '../../sales/data/sales_providers.dart';

final moneyAccountRepositoryProvider = Provider<MoneyAccountRepository>(
  (ref) {
    final db = ref.watch(localDatabaseProvider);
    final cache = ref.watch(offlineCacheDaoProvider);
    final identity = ref.watch(deviceIdentityProvider);
    return MoneyAccountRepository(
      apiClient: ref.watch(apiClientProvider),
      cache: cache,
      queue: SyncQueueDao(db),
      tenantIdOf: () async => ref.read(sessionContextProvider).$1,
      branchIdOf: () => ref.read(posBranchIdProvider)(),
      deviceIdOf: () => identity.get(),
    );
  },
);

final moneyAccountsControllerProvider =
    NotifierProvider<MoneyAccountsController, MoneyAccountsState>(
  MoneyAccountsController.new,
);

final cashSessionControllerProvider =
    NotifierProvider<CashSessionController, CashSessionState>(
  CashSessionController.new,
);
