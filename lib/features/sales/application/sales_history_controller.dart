import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/app_exception.dart';
import '../data/sale_repository.dart';
import '../domain/sale.dart';

sealed class SalesHistoryState {
  const SalesHistoryState();
}

class SalesHistoryLoading extends SalesHistoryState {
  const SalesHistoryLoading();
}

class SalesHistoryLoaded extends SalesHistoryState {
  const SalesHistoryLoaded({
    required this.sales,
    required this.total,
    this.searchActive = false,
  });

  final List<SaleDto> sales;
  final int total;

  /// True when the loaded page was produced by a non-empty search term, so the
  /// empty state can say "no matches" instead of "nothing sold that day".
  final bool searchActive;

  bool get isEmpty => sales.isEmpty;
}

class SalesHistoryFailure extends SalesHistoryState {
  const SalesHistoryFailure(this.message);

  final String message;
}

/// "Mauzo" — a single day's completed sales, newest first, optionally filtered
/// by receipt number or customer name (server-side search).
class SalesHistoryController extends Notifier<SalesHistoryState> {
  static const _pageSize = 100;

  @override
  SalesHistoryState build() => const SalesHistoryLoading();

  SaleRepository get _repository => ref.read(saleRepositoryProvider);

  static String? _cleanSearch(String? search) {
    final trimmed = search?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// Loads one local calendar day (midnight → next midnight). Pass [search] to
  /// filter by receipt number or customer name.
  ///
  /// Local-First Invariant: Local device SQLite is the primary authoritative
  /// source of truth. Results are rendered immediately with the latest sale
  /// always at the top (effectiveAt DESC). Background remote fetch enriches
  /// external multi-terminal sales without ever wiping or replacing local sales.
  Future<void> load({DateTime? day, String? search}) async {
    state = const SalesHistoryLoading();
    final target = day ?? DateTime.now();
    final start = DateTime(target.year, target.month, target.day);
    final end = start.add(const Duration(days: 1));
    final term = _cleanSearch(search);

    // 1. Authoritative local SQLite load (instant, 100% offline-ready)
    List<SaleDto> localSales = const [];
    bool localReadSucceeded = false;
    try {
      localSales = await ref.read(localSalesServiceProvider).sales.listSales(
        from: start,
        to: end,
        search: term,
        limit: _pageSize,
      );
      localReadSucceeded = true;
      // Immediately present local sales to the user — zero network delay.
      // Latest sale is ALWAYS at index 0 (ordered by effectiveAt DESC).
      state = SalesHistoryLoaded(
        sales: localSales,
        total: localSales.length,
        searchActive: term != null,
      );
    } catch (_) {
      // Local DB read degraded — fall back to remote fetch
    }

    // 2. Background remote reconciliation for multi-terminal environments
    try {
      final page = await _repository.list(
        from: start,
        to: end,
        search: term,
        pageSize: _pageSize,
      );

      // Merge remote sales without ever wiping or deleting local sales
      final existingKeys = <String>{};
      for (final s in localSales) {
        existingKeys.add(s.id);
        if (s.number.isNotEmpty) existingKeys.add(s.number);
      }

      final merged = List<SaleDto>.from(localSales);
      for (final remote in page.items) {
        final matchesLocal = existingKeys.contains(remote.id) ||
            (remote.number.isNotEmpty && existingKeys.contains(remote.number));
        if (!matchesLocal) {
          merged.add(remote);
        }
      }

      // Invariant: Latest sale is ALWAYS first in the list
      merged.sort((a, b) => b.saleDate.compareTo(a.saleDate));

      state = SalesHistoryLoaded(
        sales: merged,
        total: merged.length,
        searchActive: term != null,
      );
    } on AppException catch (error) {
      // If local read succeeded, NEVER surface network errors to the UI!
      // The user is working offline and local sales are already displayed safely.
      if (!localReadSucceeded && state is! SalesHistoryLoaded) {
        state = SalesHistoryFailure(error.message);
      }
    }
  }

  /// Optimistically prepends a newly completed sale to the loaded list so it
  /// is immediately visible at index 0 without waiting for a re-query.
  void prependSale(SaleDto sale) {
    if (state is SalesHistoryLoaded) {
      final current = (state as SalesHistoryLoaded).sales;
      if (!current.any((s) => s.id == sale.id || (s.number.isNotEmpty && s.number == sale.number))) {
        final updated = [sale, ...current];
        state = SalesHistoryLoaded(
          sales: updated,
          total: updated.length,
          searchActive: (state as SalesHistoryLoaded).searchActive,
        );
      }
    } else {
      state = SalesHistoryLoaded(
        sales: [sale],
        total: 1,
        searchActive: false,
      );
    }
  }

  /// Legacy entry point kept for existing callers: today, unfiltered.
  Future<void> loadToday() => load();

  void reset() => state = const SalesHistoryLoading();
}
