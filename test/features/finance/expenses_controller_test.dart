import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/app/providers.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/features/finance/application/expenses_controller.dart';
import 'package:jolinx_app/features/finance/data/expense_repository.dart';

class FakeExpenseRepository implements ExpenseRepository {
  final List<Map<String, dynamic>> items;
  FakeExpenseRepository({List<Map<String, dynamic>>? items})
      : items = items ?? _generate(25);

  Object? listError;
  Object? summaryError;
  String? lastFromDate;
  String? lastToDate;

  static List<Map<String, dynamic>> _generate(int count) => List.generate(
        count,
        (i) => {
          'id': 'e${i + 1}',
          'description': 'Expense ${i + 1}',
          'amount': (i + 1) * 10.0,
          'expenseDate': '2026-08-${(i % 28) + 1}T10:00:00Z',
          'categoryId': i.isEven ? 'c1' : null,
          'categoryName': i.isEven ? 'Fuel' : null,
        },
      );

  @override
  Future<PagedExpenses> list({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? fromDate,
    String? toDate,
  }) async {
    if (listError != null) throw listError as Exception;
    lastFromDate = fromDate;
    lastToDate = toDate;
    var filtered = items;
    if (search != null && search.trim().isNotEmpty) {
      final term = search.trim().toLowerCase();
      filtered = items
          .where(
              (e) => (e['description'] as String).toLowerCase().contains(term))
          .toList();
    }
    final start = (page - 1) * pageSize;
    final slice = start >= filtered.length
        ? const <Map<String, dynamic>>[]
        : filtered.sublist(start, math.min(start + pageSize, filtered.length));
    return PagedExpenses(items: slice, total: filtered.length);
  }

  @override
  Future<Map<String, dynamic>> getById(String id) async =>
      items.firstWhere((e) => e['id'] == id);

  @override
  Future<Map<String, dynamic>> create(
    Map<String, dynamic> body, {
    String? idempotencyKey,
    bool remoteOnly = false,
  }) async {
    final created = {...body, 'id': 'new'};
    items.insert(0, created);
    return created;
  }

  @override
  Future<Map<String, dynamic>> update(
      String id, Map<String, dynamic> body) async {
    final index = items.indexWhere((e) => e['id'] == id);
    final updated = {...items[index], ...body};
    items[index] = updated;
    return updated;
  }

  @override
  Future<void> delete(String id) async {
    items.removeWhere((e) => e['id'] == id);
  }

  @override
  Future<List<ExpenseCategory>> listCategories() async => const [
        ExpenseCategory(id: 'c1', name: 'Fuel'),
      ];

  @override
  Future<ExpenseCategory> createCategory(String name) async =>
      ExpenseCategory(id: 'c9', name: name);

  @override
  Future<ExpenseSummary> getSummary({String? fromDate, String? toDate}) async {
    if (summaryError != null) throw summaryError as Exception;
    return const ExpenseSummary(
      total: 3000,
      byCategory: [
        ExpenseCategoryTotal(
            categoryId: 'c1', categoryName: 'Fuel', total: 1200),
      ],
    );
  }
}

