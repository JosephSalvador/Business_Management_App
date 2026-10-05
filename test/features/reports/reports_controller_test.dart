import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/features/reports/application/reports_controller.dart';
import 'package:jolinx_app/features/reports/data/report_repository.dart';
import 'package:jolinx_app/features/reports/data/report_providers.dart';

class FakeReportRepository implements ReportRepository {
  SalesSummary? summaryToReturn;
  List<TopProduct> topProductsToReturn = [];
  List<SalesTrendPoint> trendToReturn = [];
  Object? errorToThrow;

  DateTime? lastSummaryFrom;
  DateTime? lastSummaryTo;
  int? lastTopProductsLimit;
  int? lastTrendDays;

  @override
  Future<SalesSummary> salesSummary({
    DateTime? from,
    DateTime? to,
  }) async {
    lastSummaryFrom = from;
    lastSummaryTo = to;
    if (errorToThrow != null) throw errorToThrow!;
    return summaryToReturn ??
        const SalesSummary(totalSales: 0, totalRevenue: 0, averageSale: 0);
  }

  @override
  Future<List<TopProduct>> topProducts({
    DateTime? from,
    DateTime? to,
    int limit = 5,
  }) async {
    lastTopProductsLimit = limit;
    if (errorToThrow != null) throw errorToThrow!;
    return topProductsToReturn;
  }

  @override
  Future<List<SalesTrendPoint>> salesTrend({int days = 7}) async {
    lastTrendDays = days;
    if (errorToThrow != null) throw errorToThrow!;
    return trendToReturn;
  }

  @override
  Future<BusinessOverview> businessOverview(
      {DateTime? from, DateTime? to}) async {
    throw UnimplementedError();
  }

  @override
  Future<MoneyMovement> moneyMovement({DateTime? from, DateTime? to}) async {
    throw UnimplementedError();
  }

  @override
  Future<PurchasesSummary> purchasesSummary(
      {DateTime? from, DateTime? to}) async {
    throw UnimplementedError();
  }

  @override
  Future<List<SalesByPaymentMethod>> salesByPaymentMethod(
      {DateTime? from, DateTime? to}) async {
    throw UnimplementedError();
  }

  @override
  Future<List<SalesByCategory>> salesByCategory(
      {DateTime? from, DateTime? to}) async {
    throw UnimplementedError();
  }

  @override
  Future<StockSummaryReport> stockSummary(
      {DateTime? from, DateTime? to}) async {
    throw UnimplementedError();
  }

  @override
  Future<StockMovementSummaryReport> stockMovementSummary(
      {DateTime? from, DateTime? to}) async {
    throw UnimplementedError();
  }

  @override
  Future<StockVelocityReport> stockVelocity(
      {DateTime? from, DateTime? to}) async {
    throw UnimplementedError();
  }

  @override
  Future<ExpenseTrendReport> expenseTrend(
      {DateTime? from, DateTime? to}) async {
    throw UnimplementedError();
  }

  @override
  Future<List<ExpenseByPaymentMethod>> expenseByPaymentMethod(
      {DateTime? from, DateTime? to}) async {
    throw UnimplementedError();
  }

  @override
  Future<PurchasesBySupplierReport> purchasesBySupplier(
      {DateTime? from, DateTime? to}) async {
    throw UnimplementedError();
  }

  @override
  Future<ExpenseSummaryReport> getExpenseSummary(
      {DateTime? from, DateTime? to}) async {
    throw UnimplementedError();
  }
}

