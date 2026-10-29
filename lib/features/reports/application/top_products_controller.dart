import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/core_providers.dart' show offlineCacheDaoProvider;
import '../../../core/storage/offline_cache_dao.dart';
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
  const TopProductsLoaded(
    this.products, {
    this.isFromCache = false,
    this.lastUpdated,
  });

  final List<TopProduct> products;
  final bool isFromCache;
  final DateTime? lastUpdated;
}

class TopProductsFailure extends TopProductsState {
  const TopProductsFailure(this.message);

  final String message;
}

class TopProductsController extends Notifier<TopProductsState> {
  @override
  TopProductsState build() => const TopProductsLoading();

  ReportRepository get _repository => ref.read(reportRepositoryProvider);
  OfflineCacheDao get _cacheDao => ref.read(offlineCacheDaoProvider);

  Future<void> load({
    ReportPeriod period = ReportPeriod.today,
    int limit = 25,
  }) async {
    final cacheKey = 'top_products_${period.name}';

    // 1. Instantly show cached items if available
    final cached = await _cacheDao.load(cacheKey);
    if (cached != null && cached['items'] is List) {
      try {
        final list = (cached['items'] as List)
            .map((e) => TopProduct.fromJson(e as Map<String, dynamic>))
            .toList();
        final lastUpdated = await _cacheDao.getLastUpdated(cacheKey);
        state = TopProductsLoaded(
          list,
          isFromCache: true,
          lastUpdated: lastUpdated,
        );
      } catch (_) {
        if (state is! TopProductsLoaded) {
          state = const TopProductsLoading();
        }
      }
    } else if (state is! TopProductsLoaded) {
      state = const TopProductsLoading();
    }

    // 2. Fetch fresh from server
    try {
      final (from, to) = reportDateRange(period);
      final products =
          await _repository.topProducts(from: from, to: to, limit: limit);
      state = TopProductsLoaded(
        products,
        isFromCache: false,
        lastUpdated: DateTime.now(),
      );

      // Save to cache
      await _cacheDao.save(cacheKey, {
        'items': products.map((p) => p.toJson()).toList(),
      });
    } catch (_) {
      if (state is! TopProductsLoaded) {
        state = const TopProductsLoaded([]);
      }
    }
  }
}
