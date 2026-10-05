import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../data/report_repository.dart';
import '../data/report_providers.dart';
import 'reports_controller.dart';

sealed class TopProductsState {
  const TopProductsState();
}

class TopProductsLoading extends TopProductsState {
  const TopProductsLoading();
}

class TopProductsLoaded extends TopProductsState {
  const TopProductsLoaded(this.products);

  final List<TopProduct> products;
}

class TopProductsFailure extends TopProductsState {
  const TopProductsFailure(this.message);

  final String message;
}

class TopProductsController extends Notifier<TopProductsState> {
  @override
  TopProductsState build() => const TopProductsLoading();

  ReportRepository get _repository => ref.read(reportRepositoryProvider);

  Future<void> load({
    ReportPeriod period = ReportPeriod.today,
    int limit = 25,
  }) async {
    state = const TopProductsLoading();
    try {
      final (from, to) = reportDateRange(period);
      final products =
          await _repository.topProducts(from: from, to: to, limit: limit);
      state = TopProductsLoaded(products);
    } on AppException catch (error) {
      state = TopProductsFailure(error.message);
    }
  }
}
