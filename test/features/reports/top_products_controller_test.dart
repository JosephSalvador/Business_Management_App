import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/di/core_providers.dart' show offlineCacheDaoProvider;
import 'package:jolinx_app/core/storage/offline_cache_dao.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/features/reports/application/reports_controller.dart';
import 'package:jolinx_app/features/reports/application/top_products_controller.dart';
import 'package:jolinx_app/features/reports/data/report_repository.dart';
import 'package:jolinx_app/features/reports/data/report_providers.dart';

class FakeReportRepository implements ReportRepository {
  List<TopProduct> productsToReturn = [];
  Object? errorToThrow;

  DateTime? lastFrom;
  DateTime? lastTo;
  int? lastLimit;

  @override
  Future<SalesSummary> salesSummary({
    DateTime? from,
    DateTime? to,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<TopProduct>> topProducts({
    DateTime? from,
    DateTime? to,
    int limit = 5,
  }) async {
    lastFrom = from;
    lastTo = to;
    lastLimit = limit;
    if (errorToThrow != null) throw errorToThrow!;
    return productsToReturn;
  }

  @override
  Future<List<SalesTrendPoint>> salesTrend({int days = 7}) async {
    throw UnimplementedError();
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

class FakeOfflineCacheDao implements OfflineCacheDao {
  final Map<String, Map<String, dynamic>> cachedData = {};
  final Map<String, DateTime> lastUpdatedTimes = {};

  @override
  Future<void> save(String key, Map<String, dynamic> data) async {
    cachedData[key] = data;
    lastUpdatedTimes[key] = DateTime.now();
  }

  @override
  Future<Map<String, dynamic>?> load(String key) async => cachedData[key];

  @override
  Future<DateTime?> getLastUpdated(String key) async => lastUpdatedTimes[key];

  @override
  Future<void> clear(String key) async {
    cachedData.remove(key);
    lastUpdatedTimes.remove(key);
  }
}

void main() {
  group('TopProductsController', () {
    late FakeOfflineCacheDao fakeCache;

    setUp(() {
      fakeCache = FakeOfflineCacheDao();
    });

    test('initial state is Loading', () {
      final repository = FakeReportRepository();
      final container = ProviderContainer(overrides: [
        reportRepositoryProvider.overrideWithValue(repository),
        offlineCacheDaoProvider.overrideWithValue(fakeCache),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(topProductsControllerProvider.notifier);

      expect(controller.state, isA<TopProductsLoading>());
    });

    test('load() transitions to Loaded with products', () async {
      final repository = FakeReportRepository()
        ..productsToReturn = const [
          TopProduct(
              productName: 'Mchele', totalQuantity: 150, totalRevenue: 300000),
          TopProduct(
              productName: 'Sukari', totalQuantity: 60, totalRevenue: 120000),
        ];
      final container = ProviderContainer(overrides: [
        reportRepositoryProvider.overrideWithValue(repository),
        offlineCacheDaoProvider.overrideWithValue(fakeCache),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(topProductsControllerProvider.notifier);

      await controller.load();

      final state = controller.state as TopProductsLoaded;
      expect(state.products, hasLength(2));
      expect(state.products[0].productName, 'Mchele');
    });

    test('load() requests the today range with a higher limit', () async {
      final repository = FakeReportRepository();
      final container = ProviderContainer(overrides: [
        reportRepositoryProvider.overrideWithValue(repository),
        offlineCacheDaoProvider.overrideWithValue(fakeCache),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(topProductsControllerProvider.notifier);

      await controller.load(period: ReportPeriod.today, limit: 25);

      final now = DateTime.now();
      expect(repository.lastFrom, DateTime(now.year, now.month, now.day));
      expect(repository.lastLimit, 25);
    });

    test('load(period: lastMonth) delegates the previous-month range',
        () async {
      final repository = FakeReportRepository();
      final container = ProviderContainer(overrides: [
        reportRepositoryProvider.overrideWithValue(repository),
        offlineCacheDaoProvider.overrideWithValue(fakeCache),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(topProductsControllerProvider.notifier);

      await controller.load(period: ReportPeriod.lastMonth, limit: 25);

      final now = DateTime.now();
      expect(repository.lastFrom, DateTime(now.year, now.month - 1, 1));
      expect(
        repository.lastTo!.add(const Duration(microseconds: 1)),
        DateTime(now.year, now.month, 1),
      );
    });

    test('load() failure transitions to Failure', () async {
      final repository = FakeReportRepository()
        ..errorToThrow = ServerException('Backend crashed');
      final container = ProviderContainer(overrides: [
        reportRepositoryProvider.overrideWithValue(repository),
        offlineCacheDaoProvider.overrideWithValue(fakeCache),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(topProductsControllerProvider.notifier);

      await controller.load();

      final state = controller.state as TopProductsFailure;
      expect(state.message, 'Backend crashed');
    });

    test('load() instantly populates cached products when offline', () async {
      fakeCache.cachedData['top_products_today'] = {
        'items': [
          const TopProduct(
            productName: 'Chai Jaba',
            totalQuantity: 20,
            totalRevenue: 20000,
            totalCost: 10000,
            totalProfit: 10000,
            marginPercent: 50.0,
          ).toJson(),
        ],
      };
      final repository = FakeReportRepository()
        ..errorToThrow = ServerException('Network down');
      final container = ProviderContainer(overrides: [
        reportRepositoryProvider.overrideWithValue(repository),
        offlineCacheDaoProvider.overrideWithValue(fakeCache),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(topProductsControllerProvider.notifier);

      await controller.load(period: ReportPeriod.today);

      final state = controller.state;
      expect(state, isA<TopProductsLoaded>());
      final loaded = state as TopProductsLoaded;
      expect(loaded.isFromCache, isTrue);
      expect(loaded.products, hasLength(1));
      expect(loaded.products[0].productName, 'Chai Jaba');
      expect(loaded.products[0].totalProfit, 10000);
    });
  });
}