void main() {
  group('reportDateRange', () {
    test('today starts at local midnight and ends at end of today', () {
      final (from, to) = reportDateRange(ReportPeriod.today);
      final now = DateTime.now();

      expect(from, DateTime(now.year, now.month, now.day));
      expect(to.day, now.day);
      expect(to.hour, 23);
      expect(to.minute, 59);
      expect(to.second, 59);
    });

    test('thisWeek starts on Monday (local weekday 1)', () {
      final (from, _) = reportDateRange(ReportPeriod.thisWeek);
      final today = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);

      expect(DateTime(today.year, today.month, today.day), today);
      expect(from.weekday, DateTime.monday);
    });

    test('lastMonth covers the full previous month', () {
      final (from, to) = reportDateRange(ReportPeriod.lastMonth);
      final now = DateTime.now();
      final firstOfCurrent = DateTime(now.year, now.month, 1);

      expect(from, DateTime(now.year, now.month - 1, 1));
      expect(to.add(const Duration(microseconds: 1)), firstOfCurrent);
    });
  });

  group('parseReportPeriod', () {
    test('parses known names', () {
      expect(parseReportPeriod('today'), ReportPeriod.today);
      expect(parseReportPeriod('lastMonth'), ReportPeriod.lastMonth);
    });

    test('falls back to today for unknown or null', () {
      expect(parseReportPeriod(null), ReportPeriod.today);
      expect(parseReportPeriod('nonsense'), ReportPeriod.today);
    });
  });

  group('ReportsController', () {
    test('initial state is Loading', () {
      final repository = FakeReportRepository();
      final container = ProviderContainer(overrides: [
        reportRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(reportsControllerProvider.notifier);

      expect(controller.state, isA<ReportsLoading>());
    });

    test('load() transitions to Loaded with summary, topProducts and trend',
        () async {
      final repository = FakeReportRepository()
        ..summaryToReturn = const SalesSummary(
            totalSales: 25, totalRevenue: 300000, averageSale: 12000)
        ..topProductsToReturn = const [
          TopProduct(
              productName: 'Mchele', totalQuantity: 150, totalRevenue: 300000),
          TopProduct(
              productName: 'Sukari', totalQuantity: 60, totalRevenue: 120000),
        ]
        ..trendToReturn = const [
          SalesTrendPoint(label: '2026-09-08', revenue: 120000),
          SalesTrendPoint(label: '2026-09-07', revenue: 50000),
        ];
      final container = ProviderContainer(overrides: [
        reportRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(reportsControllerProvider.notifier);

      await controller.load();

      final state = controller.state as ReportsLoaded;
      expect(state.summary.totalSales, 25);
      expect(state.summary.totalRevenue, 300000);
      expect(state.summary.averageSale, 12000);
      expect(state.topProducts, hasLength(2));
      expect(state.topProducts[0].productName, 'Mchele');
      expect(state.trend, hasLength(2));
      expect(state.trend[0].label, '2026-09-08');
    });

    test('load() queries today range and 7-day trend by default', () async {
      final repository = FakeReportRepository();
      final container = ProviderContainer(overrides: [
        reportRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(reportsControllerProvider.notifier);

      await controller.load();

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      expect(repository.lastSummaryFrom, todayStart);
      expect(
          repository.lastSummaryTo,
          todayStart
              .add(const Duration(days: 1))
              .subtract(const Duration(microseconds: 1)));
      expect(repository.lastTopProductsLimit, 5);
      expect(repository.lastTrendDays, 7);
    });

    test('load(period: lastMonth) delegates the previous-month range',
        () async {
      final repository = FakeReportRepository();
      final container = ProviderContainer(overrides: [
        reportRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(reportsControllerProvider.notifier);

      await controller.load(period: ReportPeriod.lastMonth);

      final now = DateTime.now();
      expect(repository.lastSummaryFrom, DateTime(now.year, now.month - 1, 1));
      expect(
        repository.lastSummaryTo!.add(const Duration(microseconds: 1)),
        DateTime(now.year, now.month, 1),
      );
    });

    test('load() failure transitions to Failure', () async {
      final repository = FakeReportRepository()
        ..errorToThrow = ServerException('Backend crashed');
      final container = ProviderContainer(overrides: [
        reportRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(reportsControllerProvider.notifier);

      await controller.load();

      final state = controller.state as ReportsFailure;
      expect(state.message, 'Backend crashed');
    });

    test('load() resets to Loading before re-fetching', () async {
      final repository = FakeReportRepository();
      final container = ProviderContainer(overrides: [
        reportRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(reportsControllerProvider.notifier);

      // Seed a non-Loading state so the re-fetch transition to Loading is
      // observable (re-setting the identical initial Loading is a no-op).
      await controller.load();
      expect(controller.state, isA<ReportsLoaded>());

      final states = <ReportsState>[];
      container.listen<ReportsState>(reportsControllerProvider, (_, next) {
        states.add(next);
      });

      await controller.load();

      expect(states.first, isA<ReportsLoading>());
      expect(states.last, isA<ReportsLoaded>());
    });
  });
}
