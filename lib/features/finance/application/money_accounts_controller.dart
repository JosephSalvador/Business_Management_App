import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/app_exception.dart';
import '../data/money_account_repository.dart';

sealed class MoneyAccountsState {
  const MoneyAccountsState();
}

class MoneyAccountsLoading extends MoneyAccountsState {
  const MoneyAccountsLoading();
}

class MoneyAccountsLoaded extends MoneyAccountsState {
  const MoneyAccountsLoaded({required this.accounts});

  final List<Map<String, dynamic>> accounts;

  bool get isEmpty => accounts.isEmpty;

  double get totalBalance => accounts.fold<double>(
        0,
        (sum, a) => sum + (a['balance'] as num? ?? 0).toDouble(),
      );
}

class MoneyAccountsFailure extends MoneyAccountsState {
  const MoneyAccountsFailure(this.message);

  final String message;
}

class MoneyAccountsController extends Notifier<MoneyAccountsState> {
  @override
  MoneyAccountsState build() => const MoneyAccountsLoading();

  MoneyAccountRepository get _repository =>
      ref.read(moneyAccountRepositoryProvider);

  Future<void> load({bool silent = false}) async {
    if (!silent || state is! MoneyAccountsLoaded) {
      state = const MoneyAccountsLoading();
    }
    try {
      final accounts = await _repository.listAccounts();
      state = MoneyAccountsLoaded(accounts: accounts);
    } on AppException catch (e) {
      if (state is! MoneyAccountsLoaded) {
        state = MoneyAccountsFailure(e.message);
      }
    } catch (e) {
      if (state is! MoneyAccountsLoaded) {
        state = MoneyAccountsFailure(e.toString());
      }
    }
  }

  Future<Map<String, dynamic>> getById(String id) async {
    return _repository.getAccount(id);
  }

  Future<List<Map<String, dynamic>>> getTransactions(
    String accountId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    return _repository.listTransactions(accountId,
        page: page, pageSize: pageSize);
  }

  Future<void> createAccount(Map<String, dynamic> body) async {
    await _repository.createAccount(body);
    await load(silent: true);
  }

  Future<void> recordIncome(Map<String, dynamic> body) async {
    await _repository.recordIncome(body);
    await load(silent: true);
  }

  Future<void> recordExpense(Map<String, dynamic> body) async {
    await _repository.recordExpense(body);
    await load(silent: true);
  }

  Future<void> transfer(Map<String, dynamic> body) async {
    await _repository.transfer(body);
    await load(silent: true);
  }

  void reset() {
    state = const MoneyAccountsLoading();
  }
}
