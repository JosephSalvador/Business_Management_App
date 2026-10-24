import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/features/finance/data/money_account_repository.dart';
import 'package:jolinx_app/app/providers.dart';

class FakeCashSessionRepository implements MoneyAccountRepository {
  Map<String, dynamic>? currentSession;
  Object? sessionError;

  @override
  Future<List<Map<String, dynamic>>> listAccounts() async => [];

  @override
  Future<Map<String, dynamic>> getAccount(String id) async => {};

  @override
  Future<List<Map<String, dynamic>>> listTransactions(
    String accountId, {
    int page = 1,
    int pageSize = 20,
  }) async =>
      [];

  @override
  Future<Map<String, dynamic>> createAccount(Map<String, dynamic> body) async =>
      {};

  @override
  Future<Map<String, dynamic>> transfer(Map<String, dynamic> body) async => {};

  @override
  Future<Map<String, dynamic>> recordIncome(Map<String, dynamic> body) async =>
      {};

  @override
  Future<Map<String, dynamic>> recordExpense(Map<String, dynamic> body) async =>
      {};

  @override
  Future<Map<String, dynamic>?> getCurrentSession(String accountId) async {
    if (sessionError != null) throw sessionError as Exception;
    return currentSession;
  }

  @override
  Future<Map<String, dynamic>> openSession(
    Map<String, dynamic> body, {
    bool remoteOnly = false,
  }) async {
    currentSession = {
      'id': 's1',
      'accountId': body['accountId'],
      'openingCash': body['openingCash'],
      'status': 0,
      'openedAt': DateTime.now().toIso8601String(),
    };
    return currentSession!;
  }

  @override
  Future<Map<String, dynamic>> closeSession(
    String sessionId,
    Map<String, dynamic> body, {
    bool remoteOnly = false,
  }) async {
    currentSession = {
      'id': sessionId,
      'accountId': currentSession?['accountId'],
      'status': 1,
      'openingCash': currentSession?['openingCash'],
      'closingCash': body['closingCash'],
      'variance': 0,
      'closedAt': DateTime.now().toIso8601String(),
    };
    return currentSession!;
  }
}

void main() {
  group('CashSessionController', () {
    test('initial state is Loading', () {
      final repository = FakeCashSessionRepository();
      final container = ProviderContainer(overrides: [
        moneyAccountRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);

      expect(
        container.read(cashSessionControllerProvider),
        isA<CashSessionLoading>(),
      );
    });

    test('load() with no session transitions to Loaded with null session',
        () async {
      final repository = FakeCashSessionRepository();
      final container = ProviderContainer(overrides: [
        moneyAccountRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);

      await container
          .read(cashSessionControllerProvider.notifier)
          .load('account1');

      final state = container.read(cashSessionControllerProvider);
      expect(state, isA<CashSessionLoaded>());
      final loaded = state as CashSessionLoaded;
      expect(loaded.session, isNull);
      expect(loaded.hasOpenSession, false);
    });

    test('load() failure transitions to Failure', () async {
      final repository = FakeCashSessionRepository();
      repository.sessionError = ServerException('DB error');
      final container = ProviderContainer(overrides: [
        moneyAccountRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);

      await container
          .read(cashSessionControllerProvider.notifier)
          .load('account1');

      final state = container.read(cashSessionControllerProvider);
      expect(state, isA<CashSessionFailure>());
      expect((state as CashSessionFailure).message, 'DB error');
    });

    test('openSession creates session and reloads', () async {
      final repository = FakeCashSessionRepository();
      final container = ProviderContainer(overrides: [
        moneyAccountRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(cashSessionControllerProvider.notifier);

      final session = await controller.openSession('account1', 50000);

      expect(session['status'], 0);
      expect(session['openingCash'], 50000);

      final state =
          container.read(cashSessionControllerProvider) as CashSessionLoaded;
      expect(state.hasOpenSession, true);
      expect(state.session?['openingCash'], 50000);
    });

    test('closeSession closes and reloads', () async {
      final repository = FakeCashSessionRepository();
      final container = ProviderContainer(overrides: [
        moneyAccountRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(cashSessionControllerProvider.notifier);

      await controller.openSession('account1', 50000);
      final result =
          await controller.closeSession('s1', 48000, 'End of day', 'account1');

      expect(result['status'], 1);
      expect(result['closingCash'], 48000);

      final state =
          container.read(cashSessionControllerProvider) as CashSessionLoaded;
      expect(state.hasOpenSession, false);
    });

    test('hasOpenSession is true when status is 0', () async {
      final repository = FakeCashSessionRepository();
      final container = ProviderContainer(overrides: [
        moneyAccountRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(cashSessionControllerProvider.notifier);

      await controller.openSession('account1', 50000);

      final state =
          container.read(cashSessionControllerProvider) as CashSessionLoaded;
      expect(state.hasOpenSession, true);
    });

    test('hasOpenSession is false when status is 1', () async {
      final repository = FakeCashSessionRepository();
      final container = ProviderContainer(overrides: [
        moneyAccountRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(cashSessionControllerProvider.notifier);

      await controller.openSession('account1', 50000);
      await controller.closeSession('s1', 50000, null, 'account1');

      final state =
          container.read(cashSessionControllerProvider) as CashSessionLoaded;
      expect(state.hasOpenSession, false);
    });

    test('reset() returns to Loading', () async {
      final repository = FakeCashSessionRepository();
      final container = ProviderContainer(overrides: [
        moneyAccountRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(cashSessionControllerProvider.notifier);

      await controller.load('account1');
      expect(container.read(cashSessionControllerProvider),
          isA<CashSessionLoaded>());

      controller.reset();

      final state = container.read(cashSessionControllerProvider);
      expect(state, isA<CashSessionLoading>());
    });
  });
}
