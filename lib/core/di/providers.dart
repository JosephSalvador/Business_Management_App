import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../local/db_key_store.dart';
import '../local/device_identity.dart';
import '../local/local_database.dart';
import '../local/session_journal.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/secure_token_store.dart';
import '../../features/products/application/catalog_controller.dart';
import '../../features/products/application/products_controller.dart';
import '../../features/products/application/stock_controller.dart';
import '../../features/products/data/product_repository.dart';
import '../../features/sales/application/cart_controller.dart';
import '../../features/sales/application/checkout_controller.dart';
import '../../features/sales/application/local_sales_service.dart';
import '../../features/sales/application/offline_sale_recorder.dart';
import '../../features/sales/application/pos_catalog_controller.dart';
import '../../features/sales/application/sales_history_controller.dart';
import '../../features/sales/application/sync_engine.dart';
import '../../features/sales/data/sale_repository.dart';
import '../../features/workspace/application/workspace_controller.dart';
import '../../features/workspace/data/workspace_repository.dart';
import '../network/api_client.dart';
import '../network/api_routes.dart';
import '../network/connectivity_monitor.dart';

/// Resolved once in `main()` and injected via [ProviderScope] overrides so
/// tests can supply their own configuration.
final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.instance);

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

/// Opened once in `main()` (SQLCipher key from secure storage) and injected
/// via overrides; tests inject in-memory databases.
final localDatabaseProvider = Provider<LocalDatabase>(
  (ref) => throw UnimplementedError(
      'localDatabaseProvider must be overridden at bootstrap'),
);

final dbKeyStoreProvider = Provider<DbKeyStore>((ref) => DbKeyStore());

final deviceIdentityProvider = Provider<DeviceIdentity>((ref) => DeviceIdentity());

/// Application facade over the local sale + queue storage.
final localSalesServiceProvider = Provider<LocalSalesService>(
  (ref) => LocalSalesService(database: ref.watch(localDatabaseProvider)),
);

final sessionJournalProvider = Provider<SessionJournal>(
  (ref) => SessionJournal(ref.watch(localDatabaseProvider)),
);

/// Repository owning authentication + the whole-app HTTP client.
/// The refresh callback closes over the repository being constructed
/// (late assignment breaks the construction cycle).
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  final tokenStore = ref.watch(tokenStoreProvider);
  final journal = ref.watch(sessionJournalProvider);

  late final AuthRepository repository;
  final client = ApiClient(
    config: config,
    tokenStore: tokenStore,
    refresher: (refreshToken) => repository.refresh(refreshToken),
  );
  repository = AuthRepository(
    apiClient: client,
    tokenStore: tokenStore,
    onSessionEstablished: () => journal.markAuthenticated(),
  );
  return repository;
});

final apiClientProvider = Provider<ApiClient>(
  (ref) => ref.watch(authRepositoryProvider).apiClient,
);

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref.watch(authRepositoryProvider))..bootstrap(),
);

final workspaceRepositoryProvider = Provider<WorkspaceRepository>(
  (ref) => WorkspaceRepository(apiClient: ref.watch(apiClientProvider)),
);

final workspaceControllerProvider =
    StateNotifierProvider<WorkspaceController, WorkspaceState>(
  (ref) => WorkspaceController(ref.watch(workspaceRepositoryProvider)),
);

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepository(apiClient: ref.watch(apiClientProvider)),
);

final catalogControllerProvider =
    StateNotifierProvider<CatalogController, CatalogState>(
  (ref) => CatalogController(ref.watch(productRepositoryProvider)),
);

final productsControllerProvider =
    StateNotifierProvider<ProductsController, ProductsState>(
  (ref) => ProductsController(ref.watch(productRepositoryProvider)),
);

final stockControllerProvider =
    StateNotifierProvider<StockController, StockState>(
  (ref) => StockController(ref.watch(productRepositoryProvider)),
);

final saleRepositoryProvider = Provider<SaleRepository>(
  (ref) => SaleRepository(apiClient: ref.watch(apiClientProvider)),
);

/// Session context for offline records: tenant and user come ONLY from the
/// authenticated session — never from UI input (M5.10).
final _sessionContextProvider = Provider<(String?, String?)>((ref) {
  final state = ref.watch(authControllerProvider);
  if (state is AuthAuthenticated) {
    return (state.session.user.tenantId, state.session.user.id);
  }
  return (null, null);
});

