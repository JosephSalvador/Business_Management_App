import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/data/auth_providers.dart';
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

final moneyAccountRepositoryProvider = Provider<MoneyAccountRepository>(
  (ref) => MoneyAccountRepository(apiClient: ref.watch(apiClientProvider)),
);

final moneyAccountsControllerProvider =
    NotifierProvider<MoneyAccountsController, MoneyAccountsState>(
  MoneyAccountsController.new,
);

final cashSessionControllerProvider =
    NotifierProvider<CashSessionController, CashSessionState>(
  CashSessionController.new,
);
