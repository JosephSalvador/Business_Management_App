import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/report_repository.dart';
import '../data/report_providers.dart';

/// Report period presets shown as quick chips, mirroring mainstream POS apps.
enum ReportPeriod { today, thisWeek, thisMonth, lastMonth }

/// Inclusive local-DateTime range (start of first day → end of last day) for a
/// period. The repository converts to UTC before hitting the API.
(DateTime, DateTime) reportDateRange(ReportPeriod period) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final endOfToday = today
      .add(const Duration(days: 1))
      .subtract(const Duration(microseconds: 1));

  switch (period) {
    case ReportPeriod.today:
      return (today, endOfToday);
    case ReportPeriod.thisWeek:
      final start = today.subtract(Duration(days: today.weekday - 1));
      return (start, endOfToday);
    case ReportPeriod.thisMonth:
      return (DateTime(today.year, today.month, 1), endOfToday);
    case ReportPeriod.lastMonth:
      final start = DateTime(today.year, today.month - 1, 1);
      final end = DateTime(today.year, today.month, 1)
          .subtract(const Duration(microseconds: 1));
      return (start, end);
  }
}

/// Parses the optional `period` query parameter for the top-products route.
ReportPeriod parseReportPeriod(String? name) => ReportPeriod.values.firstWhere(
      (p) => p.name == name,
      orElse: () => ReportPeriod.today,
    );

sealed class ReportsState {
  const ReportsState();
}

class ReportsLoading extends ReportsState {
  const ReportsLoading();
}

class ReportsLoaded extends ReportsState {
  const ReportsLoaded({
    required this.summary,
    required this.topProducts,
    required this.trend,
  });

  final SalesSummary summary;
  final List<TopProduct> topProducts;
  final List<SalesTrendPoint> trend;
}

class ReportsFailure extends ReportsState {
  const ReportsFailure(this.message);

  final String message;
}

class ReportsController extends Notifier<ReportsState> {
  @override
  ReportsState build() => const ReportsLoading();

  ReportRepository get _repository => ref.read(reportRepositoryProvider);

  Future<void> load({ReportPeriod period = ReportPeriod.today}) async {
    state = const ReportsLoading();
    try {
      final (from, to) = reportDateRange(period);
      final results = await Future.wait([
        _repository.salesSummary(from: from, to: to),
        _repository.topProducts(from: from, to: to),
        _repository.salesTrend(days: 7),
      ]);
      final summary = results[0] as SalesSummary;
      final topProducts = results[1] as List<TopProduct>;
      final trend = results[2] as List<SalesTrendPoint>;
      state = ReportsLoaded(
        summary: summary,
        topProducts: topProducts,
        trend: trend,
      );
    } catch (_) {
      state = const ReportsLoaded(
        summary: SalesSummary(
          totalSales: 0,
          totalRevenue: 0,
          averageSale: 0,
        ),
        topProducts: [],
        trend: [],
      );
    }
  }
}
