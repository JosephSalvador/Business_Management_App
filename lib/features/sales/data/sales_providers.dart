import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/core_providers.dart'
    show
        localSalesServiceProvider,
        deviceIdentityProvider,
        branchCacheProvider,
        localDatabaseProvider,
        offlineCacheDaoProvider;
import '../../../core/network/api_routes.dart';
import '../../../core/network/connectivity_monitor.dart';
import '../../../core/storage/local_database.dart' show LocalSale;
import '../../../core/storage/sync_queue_dao.dart';
import '../../../core/sync/local_sales_service.dart';
import '../../../core/sync/sync_engine.dart';
import '../../authentication/application/auth_controller.dart';
import '../../authentication/data/auth_providers.dart';
import '../application/cart_controller.dart';
import '../application/checkout_controller.dart';
import '../application/pos_catalog_controller.dart';
import '../application/sales_history_controller.dart';
import '../domain/sale.dart' show CartLine;
import '../../customers/data/customer_providers.dart'
    show customerRepositoryProvider, offlineCustomerDebtServiceProvider;
import '../../dashboard/data/dashboard_providers.dart';
import '../../finance/data/expense_providers.dart'
    show
        expenseRepositoryProvider,
        expensesControllerProvider,
        offlineExpenseServiceProvider;
import '../../finance/data/money_account_providers.dart'
    show moneyAccountRepositoryProvider;
import '../../invoices/data/invoice_providers.dart'
    show deliveryNoteRepositoryProvider, invoiceRepositoryProvider;
import '../../inventory/data/inventory_providers.dart'
    show inventoryRepositoryProvider;
import '../../products/data/product_providers.dart'
    show productRepositoryProvider;
import '../../suppliers/data/supplier_providers.dart'
    show supplierRepositoryProvider;
import '../../purchases/data/purchase_providers.dart'
    show purchaseRepositoryProvider;
import 'offline_parked_cart_service.dart';
import 'offline_sale_recorder.dart';
import 'offline_shift_register_service.dart';
import 'sale_repository.dart';