/// Cache-first POS catalog (M5.3).
final posCatalogControllerProvider =
    StateNotifierProvider<PosCatalogController, PosCatalogState>((ref) {
  final service = ref.watch(localSalesServiceProvider);
  return PosCatalogController(
    dao: service.catalog,
    repository: ref.watch(productRepositoryProvider),
    tenantIdOf: () async => ref.read(_sessionContextProvider).$1,
  );
});

final connectivityMonitorProvider =
    StateNotifierProvider<ConnectivityMonitor, ConnectionQuality>((ref) {
  return ConnectivityMonitor(apiClient: ref.watch(apiClientProvider));
});

/// Indirection so UI reads a plain value that tests can override without
/// constructing real connectivity plumbing.
final connectionQualityProvider = Provider<ConnectionQuality>(
  (ref) => ref.watch(connectivityMonitorProvider),
);

/// The single sync worker (M5.8): drains on reconnect, on a periodic tick
/// while online, and after each new pending sale.
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
    // Server balances changed; refresh cache quietly.
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

/// Simple counters powering the sync status sheet (M5.16).
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
    StateNotifierProvider<SyncStatusController, SyncStatusState>((ref) {
  return SyncStatusController(ref.watch(localSalesServiceProvider));
});

class SyncStatusController extends StateNotifier<SyncStatusState> {
  SyncStatusController(this._service) : super(const SyncStatusState()) {
    refresh();
  }

  final LocalSalesService _service;

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

final cartControllerProvider =
    StateNotifierProvider<CartController, CartState>(
  (ref) => CartController(),
);

/// Lazily resolves the tenant branch a sale is recorded against. The
/// workspace DTO carries no branch id, so the POS asks `/api/v1/branches`
/// and takes the first one (registration always seeds exactly one branch).
///
/// This is a FUNCTION provider on purpose: constructing it performs NO
/// network call. The GET fires only when a checkout actually needs the
/// branch — and never when there is no authenticated session.
final posBranchIdProvider = Provider<Future<String?> Function()>((ref) {
  return () async {
    final auth = ref.read(authControllerProvider);
    if (auth is! AuthAuthenticated) {
      return null;
    }
    final response =
        await ref.watch(apiClientProvider).get<Map<String, dynamic>>(
              ApiRoutes.v1('/branches'),
              query: {'page': 1, 'pageSize': 1},
            );
    final items = response.data?['items'] as List? ?? [];
    if (items.isEmpty) {
      return null;
    }
    return (items.first as Map<String, dynamic>)['id'] as String?;
  };
});

final checkoutControllerProvider =
    StateNotifierProvider<CheckoutController, CheckoutState>(
  (ref) {
    final branchIds = ref.read(posBranchIdProvider);
    final journal = ref.watch(sessionJournalProvider);
    final identity = ref.watch(deviceIdentityProvider);
    final service = ref.watch(localSalesServiceProvider);
    return CheckoutController(
      ref.watch(saleRepositoryProvider),
      branchIds,
      offlineRecorder: OfflineSaleRecorder(
        salesDao: service.sales,
        catalogDao: service.catalog,
        tenantIdOf: () async => ref.read(_sessionContextProvider).$1,
        deviceIdOf: () => identity.get(),
        userIdOf: () async => ref.read(_sessionContextProvider).$2,
        branchIdOf: () => branchIds(),
      ),
      offlineWindowOpen: () => journal.offlineWindowOpen(),
      uuid: const Uuid(),
    );
  },
);

final salesHistoryControllerProvider =
    StateNotifierProvider<SalesHistoryController, SalesHistoryState>(
  (ref) =>
      SalesHistoryController(ref.watch(saleRepositoryProvider)),
);

/// Wires the workspace journey to the auth lifecycle: loading starts on
/// login and state resets on logout/session expiry. Watched by the router so
/// it is alive for the whole session.
final workspaceJourneyBindingProvider = Provider<void>((ref) {
  ref.listen<AuthState>(authControllerProvider, (_, next) {
    final controller = ref.read(workspaceControllerProvider.notifier);
    if (next is AuthAuthenticated) {
      controller.load();
    } else {
      controller.reset();
      ref.read(productsControllerProvider.notifier).reset();
      ref.read(stockControllerProvider.notifier).reset();
      ref.read(catalogControllerProvider.notifier).reset();
      ref.read(cartControllerProvider.notifier).clear();
      ref.read(checkoutControllerProvider.notifier).reset();
      ref.read(salesHistoryControllerProvider.notifier).reset();
    }
  });
});
