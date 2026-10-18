import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/storage/cached_catalog_dao.dart';
import '../../../core/storage/local_database.dart'
    show
        CachedProductsCompanion,
        CachedStockCompanion,
        CachedWarehousesCompanion;
import '../../../core/network/app_exception.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/catalog.dart' show StockBalance;
import '../../products/domain/product.dart';

/// One sellable row on the POS grid, served from the local cache with a
/// stock projection that accounts for still-unsynced offline sales.
class PosProduct {
  const PosProduct({
    required this.productId,
    required this.name,
    required this.sku,
    required this.price,
    required this.projectedQuantity,
  });

  final String productId;
  final String name;
  final String? sku;
  final double price;

  /// Last-known server balance minus pending offline deductions. The POS
  /// blocks selling beyond zero of this number (M5.5).
  final double projectedQuantity;

  bool get outOfStock => projectedQuantity <= 0;
}

class PosCatalogState {
  const PosCatalogState({
    this.loading = false,
    this.search = '',
    this.items = const [],
    this.stale = false,
    this.hasLoadedOnce = false,
  });

  final bool loading;
  final String search;
  final List<PosProduct> items;

  /// True when the last online refresh failed — the grid is being served
  /// from cache and the UI should show the offline banner.
  final bool stale;

  /// Guards double-loading on every POS page rebuild.
  final bool hasLoadedOnce;

  PosCatalogState copyWith({
    bool? loading,
    String? search,
    List<PosProduct>? items,
    bool? stale,
    bool? hasLoadedOnce,
  }) =>
      PosCatalogState(
        loading: loading ?? this.loading,
        search: search ?? this.search,
        items: items ?? this.items,
        stale: stale ?? this.stale,
        hasLoadedOnce: hasLoadedOnce ?? this.hasLoadedOnce,
      );
}

/// Cache-first catalog for the POS (M5.3). Reads NEVER hit the network:
/// search works fully offline. A refresh pulls products, default-list retail
/// prices and balances into the encrypted cache when connectivity allows.
class PosCatalogController extends Notifier<PosCatalogState> {
  static const _pageSize = 200;

  @override
  PosCatalogState build() => const PosCatalogState();

  CachedCatalogDao get _dao => ref.read(localSalesServiceProvider).catalog;
  ProductRepository get _repository => ref.read(productRepositoryProvider);

  /// Loads the visible list: cached rows immediately, then a silent online
  /// refresh that swaps in fresher data if it succeeds.
  Future<void> load({String? search}) async {
    state = state.copyWith(
      loading: state.items.isEmpty,
      search: search ?? state.search,
      hasLoadedOnce: true,
    );
    await _emitFromCache();
    try {
      await refresh();
    } on NetworkException catch (_) {
      state = state.copyWith(loading: false, stale: true);
      return;
    } on TimeoutException catch (_) {
      state = state.copyWith(loading: false, stale: true);
      return;
    } on AppException {
      // Server reachable but unhappy (5xx/auth) — keep serving cache and
      // let the connectivity layer escalate session problems.
      state = state.copyWith(loading: false, stale: true);
      return;
    } catch (_) {
      state = state.copyWith(loading: false, stale: true);
      return;
    } finally {
      if (state.loading) {
        state = state.copyWith(loading: false);
      }
    }
    state = state.copyWith(loading: false);
  }

  /// Pulls the minimum selling data from the API and replaces the cache.
  Future<void> refresh() async {
    final tenantId = ref.read(sessionContextProvider).$1;
    if (tenantId == null) {
      throw ValidationException('Chagua biashara kwanza.');
    }

    var page = 1;
    final products = <Product>[];
    while (true) {
      final result = await _repository.list(page: page, pageSize: _pageSize);
      products.addAll(result.items);
      if (result.items.length < _pageSize || page >= 20) {
        break;
      }
      page++;
    }

    Map<String, double> prices = {};
    var currency = 'TZS';
    try {
      final priceList = await _repository.defaultPriceList();
      if (priceList != null) {
        currency = priceList.currency;
        prices = {
          for (final row in await _repository.prices(priceList.id))
            if (row.priceType == 0) row.productId: row.price,
        };
      }
    } on AppException {
      // Prices are supplementary for the grid; sale-time pricing stays
      // server-side either way.
    }

    List<StockBalance> balances = const [];
    try {
      balances = await _repository.balances();
    } catch (_) {}

    final now = DateTime.now().toUtc();
    List<CachedWarehousesCompanion> warehouseRows = const [];
    try {
      warehouseRows = [
        for (final w in await _repository.warehouses())
          CachedWarehousesCompanion.insert(
            tenantId: tenantId,
            warehouseId: w.id,
            name: w.name,
            code: w.code,
            fetchedAt: now,
          ),
      ];
    } on AppException {
      // Warehouse names are a display nicety for the hub; a missed fetch
      // degrades to the stock-only cache.
    }
    await _dao.replaceCatalog(
      tenantId: tenantId,
      products: [
        for (final p in products)
          CachedProductsCompanion.insert(
            tenantId: tenantId,
            productId: p.id,
            name: p.name,
            sku: Value(p.sku),
            barcode: Value(p.barcode),
            status: p.status,
            sellable: p.status == LocalProductCodes.statusActive &&
                p.productType == LocalProductCodes.typeGoods,
            productType: p.productType,
            retailPrice: prices[p.id] ?? 0,
            currency: currency,
            fetchedAt: now,
          ),
      ],
      stock: [
        for (final balance in balances)
          CachedStockCompanion.insert(
            tenantId: tenantId,
            productId: balance.productId,
            warehouseId: balance.warehouseId,
            quantity: balance.quantity,
            fetchedAt: now,
          ),
      ],
      warehouses: warehouseRows,
    );
    await _emitFromCache(staleOverride: false);
  }

  Future<void> _emitFromCache({bool? staleOverride}) async {
    final tenantId = ref.read(sessionContextProvider).$1;
    if (tenantId == null) {
      state = state.copyWith(items: const [], stale: true, loading: false);
      return;
    }
    try {
      final query = state.search.trim();
      final found = await (query.isEmpty
              ? _dao.list(tenantId)
              : _dao.search(tenantId, query))
          .timeout(const Duration(milliseconds: 2500));
      final quantities = await _dao
          .projectedQuantities(tenantId)
          .timeout(const Duration(milliseconds: 2000));
      final items = <PosProduct>[
        for (final row in found)
          PosProduct(
            productId: row.productId,
            name: row.name,
            sku: row.sku,
            price: row.retailPrice,
            projectedQuantity: quantities[row.productId] ?? 0.0,
          ),
      ];
      state = state.copyWith(
        items: items,
        loading: false,
        stale: staleOverride ?? state.stale,
      );
    } catch (_) {
      state = state.copyWith(
        loading: false,
        stale: staleOverride ?? state.stale,
      );
    }
  }
}
