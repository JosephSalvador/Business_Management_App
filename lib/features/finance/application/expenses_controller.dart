import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/network/connectivity_monitor.dart';
import '../data/expense_repository.dart';

const int expensePageSize = 20;

/// Encloses [day] from local midnight to one millisecond before the next day.
String expenseDayStartUtc(DateTime day) =>
    DateTime(day.year, day.month, day.day).toUtc().toIso8601String();

/// Encloses [day] from local midnight to one millisecond before the next day.
String expenseDayEndUtc(DateTime day) =>
    DateTime(day.year, day.month, day.day, 23, 59, 59)
        .toUtc()
        .toIso8601String();

sealed class ExpensesState {
  const ExpensesState();
}

class ExpensesLoading extends ExpensesState {
  const ExpensesLoading({this.search = ''});

  final String search;
}

class ExpensesLoaded extends ExpensesState {
  const ExpensesLoaded({
    required this.items,
    required this.total,
    required this.page,
    required this.hasMore,
    this.search = '',
    this.fromDate,
    this.toDate,
    this.summary,
  });

  final List<Map<String, dynamic>> items;
  final int total;
  final int page;
  final bool hasMore;
  final String search;
  final DateTime? fromDate;
  final DateTime? toDate;
  final ExpenseSummary? summary;

  bool get isEmpty => items.isEmpty;
}

class ExpensesFailure extends ExpensesState {
  const ExpensesFailure(this.message);

  final String message;
}

class ExpensesController extends Notifier<ExpensesState> {
  String _search = '';
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  ExpensesState build() => const ExpensesLoading();

  ExpenseRepository get _repository => ref.read(expenseRepositoryProvider);
  OfflineExpenseService get _offlineService =>
      ref.read(offlineExpenseServiceProvider);

  Future<void> load({
    String? search,
    DateTime? fromDate,
    DateTime? toDate,
    bool silent = false,
  }) async {
    if (search != null) {
      _search = search;
    }
    if (fromDate != null || toDate != null) {
      _fromDate = fromDate ?? _fromDate;
      _toDate = toDate ?? _toDate;
    }
    if (!silent || state is! ExpensesLoaded) {
      state = ExpensesLoading(search: _search);
    }
    try {
      state = await _fetchPage(1);
    } on AppException catch (e) {
      if (state is! ExpensesLoaded) {
        state = ExpensesFailure(e.message);
      }
    }
  }

  Future<void> loadMore() async {
    final current = state;
    if (current is! ExpensesLoaded || !current.hasMore) return;
    try {
      final page = await _fetchPage(current.page + 1);
      final loaded = page as ExpensesLoaded;
      state = ExpensesLoaded(
        items: [...current.items, ...loaded.items],
        total: loaded.total,
        page: loaded.page,
        hasMore: loaded.hasMore,
        search: loaded.search,
        fromDate: loaded.fromDate,
        toDate: loaded.toDate,
        summary: current.summary,
      );
    } on AppException {
      // Keep the current list; the user can scroll to retry.
    }
  }

  Future<ExpensesState> _fetchPage(int page) async {
    List<Map<String, dynamic>> pending = const [];
    if (page == 1) {
      try {
        pending = await _offlineService.listPendingExpenses();
      } catch (_) {}
    }

    try {
      final result = await _repository.list(
        page: page,
        pageSize: expensePageSize,
        search: _search,
        fromDate: _fromDate == null ? null : expenseDayStartUtc(_fromDate!),
        toDate: _toDate == null ? null : expenseDayEndUtc(_toDate!),
      );
      final summary = await _repository.getSummary(
        fromDate: _fromDate == null ? null : expenseDayStartUtc(_fromDate!),
        toDate: _toDate == null ? null : expenseDayEndUtc(_toDate!),
      );

      final existingIds = result.items.map((e) => e['id']).toSet();
      final uniquePending =
          pending.where((p) => !existingIds.contains(p['id'])).toList();

      final combined = [...uniquePending, ...result.items];
      return ExpensesLoaded(
        items: combined,
        total: result.total + uniquePending.length,
        page: page,
        hasMore: page * expensePageSize < result.total,
        search: _search,
        fromDate: _fromDate,
        toDate: _toDate,
        summary: summary,
      );
    } on AppException {
      if (page == 1 && pending.isNotEmpty) {
        return ExpensesLoaded(
          items: pending,
          total: pending.length,
          page: 1,
          hasMore: false,
          search: _search,
          fromDate: _fromDate,
          toDate: _toDate,
          summary: const ExpenseSummary(total: 0, byCategory: []),
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getById(String id) async {
    final pending = await _offlineService.listPendingExpenses();
    final localMatch = pending.where((e) => e['id'] == id).firstOrNull;
    if (localMatch != null) return localMatch;
    return _repository.getById(id);
  }

  Future<void> create(Map<String, dynamic> body) async {
    final connection = ref.read(connectionQualityProvider);
    if (connection == ConnectionQuality.offline ||
        connection == ConnectionQuality.unreachable) {
      await _offlineService.recordOffline(body);
      await load();
      return;
    }

    try {
      await _repository.create(body);
    } on AppException catch (e) {
      if (e is NetworkException || e is TimeoutException) {
        await _offlineService.recordOffline(body);
      } else {
        rethrow;
      }
    }
    await load();
  }

  Future<void> update(String id, Map<String, dynamic> body) async {
    await _repository.update(id, body);
    await load();
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    await load();
  }

  void reset() {
    _search = '';
    _fromDate = null;
    _toDate = null;
    state = const ExpensesLoading();
  }
}
