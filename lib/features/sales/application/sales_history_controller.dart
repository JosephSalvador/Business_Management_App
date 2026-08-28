import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  const SalesHistoryLoaded({required this.sales, required this.total});

  final List<SaleDto> sales;
  final int total;

  bool get isEmpty => sales.isEmpty;
}

class SalesHistoryFailure extends SalesHistoryState {
  const SalesHistoryFailure(this.message);

  final String message;
}

/// "Mauzo ya leo" — the day's completed sales, newest first.
class SalesHistoryController extends StateNotifier<SalesHistoryState> {
  SalesHistoryController(this._repository)
      : super(const SalesHistoryLoading());

  static const _pageSize = 100;

  final SaleRepository _repository;

  Future<void> loadToday() async {
    state = const SalesHistoryLoading();
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));
      final page = await _repository.list(
        from: start,
        to: end,
        pageSize: _pageSize,
      );
      state = SalesHistoryLoaded(sales: page.items, total: page.total);
    } on AppException catch (error) {
      state = SalesHistoryFailure(error.message);
    }
  }

  void reset() => state = const SalesHistoryLoading();
}