void main() {
  group('ExpensesController', () {
    test('initial state is Loading', () {
      final container = ProviderContainer(overrides: [
        expenseRepositoryProvider.overrideWithValue(FakeExpenseRepository()),
      ]);
      addTearDown(container.dispose);

      expect(
          container.read(expensesControllerProvider), isA<ExpensesLoading>());
    });

    test('load() transitions to Loaded with items and summary', () async {
      final repository = FakeExpenseRepository();
      final container = ProviderContainer(overrides: [
        expenseRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);

      await container.read(expensesControllerProvider.notifier).load();

      final state = container.read(expensesControllerProvider);
      expect(state, isA<ExpensesLoaded>());
      final loaded = state as ExpensesLoaded;
      expect(loaded.items, hasLength(20));
      expect(loaded.total, 25);
      expect(loaded.summary, isNotNull);
      expect(loaded.summary!.total, 3000);
      expect(loaded.hasMore, isTrue);
    });

    test('load() without a range sends no date bounds', () async {
      final repository = FakeExpenseRepository();
      final container = ProviderContainer(overrides: [
        expenseRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);

      await container.read(expensesControllerProvider.notifier).load();

      expect(repository.lastFromDate, isNull);
      expect(repository.lastToDate, isNull);
    });

    test('load() with a range sends UTC day bounds', () async {
      final repository = FakeExpenseRepository();
      final container = ProviderContainer(overrides: [
        expenseRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);

      await container
          .read(expensesControllerProvider.notifier)
          .load(fromDate: DateTime(2026, 8, 1), toDate: DateTime(2026, 8, 10));

      expect(repository.lastFromDate, isNotNull);
      expect(repository.lastToDate, isNotNull);
      expect(repository.lastFromDate, endsWith('Z'));
      expect(repository.lastToDate, endsWith('Z'));
    });

    test('loadMore() appends the next page and stops at the end', () async {
      final container = ProviderContainer(overrides: [
        expenseRepositoryProvider.overrideWithValue(FakeExpenseRepository()),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(expensesControllerProvider.notifier);

      await controller.load();
      expect(
          (container.read(expensesControllerProvider) as ExpensesLoaded).items,
          hasLength(20));

      await controller.loadMore();
      var loaded = container.read(expensesControllerProvider) as ExpensesLoaded;
      expect(loaded.items, hasLength(25));
      expect(loaded.hasMore, isFalse);

      await controller.loadMore();
      loaded = container.read(expensesControllerProvider) as ExpensesLoaded;
      expect(loaded.items, hasLength(25));
    });

    test('search filters through the repository', () async {
      final container = ProviderContainer(overrides: [
        expenseRepositoryProvider.overrideWithValue(FakeExpenseRepository()),
      ]);
      addTearDown(container.dispose);

      await container
          .read(expensesControllerProvider.notifier)
          .load(search: 'Expense 3');

      final loaded =
          container.read(expensesControllerProvider) as ExpensesLoaded;
      expect(loaded.total, 1);
      expect(loaded.items.single['description'], 'Expense 3');
    });

    test('create() calls repository then reloads', () async {
      final container = ProviderContainer(overrides: [
        expenseRepositoryProvider.overrideWithValue(FakeExpenseRepository()),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(expensesControllerProvider.notifier);

      await controller.load();
      expect(
          (container.read(expensesControllerProvider) as ExpensesLoaded).total,
          25);

      await controller.create({'description': 'New', 'amount': 50.0});

      final loaded =
          container.read(expensesControllerProvider) as ExpensesLoaded;
      expect(loaded.total, 26);
      expect(loaded.items.first['description'], 'New');
    });

    test('delete() calls repository then reloads', () async {
      final repository = FakeExpenseRepository();
      final container = ProviderContainer(overrides: [
        expenseRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(expensesControllerProvider.notifier);

      await controller.load();
      await controller.delete('e1');

      final loaded =
          container.read(expensesControllerProvider) as ExpensesLoaded;
      expect(loaded.total, 24);
      expect(loaded.items.any((e) => e['id'] == 'e1'), isFalse);
    });

    test('load() failure transitions to Failure', () async {
      final repository = FakeExpenseRepository();
      repository.listError = ServerException('Server down');
      final container = ProviderContainer(overrides: [
        expenseRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);

      await container.read(expensesControllerProvider.notifier).load();

      final state = container.read(expensesControllerProvider);
      expect(state, isA<ExpensesFailure>());
      expect((state as ExpensesFailure).message, 'Server down');
    });

    test('reset() returns to Loading', () async {
      final container = ProviderContainer(overrides: [
        expenseRepositoryProvider.overrideWithValue(FakeExpenseRepository()),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(expensesControllerProvider.notifier);

      await controller.load();
      expect(container.read(expensesControllerProvider), isA<ExpensesLoaded>());

      controller.reset();

      expect(
          container.read(expensesControllerProvider), isA<ExpensesLoading>());
    });

    test('expenseDay bounds are local-midnight UTC ranges', () {
      final start = expenseDayStartUtc(DateTime(2026, 8, 1));
      final end = expenseDayEndUtc(DateTime(2026, 8, 1));
      expect(start, endsWith('Z'));
      expect(end, endsWith('Z'));
      expect(DateTime.parse(end).isAfter(DateTime.parse(start)), isTrue);
    });
  });
}
