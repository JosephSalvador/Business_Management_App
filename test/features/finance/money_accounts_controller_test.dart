import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/features/finance/data/money_account_repository.dart';
import 'package:jolinx_app/app/providers.dart';

class FakeMoneyAccountRepository implements MoneyAccountRepository {
  List<Map<String, dynamic>> accounts = [
    {
      'id': 'a1',
      'name': 'Cash Shop',
      'type': 0,
      'balance': 50000,
      'isActive': true
    },
    {
      'id': 'a2',
      'name': 'M-Pesa Business',
      'type': 1,
      'balance': 120000,
      'isActive': true
    },
  ];
  Object? listError;

  @override
  Future<List<Map<String, dynamic>>> listAccounts() async {
    if (listError != null) throw listError as Exception;
    return accounts;
  }

  @override
  Future<Map<String, dynamic>> getAccount(String id) async {
    return accounts.firstWhere((a) => a['id'] == id);
  }

  @override
  Future<List<Map<String, dynamic>>> listTransactions(
    String accountId, {
    int page = 1,
    int pageSize = 20,
  }) async =>
      [
        {
          'id': 't1',
          'type': 0,
          'amount': 10000,
          'description': 'Sale',
          'createdAt': '2026-01-01T10:00:00Z'
        },
      ];

  @override
  Future<Map<String, dynamic>> createAccount(Map<String, dynamic> body) async {
    final newAccount = {
      ...body,
      'id': 'a${accounts.length + 1}',
      'balance': 0,
      'isActive': true
    };
    accounts = [...accounts, newAccount];
    return newAccount;
  }

  @override
  Future<Map<String, dynamic>> transfer(Map<String, dynamic> body) async => {};

  @override
  Future<Map<String, dynamic>> recordIncome(Map<String, dynamic> body) async =>
      {};

  @override
  Future<Map<String, dynamic>> recordExpense(Map<String, dynamic> body) async =>
      {};

  @override
  Future<Map<String, dynamic>?> getCurrentSession(String accountId) async =>
      null;

  @override
  Future<Map<String, dynamic>> openSession(Map<String, dynamic> body) async =>
      {};

  @override
  Future<Map<String, dynamic>> closeSession(
          String sessionId, Map<String, dynamic> body) async =>
      {};
}

void main() {
  group('MoneyAccountsController', () {
    test('initial state is Loading', () {
      final repository = FakeMoneyAccountRepository();
      final container = ProviderContainer(overrides: [
        moneyAccountRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);

      expect(
        container.read(moneyAccountsControllerProvider),
        isA<MoneyAccountsLoading>(),
      );
    });

    test('load() transitions to Loaded with accounts', () async {
      final repository = FakeMoneyAccountRepository();
      final container = ProviderContainer(overrides: [
        moneyAccountRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);

      await container.read(moneyAccountsControllerProvider.notifier).load();

      final state = container.read(moneyAccountsControllerProvider);
      expect(state, isA<MoneyAccountsLoaded>());
      final loaded = state as MoneyAccountsLoaded;
      expect(loaded.accounts, hasLength(2));
      expect(loaded.accounts[0]['name'], 'Cash Shop');
    });

    test('load() failure transitions to Failure', () async {
      final repository = FakeMoneyAccountRepository();
      repository.listError = ServerException('Server down');
      final container = ProviderContainer(overrides: [
        moneyAccountRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);

      await container.read(moneyAccountsControllerProvider.notifier).load();

      final state = container.read(moneyAccountsControllerProvider);
      expect(state, isA<MoneyAccountsFailure>());
      expect((state as MoneyAccountsFailure).message, 'Server down');
    });

    test('totalBalance sums all account balances', () async {
      final repository = FakeMoneyAccountRepository();
      final container = ProviderContainer(overrides: [
        moneyAccountRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);

      await container.read(moneyAccountsControllerProvider.notifier).load();

      final state = container.read(moneyAccountsControllerProvider)
          as MoneyAccountsLoaded;
      expect(state.totalBalance, 170000);
    });

    test('isEmpty returns false when accounts exist', () async {
      final repository = FakeMoneyAccountRepository();
      final container = ProviderContainer(overrides: [
        moneyAccountRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);

      await container.read(moneyAccountsControllerProvider.notifier).load();

      final state = container.read(moneyAccountsControllerProvider)
          as MoneyAccountsLoaded;
      expect(state.isEmpty, false);
    });

    test('isEmpty returns true when no accounts', () async {
      final repository = FakeMoneyAccountRepository();
      repository.accounts = [];
      final container = ProviderContainer(overrides: [
        moneyAccountRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);

      await container.read(moneyAccountsControllerProvider.notifier).load();

      final state = container.read(moneyAccountsControllerProvider)
          as MoneyAccountsLoaded;
      expect(state.isEmpty, true);
    });

    test('getById returns account', () async {
      final repository = FakeMoneyAccountRepository();
      final container = ProviderContainer(overrides: [
        moneyAccountRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);

      final account = await container
          .read(moneyAccountsControllerProvider.notifier)
          .getById('a1');
      expect(account['name'], 'Cash Shop');
    });

    test('getTransactions returns list', () async {
      final repository = FakeMoneyAccountRepository();
      final container = ProviderContainer(overrides: [
        moneyAccountRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);

      final txs = await container
          .read(moneyAccountsControllerProvider.notifier)
          .getTransactions('a1');
      expect(txs, hasLength(1));
      expect(txs[0]['description'], 'Sale');
    });

    test('createAccount calls repository then reloads', () async {
      final repository = FakeMoneyAccountRepository();
      final container = ProviderContainer(overrides: [
        moneyAccountRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller =
          container.read(moneyAccountsControllerProvider.notifier);

      await controller.load();
      expect(
        (container.read(moneyAccountsControllerProvider) as MoneyAccountsLoaded)
            .accounts
            .length,
        2,
      );

      await controller.createAccount({'name': 'New Account', 'type': 2});

      final state = container.read(moneyAccountsControllerProvider)
          as MoneyAccountsLoaded;
      expect(state.accounts.length, 3);
      expect(state.accounts.last['name'], 'New Account');
    });

    test('reset() returns to Loading', () async {
      final repository = FakeMoneyAccountRepository();
      final container = ProviderContainer(overrides: [
        moneyAccountRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller =
          container.read(moneyAccountsControllerProvider.notifier);

      await controller.load();
      expect(container.read(moneyAccountsControllerProvider),
          isA<MoneyAccountsLoaded>());

      controller.reset();

      final state = container.read(moneyAccountsControllerProvider);
      expect(state, isA<MoneyAccountsLoading>());
    });
  });
}
