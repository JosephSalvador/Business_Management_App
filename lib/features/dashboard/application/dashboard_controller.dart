import 'dart:async' as async;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/core_providers.dart' show offlineCacheDaoProvider;
import '../../../core/storage/offline_cache_dao.dart';
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
    // 1. Instantly restore offline state from local SQLite or cached snapshot if present
    final cached = await _cacheDao.load('dashboard');
    final offlineState = await _buildOfflineDashboardState(trendDays, cached);
    if (offlineState != null) {
      state = offlineState;
    } else if (cached != null) {
      try {
        final summary = DashboardSummary.fromJson(
            cached['summary'] as Map<String, dynamic>);
        final lowStock =
            (cached['lowStock'] as List).cast<Map<String, dynamic>>();
        final recentActivity =
            (cached['recentActivity'] as List).cast<Map<String, dynamic>>();
        var trendData = (cached['trendData'] as List)
            .map((e) => SalesTrendPoint.fromJson(e as Map<String, dynamic>))
            .toList();
        if (trendData.isEmpty) {
          final now = DateTime.now();
          trendData = List.generate(
            trendDays,
            (i) => SalesTrendPoint(
              label: now
                  .subtract(Duration(days: trendDays - 1 - i))
                  .toIso8601String()
                  .substring(0, 10),
              saleCount: 0,
              revenue: 0,
            ),
          );
        }
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

  Future<DashboardLoaded?> _buildOfflineDashboardState(
    int trendDays,
    Map<String, dynamic>? cached,
  ) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toUtc();
      final todayEnd =
          DateTime(now.year, now.month, now.day, 23, 59, 59, 999).toUtc();
      final windowStart = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: trendDays - 1))
          .toUtc();

      // Query local authoritative SQLite sales
      final windowSales = await _salesService.sales
          .listSales(from: windowStart, to: todayEnd, limit: 5000);

      if (windowSales.isEmpty && cached == null) {
        return null;
      }

      var todayRevenue = 0.0;
      final bucketMap = <String, (int, double)>{};

      for (final sale in windowSales) {
        final effective = sale.saleDate.toLocal();
        final dateKey = effective.toIso8601String().substring(0, 10);
        final current = bucketMap[dateKey] ?? (0, 0.0);
        bucketMap[dateKey] = (current.$1 + 1, current.$2 + sale.totalAmount);

        if (sale.saleDate.isAfter(todayStart) &&
            sale.saleDate.isBefore(todayEnd)) {
          todayRevenue += sale.totalAmount;
        }
      }

      final trendData = List.generate(trendDays, (i) {
        final day = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: trendDays - 1 - i));
        final dateKey = day.toIso8601String().substring(0, 10);
        final stats = bucketMap[dateKey] ?? (0, 0.0);
        return SalesTrendPoint(
          label: dateKey,
          saleCount: stats.$1,
          revenue: stats.$2,
        );
      });

      final recentSales = await _salesService.sales.listSales(limit: 10);
      final recentActivity = recentSales
          .map((s) => {
                'id': s.id,
                'type': 'sale',
                'description':
                    'Mauzo #${s.number.isNotEmpty ? s.number : (s.id.length >= 8 ? s.id.substring(0, 8) : s.id)}',
                'amount': s.totalAmount,
                'createdAt': s.saleDate.toIso8601String(),
              })
          .toList();

      // Top products aggregated from local sales lines
      final productMap = <String, (int, double)>{};
      for (final sale in windowSales) {
        for (final line in sale.lines) {
          final current = productMap[line.productName] ?? (0, 0.0);
          productMap[line.productName] = (
            current.$1 + line.quantity.toInt(),
            current.$2 + line.lineTotal,
          );
        }
      }
      final sortedProducts = productMap.entries.toList()
        ..sort((a, b) => b.value.$2.compareTo(a.value.$2));
      final topProducts = sortedProducts
          .take(5)
          .map((e) => {
                'productName': e.key,
                'quantity': e.value.$1,
                'revenue': e.value.$2,
              })
          .toList();

      // Fallbacks from cache if available
      final cachedSummary = cached?['summary'] != null
          ? DashboardSummary.fromJson(
              cached!['summary'] as Map<String, dynamic>)
          : null;
      final cachedLowStock =
          (cached?['lowStock'] as List?)?.cast<Map<String, dynamic>>() ??
              const <Map<String, dynamic>>[];

      final summary = DashboardSummary(
        branchName: cachedSummary?.branchName ?? 'Duka Langu',
        revenueToday: todayRevenue > 0
            ? todayRevenue
            : (cachedSummary?.revenueToday ?? 0),
        totalProducts: cachedSummary?.totalProducts ?? 0,
      );

      final lastUpdated = await _cacheDao.getLastUpdated('dashboard');

      return DashboardLoaded(
        summary: summary,
        lowStock: cachedLowStock,
        recentActivity: recentActivity.isNotEmpty
            ? recentActivity
            : ((cached?['recentActivity'] as List?)
                    ?.cast<Map<String, dynamic>>() ??
                const []),
        trendData: trendData,
        topProducts: topProducts.isNotEmpty
            ? topProducts
            : ((cached?['topProducts'] as List?)
                    ?.cast<Map<String, dynamic>>() ??
                const []),
        isFromCache: true,
        lastUpdated: lastUpdated ?? DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

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

      final localSales = await _salesService.sales.listSales(limit: 100);
      final pendingSales =
          localSales.where((sale) => sale.pendingLocally).toList();

      // Keep local pending sales visible until the server confirms them.
      var pendingRevenue = 0.0;
      var pendingCount = 0;
      try {
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final todayEnd = todayStart.add(const Duration(days: 1));
        for (final s in pendingSales) {
          final localEffective = s.saleDate.toLocal();
          if (localEffective.isAfter(todayStart) &&
              localEffective.isBefore(todayEnd)) {
            pendingRevenue += s.totalAmount;
            pendingCount += 1;
          }
        }
      } catch (_) {}

      final mergedActivity = [
        ...pendingSales.take(5).map((sale) => {
              'action': 'sale',
              'entityType': 'sale',
              'entityName': 'Receipt ${sale.number}',
              'amount': sale.totalAmount,
              'status': 'Pending sync',
              'occurredAt': sale.saleDate.toIso8601String(),
            }),
        ...recentActivity,
      ];
      final mergedTopProducts = <String, Map<String, dynamic>>{
        for (final item in topProducts)
          (item['productName'] ?? item['name'] ?? '').toString(): item,
      };
      for (final sale in pendingSales) {
        for (final line in sale.lines) {
          final name = line.productName;
          final current = mergedTopProducts[name];
          mergedTopProducts[name] = {
            'productName': name,
            'quantity': (current?['quantity'] as num? ?? 0) + line.quantity,
            'revenue': (current?['revenue'] as num? ?? 0) + line.lineTotal,
          };
        }
      }

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
        recentActivity: mergedActivity,
        trendData: trendData,
        topProducts: mergedTopProducts.values.take(5).toList(),
        isFromCache: false,
        lastUpdated: DateTime.now(),
      );

      // Persist snapshot to local encrypted cache
      try {
        await _cacheDao.save('dashboard', {
          'summary': effectiveSummary.toJson(),
          'lowStock': lowStock,
          'recentActivity': mergedActivity,
          'trendData': trendData.map((e) => e.toJson()).toList(),
          'topProducts': mergedTopProducts.values.take(5).toList(),
        });
      } catch (_) {}
    } catch (error) {
      final cached = await _cacheDao.load('dashboard');
      final offlineState = await _buildOfflineDashboardState(trendDays, cached);
      if (offlineState != null) {
        state = offlineState;
        return;
      }

      if (state is! DashboardLoaded) {
        // Try restoring from offline cache if not already loaded
        if (cached != null) {
          try {
            final summary = DashboardSummary.fromJson(
                cached['summary'] as Map<String, dynamic>);
            final lowStock =
                (cached['lowStock'] as List).cast<Map<String, dynamic>>();
            final recentActivity =
                (cached['recentActivity'] as List).cast<Map<String, dynamic>>();
            var trendData = (cached['trendData'] as List)
                .map((e) => SalesTrendPoint.fromJson(e as Map<String, dynamic>))
                .toList();
            if (trendData.isEmpty) {
              final now = DateTime.now();
              trendData = List.generate(
                trendDays,
                (i) => SalesTrendPoint(
                  label: now
                      .subtract(Duration(days: trendDays - 1 - i))
                      .toIso8601String()
                      .substring(0, 10),
                  saleCount: 0,
                  revenue: 0,
                ),
              );
            }
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
      return await _repository.lowStock().timeout(const Duration(seconds: 10));
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
