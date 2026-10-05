import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/app_exception.dart';
import '../data/dashboard_repository.dart';
import '../presentation/widgets/revenue_line_chart.dart';

sealed class DashboardState {
  const DashboardState();
}

class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

class DashboardLoaded extends DashboardState {
  const DashboardLoaded({
    required this.summary,
    required this.lowStock,
    required this.recentActivity,
    required this.trendData,
    required this.topProducts,
  });

  final DashboardSummary summary;
  final List<Map<String, dynamic>> lowStock;
  final List<Map<String, dynamic>> recentActivity;
  final List<SalesTrendPoint> trendData;
  final List<Map<String, dynamic>> topProducts;
}

class DashboardFailure extends DashboardState {
  const DashboardFailure(this.message);

  final String message;
}

class DashboardController extends Notifier<DashboardState> {
  @override
  DashboardState build() => const DashboardLoading();

  DashboardRepository get _repository => ref.read(dashboardRepositoryProvider);

  Future<void> load({int trendDays = 30}) async {
    state = const DashboardLoading();
    await _fetch(trendDays: trendDays);
  }

  Future<void> refresh({int trendDays = 30}) async {
    if (state is! DashboardLoaded) {
      return load(trendDays: trendDays);
    }
    await _fetch(trendDays: trendDays);
  }

  Future<void> _fetch({int trendDays = 30}) async {
    try {
      final results = await Future.wait<dynamic>([
        _repository.summary(),
        _repository.lowStock(),
        _repository.recentActivity(),
        _loadTrendRaw(days: trendDays),
        _repository.topProducts(limit: 5),
      ]);
      state = DashboardLoaded(
        summary: results[0] as DashboardSummary,
        lowStock: (results[1] as List).cast<Map<String, dynamic>>(),
        recentActivity: (results[2] as List).cast<Map<String, dynamic>>(),
        trendData: (results[3] as List)
            .map((e) => SalesTrendPoint.fromJson(e))
            .toList(),
        topProducts: (results[4] as Map<String, dynamic>)['items']
                ?.cast<Map<String, dynamic>>() ??
            [],
      );
    } on AppException catch (error) {
      state = DashboardFailure(error.message);
    }
  }

  Future<List<Map<String, dynamic>>> _loadTrendRaw({int days = 30}) async {
    try {
      return await _repository.salesTrend(days: days);
    } on AppException catch (_) {
      return [];
    }
  }

  Future<List<SalesTrendPoint>> loadSalesTrend({int days = 7}) async {
    try {
      final items = await _repository.salesTrend(days: days);
      return items.map((e) => SalesTrendPoint.fromJson(e)).toList();
    } on AppException catch (_) {
      final now = DateTime.now();
      return List.generate(
        days,
        (i) => SalesTrendPoint(
          label: now
              .subtract(Duration(days: days - 1 - i))
              .toIso8601String()
              .substring(0, 10),
          saleCount: 0,
          revenue: 0,
        ),
      );
    }
  }
}
