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
  Future<void> load({DateTime? day, String? search}) async {
    state = const SalesHistoryLoading();
    try {
      final target = day ?? DateTime.now();
      final start = DateTime(target.year, target.month, target.day);
      final end = start.add(const Duration(days: 1));
      final term = _cleanSearch(search);
      final page = await _repository.list(
        from: start,
        to: end,
        search: term,
        pageSize: _pageSize,
      );
      state = SalesHistoryLoaded(
        sales: page.items,
        total: page.total,
        searchActive: term != null,
      );
    } on AppException catch (error) {
      state = SalesHistoryFailure(error.message);
    }
  }

  /// Legacy entry point kept for existing callers: today, unfiltered.
  Future<void> loadToday() => load();

  void reset() => state = const SalesHistoryLoading();
}
