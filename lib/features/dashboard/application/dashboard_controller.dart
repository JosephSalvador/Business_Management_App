import 'dart:async' as async;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/core_providers.dart' show offlineCacheDaoProvider;
import '../../../core/storage/offline_cache_dao.dart';
import '../../../core/storage/tables.dart' show LocalSaleStatus;
import '../../../core/sync/local_sales_service.dart';
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

  LocalSalesService get _salesService => ref.read(localSalesServiceProvider);

  Future<void> _fetch({int trendDays = 30}) async {
    try {
      final summaryFuture =
          _repository.summary().timeout(const Duration(seconds: 15));
      final lowStockFuture = _loadLowStockSafe();
      final recentActivityFuture = _loadRecentActivitySafe();
      final trendFuture = _loadTrendRawSafe(trendDays);
      final topProductsFuture = _loadTopProductsSafe();

      final summary = await summaryFuture;
      final lowStock = await lowStockFuture;
      final recentActivity = await recentActivityFuture;
      final rawTrend = await trendFuture;
      final topProducts = await topProductsFuture;

      final trendData =
          rawTrend.map((e) => SalesTrendPoint.fromJson(e)).toList();

      // Incorporate local pending sales from today for instant UI reflection
      var pendingRevenue = 0.0;
      var pendingCount = 0;
      try {
        final pendingSales =
            await _salesService.sales.byStatus(LocalSaleStatus.pending);
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final todayEnd = todayStart.add(const Duration(days: 1));
        for (final s in pendingSales) {
          final localEffective = s.effectiveAt.toLocal();
          if (localEffective.isAfter(todayStart) &&
              localEffective.isBefore(todayEnd)) {
            pendingRevenue += s.totalEstimate;
            pendingCount += 1;
          }
        }
      } catch (_) {}

      final effectiveSummary = pendingRevenue > 0
          ? DashboardSummary(
              branchName: summary.branchName,
              revenueToday: summary.revenueToday + pendingRevenue,
              totalProducts: summary.totalProducts,
            )
          : summary;

      if (pendingRevenue > 0 && trendData.isNotEmpty) {
        final todayStr = DateTime.now().toIso8601String().substring(0, 10);
        final todayIndex =
            trendData.indexWhere((p) => p.label.startsWith(todayStr));
        if (todayIndex >= 0) {
          final current = trendData[todayIndex];
          trendData[todayIndex] = SalesTrendPoint(
            label: current.label,
            saleCount: current.saleCount + pendingCount,
            revenue: current.revenue + pendingRevenue,
          );
        } else {
          trendData.add(SalesTrendPoint(
            label: todayStr,
            saleCount: pendingCount,
            revenue: pendingRevenue,
          ));
        }
      }

      state = DashboardLoaded(
        summary: effectiveSummary,
        lowStock: lowStock,
        recentActivity: recentActivity,
        trendData: trendData,
        topProducts: topProducts,
        isFromCache: false,
        lastUpdated: DateTime.now(),
      );

      // Persist snapshot to local encrypted cache
      try {
        await _cacheDao.save('dashboard', {
          'summary': effectiveSummary.toJson(),
          'lowStock': lowStock,
          'recentActivity': recentActivity,
          'trendData': trendData.map((e) => e.toJson()).toList(),
          'topProducts': topProducts,
        });
      } catch (_) {}
    } catch (error) {
      if (state is! DashboardLoaded) {
        // Try restoring from offline cache if not already loaded
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
            return;
          } catch (_) {}
        }

        final message = error is AppException
            ? error.message
            : error is async.TimeoutException
                ? 'Muunganisho ulikwama. Jaribu tena.'
                : 'Imeshindwa kupakia dashibodi.';
        state = DashboardFailure(message);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _loadLowStockSafe() async {
    try {
      return await _repository
          .lowStock()
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadRecentActivitySafe() async {
    try {
      return await _repository
          .recentActivity()
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadTrendRawSafe(int days) async {
    try {
      return await _repository
          .salesTrend(days: days)
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadTopProductsSafe() async {
    try {
      final rawTop = await _repository
          .topProducts(limit: 5)
          .timeout(const Duration(seconds: 10));
      final list = (rawTop['products'] as List<dynamic>?) ??
          (rawTop['items'] as List<dynamic>?) ??
          (rawTop['data'] as List<dynamic>?);
      if (list != null) {
        return list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  Future<List<SalesTrendPoint>> loadSalesTrend({int days = 7}) async {
    try {
      final items = await _repository
          .salesTrend(days: days)
          .timeout(const Duration(seconds: 10));
      return items.map((e) => SalesTrendPoint.fromJson(e)).toList();
    } catch (_) {
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