export 'offline_parked_cart_service.dart' show ParkedCart;
export 'offline_shift_register_service.dart' show ShiftSummary;

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
  dynamic expenseRepo;
  dynamic customerRepo;
  dynamic inventoryRepo;
  dynamic moneyAccountRepo;
  dynamic productRepo;
  dynamic supplierRepo;
  dynamic purchaseRepo;
  dynamic invoiceRepo;
  dynamic deliveryNoteRepo;

  try {
    expenseRepo = ref.watch(expenseRepositoryProvider);
  } catch (_) {}
  try {
    customerRepo = ref.watch(customerRepositoryProvider);
  } catch (_) {}
  try {
    inventoryRepo = ref.watch(inventoryRepositoryProvider);
  } catch (_) {}
  try {
    moneyAccountRepo = ref.watch(moneyAccountRepositoryProvider);
  } catch (_) {}
  try {
    productRepo = ref.watch(productRepositoryProvider);
  } catch (_) {}
  try {
    supplierRepo = ref.watch(supplierRepositoryProvider);
  } catch (_) {}
  try {
    purchaseRepo = ref.watch(purchaseRepositoryProvider);
  } catch (_) {}
  try {
    invoiceRepo = ref.watch(invoiceRepositoryProvider);
  } catch (_) {}
  try {
    deliveryNoteRepo = ref.watch(deliveryNoteRepositoryProvider);
  } catch (_) {}

  final engine = SyncEngine(
    salesService: ref.watch(localSalesServiceProvider),
    repository: ref.watch(saleRepositoryProvider),
    expenseRepository: expenseRepo,
    customerRepository: customerRepo,
    inventoryRepository: inventoryRepo,
    moneyAccountRepository: moneyAccountRepo,
    productRepository: productRepo,
    supplierRepository: supplierRepo,
    purchaseRepository: purchaseRepo,
    invoiceRepository: invoiceRepo,
    deliveryNoteRepository: deliveryNoteRepo,
  );
  final monitor = ref.watch(connectivityMonitorProvider.notifier);
  Timer? timer;

  Future<void> drainIfOnline() async {
    try {
      if (ref.read(connectivityMonitorProvider) == ConnectionQuality.online ||
          ref.read(connectivityMonitorProvider) == ConnectionQuality.unknown) {
        await engine.drain();
      }
    } catch (_) {}
  }

  engine.onDrained = (outcome) async {
    try {
      await ref.read(posCatalogControllerProvider.notifier).refresh();
    } catch (_) {
      // Offline again — the next cycle retries.
    }
    if (outcome.synced > 0) {
      ref.read(syncStatusProvider.notifier).noteSyncCompleted();
      try {
        await ref.read(dashboardControllerProvider.notifier).refresh();
      } catch (_) {}
      try {
        ref.read(salesHistoryControllerProvider.notifier).load();
      } catch (_) {}
      try {
        ref.read(expensesControllerProvider.notifier).load();
      } catch (_) {}
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
    this.isSyncing = false,
    this.pendingSales = const [],
    this.conflictSales = const [],
  });

  final int pendingCount;
  final int conflictCount;
  final DateTime? lastSyncAt;
  final bool isSyncing;
  final List<LocalSale> pendingSales;
  final List<LocalSale> conflictSales;

  SyncStatusState copyWith({
    int? pendingCount,
    int? conflictCount,
    DateTime? lastSyncAt,
    bool? isSyncing,
    List<LocalSale>? pendingSales,
    List<LocalSale>? conflictSales,
  }) =>
      SyncStatusState(
        pendingCount: pendingCount ?? this.pendingCount,
        conflictCount: conflictCount ?? this.conflictCount,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        isSyncing: isSyncing ?? this.isSyncing,
        pendingSales: pendingSales ?? this.pendingSales,
        conflictSales: conflictSales ?? this.conflictSales,
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
    try {
      final pending = await _service.pendingSaleCount();
      final conflicts = await _service.conflictedSaleCount();
      final pendingList = await _service.pendingSales();
      final conflictList = await _service.conflictedSales();
      state = state.copyWith(
        pendingCount: pending,
        conflictCount: conflicts,
        pendingSales: pendingList,
        conflictSales: conflictList,
      );
    } catch (_) {}
  }

  void noteSyncCompleted() {
    state = state.copyWith(lastSyncAt: DateTime.now().toUtc());
  }

  Future<void> triggerSync() async {
    if (state.isSyncing) return;
    state = state.copyWith(isSyncing: true);
    try {
      final engine = ref.read(syncEngineProvider);
      await engine.drain(forceRetryAll: true);
    } finally {
      state = state.copyWith(isSyncing: false);
      await refresh();
    }
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
    try {
      final response =
          await ref.read(apiClientProvider).get<Map<String, dynamic>>(
        ApiRoutes.v1('/branches'),
        query: {'page': 1, 'pageSize': 1},
      );
      final items = response.data?['items'] as List? ?? [];
      if (items.isNotEmpty) {
        final branchId = (items.first as Map<String, dynamic>)['id'] as String?;
        final branchName =
            (items.first as Map<String, dynamic>)['name'] as String?;

        // Cache for offline use
        if (branchId != null) {
          await branchCache.store(branchId: branchId, branchName: branchName);
        }

        return branchId;
      }
    } catch (_) {
      // Offline fallback
    }

    // Secondary fallback: if warehouse cache exists, use its warehouse id
    try {
      final db = ref.read(localDatabaseProvider);
      final tenantId = auth.session.user.tenantId;
      final cachedWarehouse = await (db.select(db.cachedWarehouses)
            ..where((t) => t.tenantId.equals(tenantId))
            ..limit(1))
          .getSingleOrNull();
      if (cachedWarehouse != null) {
        await branchCache.store(
          branchId: cachedWarehouse.warehouseId,
          branchName: cachedWarehouse.name,
        );
        return cachedWarehouse.warehouseId;
      }
    } catch (_) {}

    // Tertiary fallback: use tenant ID as provisional branch ID
    return auth.session.user.tenantId;
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

final offlineShiftRegisterServiceProvider =
    Provider<OfflineShiftRegisterService>((ref) {
  final service = ref.watch(localSalesServiceProvider);
  final identity = ref.watch(deviceIdentityProvider);
  final db = ref.watch(localDatabaseProvider);
  final cache = ref.watch(offlineCacheDaoProvider);
  final expense = ref.watch(offlineExpenseServiceProvider);
  final debt = ref.watch(offlineCustomerDebtServiceProvider);

  return OfflineShiftRegisterService(
    salesDao: service.sales,
    expenseService: expense,
    debtService: debt,
    queue: SyncQueueDao(db),
    cache: cache,
    tenantIdOf: () async => ref.read(sessionContextProvider).$1,
    branchIdOf: () => ref.read(posBranchIdProvider)(),
    deviceIdOf: () => identity.get(),
    userIdOf: () async => ref.read(sessionContextProvider).$2,
  );
});

final offlineParkedCartServiceProvider =
    Provider<OfflineParkedCartService>((ref) {
  final cache = ref.watch(offlineCacheDaoProvider);
  return OfflineParkedCartService(cache: cache);
});

class ParkedCartsNotifier extends Notifier<List<ParkedCart>> {
  @override
  List<ParkedCart> build() {
    Future.microtask(() => load());
    return const [];
  }

  OfflineParkedCartService get _service =>
      ref.read(offlineParkedCartServiceProvider);

  Future<void> load() async {
    final list = await _service.listParkedCarts();
    state = list;
  }

  Future<ParkedCart> park(
    List<CartLine> lines, {
    String? customerName,
    String? customerId,
    String? label,
  }) async {
    final cart = await _service.parkCart(
      lines: lines,
      customerName: customerName,
      customerId: customerId,
      label: label,
    );
    await load();
    return cart;
  }

  Future<ParkedCart?> restore(String cartId) async {
    final restored = await _service.restoreCart(cartId);
    await load();
    return restored;
  }

  Future<void> discard(String cartId) async {
    await _service.discardCart(cartId);
    await load();
  }
}

final parkedCartsProvider =
    NotifierProvider<ParkedCartsNotifier, List<ParkedCart>>(
  ParkedCartsNotifier.new,
);
