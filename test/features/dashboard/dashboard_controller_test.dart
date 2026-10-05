import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/features/dashboard/application/dashboard_controller.dart';
import 'package:jolinx_app/features/dashboard/data/dashboard_repository.dart';
import 'package:jolinx_app/app/providers.dart';

class FakeDashboardRepository implements DashboardRepository {
  DashboardSummary summaryResult = const DashboardSummary(
    branchName: 'Dar es Salaam',
    revenueToday: 125000,
    totalProducts: 42,
  );
  List<Map<String, dynamic>> lowStockResult = [
    {'id': 'p1', 'name': 'Mchele', 'quantity': 2},
  ];
  List<Map<String, dynamic>> recentActivityResult = [
    {'id': 'a1', 'type': 'sale', 'amount': 5000},
  ];
  List<Map<String, dynamic>> salesTrendResult = [
    {'label': '2026-08-25', 'saleCount': 1, 'revenue': 10000, 'tax': 0},
  ];
  Map<String, dynamic> topProductsResult = {
    'items': <Map<String, dynamic>>[],
  };
  Object? summaryError;
  Object? lowStockError;
  Object? recentActivityError;
  Object? salesTrendError;
  Object? topProductsError;

  @override
  Future<DashboardSummary> summary() async {
    if (summaryError != null) throw summaryError as Exception;
    return summaryResult;
  }

  @override
  Future<List<Map<String, dynamic>>> lowStock({int limit = 5}) async {
    if (lowStockError != null) throw lowStockError as Exception;
    return lowStockResult;
  }

  @override
  Future<List<Map<String, dynamic>>> recentActivity({int limit = 5}) async {
    if (recentActivityError != null) throw recentActivityError as Exception;
    return recentActivityResult;
  }

  @override
  Future<List<Map<String, dynamic>>> salesTrend({int days = 7}) async {
    if (salesTrendError != null) throw salesTrendError as Exception;
    return salesTrendResult;
  }

  @override
  Future<Map<String, dynamic>> topProducts({
    int limit = 5,
    DateTime? from,
    DateTime? to,
  }) async {
    if (topProductsError != null) throw topProductsError as Exception;
    return topProductsResult;
  }
}

void main() {
  group('DashboardController', () {
    late FakeDashboardRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = FakeDashboardRepository();
      container = ProviderContainer(overrides: [
        dashboardRepositoryProvider.overrideWithValue(repository),
      ]);
    });

    tearDown(() => container.dispose());

    DashboardController controller() =>
        container.read(dashboardControllerProvider.notifier);

    test('initial state is Loading', () {
      expect(
        container.read(dashboardControllerProvider),
        isA<DashboardLoading>(),
      );
    });

    test('load() transitions to Loaded with summary, lowStock, recentActivity',
        () async {
      await controller().load(trendDays: 7);

      final state = container.read(dashboardControllerProvider);
      expect(state, isA<DashboardLoaded>());
      final loaded = state as DashboardLoaded;
      expect(loaded.summary.branchName, 'Dar es Salaam');
      expect(loaded.summary.revenueToday, 125000);
      expect(loaded.summary.totalProducts, 42);
      expect(loaded.lowStock, hasLength(1));
      expect(loaded.recentActivity, hasLength(1));
    });

    test('load() failure transitions to Failure', () async {
      repository.summaryError = ServerException('Dashboard unavailable');

      await controller().load(trendDays: 7);

      final state = container.read(dashboardControllerProvider);
      expect(state, isA<DashboardFailure>());
      expect((state as DashboardFailure).message, 'Dashboard unavailable');
    });

    test('loadSalesTrend returns parsed data points', () async {
      final points = await controller().loadSalesTrend(days: 7);

      expect(points, hasLength(1));
      expect(points[0].label, '2026-08-25');
      expect(points[0].revenue, 10000);
    });

    test('loadSalesTrend returns zeroed fallback on error', () async {
      repository.salesTrendError = ServerException('fail');

      final points = await controller().loadSalesTrend(days: 3);

      expect(points, hasLength(3));
      expect(points.every((p) => p.revenue == 0), isTrue);
      expect(points.every((p) => p.saleCount == 0), isTrue);
    });
  });
}
