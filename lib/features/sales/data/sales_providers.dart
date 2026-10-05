import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/core_providers.dart'
    show localSalesServiceProvider, deviceIdentityProvider, branchCacheProvider;
import '../../../core/network/api_routes.dart';
import '../../../core/network/connectivity_monitor.dart';
import '../../../core/sync/local_sales_service.dart';
import '../../../core/sync/sync_engine.dart';
import '../../authentication/application/auth_controller.dart';
import '../../authentication/data/auth_providers.dart';
import '../application/cart_controller.dart';
import '../application/checkout_controller.dart';
import '../application/pos_catalog_controller.dart';
import '../application/sales_history_controller.dart';
import 'offline_sale_recorder.dart';
import 'sale_repository.dart';

final saleRepositoryProvider = Provider<SaleRepository>(
  (ref) => SaleRepository(apiClient: ref.watch(apiClientProvider)),
);

final sessionContextProvider = Provider<(String?, String?)>((ref) {
  final state = ref.watch(authControllerProvider);
  if (state is AuthAuthenticated) {
    return (state.session.user.tenantId, state.session.user.id);
  }
  return (null, null);
});

final posCatalogControllerProvider =
    NotifierProvider<PosCatalogController, PosCatalogState>(
  PosCatalogController.new,
);

final connectivityMonitorProvider =
    NotifierProvider<ConnectivityMonitor, ConnectionQuality>(
  ConnectivityMonitor.new,
);

final connectionQualityProvider = Provider<ConnectionQuality>(
  (ref) => ref.watch(connectivityMonitorProvider),
);

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine(
    salesService: ref.watch(localSalesServiceProvider),
    repository: ref.watch(saleRepositoryProvider),
  );
  final monitor = ref.watch(connectivityMonitorProvider.notifier);
  Timer? timer;

  Future<void> drainIfOnline() async {
    if (ref.read(connectivityMonitorProvider) == ConnectionQuality.online ||
        ref.read(connectivityMonitorProvider) == ConnectionQuality.unknown) {
      await engine.drain();
    }
  }

  engine.onDrained = (outcome) async {
    try {
      await ref.read(posCatalogControllerProvider.notifier).refresh();
    } on Exception {
      // Offline again — the next cycle retries.
    }
    if (outcome.synced > 0) {
      ref.read(syncStatusProvider.notifier).noteSyncCompleted();
    }
    ref.read(syncStatusProvider.notifier).refresh();
  };

  monitor.onRestored = drainIfOnline;
  timer = Timer.periodic(const Duration(seconds: 60), (_) => drainIfOnline());

  ref.onDispose(() => timer?.cancel());
  return engine;
});

class SyncStatusState {
  const SyncStatusState({
    this.pendingCount = 0,
    this.conflictCount = 0,
    this.lastSyncAt,
  });

  final int pendingCount;
  final int conflictCount;
  final DateTime? lastSyncAt;

  SyncStatusState copyWith({
    int? pendingCount,
    int? conflictCount,
    DateTime? lastSyncAt,
  }) =>
      SyncStatusState(
        pendingCount: pendingCount ?? this.pendingCount,
        conflictCount: conflictCount ?? this.conflictCount,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      );
}

final syncStatusProvider =
    NotifierProvider<SyncStatusController, SyncStatusState>(
  SyncStatusController.new,
);

class SyncStatusController extends Notifier<SyncStatusState> {
  @override
  SyncStatusState build() {
    Future.microtask(() => refresh());
    return const SyncStatusState();
  }

  LocalSalesService get _service => ref.read(localSalesServiceProvider);

  Future<void> refresh() async {
    final pending = await _service.pendingSaleCount();
    final conflicts = await _service.conflictedSaleCount();
    state = state.copyWith(
      pendingCount: pending,
      conflictCount: conflicts,
    );
  }

  void noteSyncCompleted() {
    state = state.copyWith(lastSyncAt: DateTime.now().toUtc());
  }
}

final cartControllerProvider = NotifierProvider<CartController, CartState>(
  CartController.new,
);

final posBranchIdProvider = Provider<Future<String?> Function()>((ref) {
  return () async {
    final auth = ref.read(authControllerProvider);
    if (auth is! AuthAuthenticated) {
      return null;
    }

    // Try cache first (critical for offline scenarios)
    final branchCache = ref.read(branchCacheProvider);
    final cached = await branchCache.getCached();
    if (cached != null) {
      return cached;
    }

    // Fetch from API
    final response =
        await ref.watch(apiClientProvider).get<Map<String, dynamic>>(
      ApiRoutes.v1('/branches'),
      query: {'page': 1, 'pageSize': 1},
    );
    final items = response.data?['items'] as List? ?? [];
    if (items.isEmpty) {
      return null;
    }
    final branchId = (items.first as Map<String, dynamic>)['id'] as String?;
    final branchName = (items.first as Map<String, dynamic>)['name'] as String?;

    // Cache for offline use
    if (branchId != null) {
      await branchCache.store(branchId: branchId, branchName: branchName);
    }

    return branchId;
  };
});

final offlineSaleRecorderProvider = Provider<OfflineSaleRecorder>((ref) {
  final service = ref.watch(localSalesServiceProvider);
  final identity = ref.watch(deviceIdentityProvider);
  return OfflineSaleRecorder(
    salesDao: service.sales,
    catalogDao: service.catalog,
    tenantIdOf: () async => ref.read(sessionContextProvider).$1,
    deviceIdOf: () => identity.get(),
    userIdOf: () async => ref.read(sessionContextProvider).$2,
    branchIdOf: () => ref.read(posBranchIdProvider)(),
  );
});

final checkoutControllerProvider =
    NotifierProvider<CheckoutController, CheckoutState>(
  CheckoutController.new,
);

final salesHistoryControllerProvider =
    NotifierProvider<SalesHistoryController, SalesHistoryState>(
  SalesHistoryController.new,
);
