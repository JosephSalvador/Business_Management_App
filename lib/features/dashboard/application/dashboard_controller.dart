import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/core_providers.dart' show offlineCacheDaoProvider;
import '../../../core/storage/offline_cache_dao.dart';
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
    this.isFromCache = false,
    this.lastUpdated,
  });

  final DashboardSummary summary;
  final List<Map<String, dynamic>> lowStock;
  final List<Map<String, dynamic>> recentActivity;
  final List<SalesTrendPoint> trendData;
  final List<Map<String, dynamic>> topProducts;
  final bool isFromCache;
  final DateTime? lastUpdated;
}

class DashboardFailure extends DashboardState {
  const DashboardFailure(this.message);

  final String message;
}

class DashboardController extends Notifier<DashboardState> {
  @override
  DashboardState build() => const DashboardLoading();

  DashboardRepository get _repository => ref.read(dashboardRepositoryProvider);
  OfflineCacheDao get _cacheDao => ref.read(offlineCacheDaoProvider);

  Future<void> load({int trendDays = 30}) async {
    // 1. Instantly restore cached snapshot if present (zero-spinner open)
    final cached = await _cacheDao.load('dashboard');
    if (cached != null) {
      try {
        final summary = DashboardSummary.fromJson(
            cached['summary'] as Map<String, dynamic>);
        final lowStock =
            (cached['lowStock'] as List).cast<Map<String, dynamic>>();
        final recentActivity =
            (cached['recentActivity'] as List).cast<Map<String, dynamic>>();
        final trendData = (cached['trendData'] as List)
            .map((e) => SalesTrendPoint.fromJson(e as Map<String, dynamic>))
            .toList();
        final topProducts =
            (cached['topProducts'] as List).cast<Map<String, dynamic>>();
        final lastUpdated = await _cacheDao.getLastUpdated('dashboard');

        state = DashboardLoaded(
          summary: summary,
          lowStock: lowStock,
          recentActivity: recentActivity,
          trendData: trendData,
          topProducts: topProducts,
          isFromCache: true,
          lastUpdated: lastUpdated,
        );
      } catch (_) {
        state = const DashboardLoading();
      }
    } else {
      state = const DashboardLoading();
    }

    // 2. Background revalidation from server
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
      final summary = results[0] as DashboardSummary;
      final lowStock = (results[1] as List).cast<Map<String, dynamic>>();
      final recentActivity = (results[2] as List).cast<Map<String, dynamic>>();
      final trendData = (results[3] as List)
          .map((e) => SalesTrendPoint.fromJson(e as Map<String, dynamic>))
          .toList();
      final topProducts = ((results[4] as Map<String, dynamic>)['products']
                  as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          ((results[4] as Map<String, dynamic>)['items']
                  as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];

      state = DashboardLoaded(
        summary: summary,
        lowStock: lowStock,
        recentActivity: recentActivity,
        trendData: trendData,
        topProducts: topProducts,
        isFromCache: false,
        lastUpdated: DateTime.now(),
      );

      // Persist snapshot to local encrypted cache
      await _cacheDao.save('dashboard', {
        'summary': summary.toJson(),
        'lowStock': lowStock,
        'recentActivity': recentActivity,
        'trendData': trendData.map((e) => e.toJson()).toList(),
        'topProducts': topProducts,
      });
    } on AppException catch (error) {
      // If we already have a loaded state (from cache or previous fetch), don't wipe it out!
      if (state is! DashboardLoaded) {
        state = DashboardFailure(error.message);
      }
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
