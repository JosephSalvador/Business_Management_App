import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local/cached_catalog_dao.dart';
import '../../../core/local/local_database.dart'
    show CachedProductsCompanion, CachedStockCompanion;
import '../../../core/network/app_exception.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart';/// One sellable row on the POS grid, served from the local cache with a
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
class PosCatalogController extends StateNotifier<PosCatalogState> {
  PosCatalogController({
    required CachedCatalogDao dao,
    required ProductRepository repository,
    required Future<String?> Function() tenantIdOf,
  })  : _dao = dao,
        _repository = repository,
        _tenantIdOf = tenantIdOf,
        super(const PosCatalogState());

  static const _pageSize = 200;

  final CachedCatalogDao _dao;
  final ProductRepository _repository;
  final Future<String?> Function() _tenantIdOf;

  /// Loads the visible list: cached rows immediately, then a silent online
  /// refresh that swaps in fresher data if it succeeds.
  Future<void> load({String? search}) async {
    state = state.copyWith(
      loading: true,
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
    }
    state = state.copyWith(loading: false);
  }

  /// Pulls the minimum selling data from the API and replaces the cache.
  Future<void> refresh() async {
    final tenantId = await _tenantIdOf();
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

    final stock = <String, double>{};
    for (final balance in await _repository.balances()) {
      stock[balance.productId] =
          (stock[balance.productId] ?? 0) + balance.quantity;
    }

    final now = DateTime.now().toUtc();
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
                p.productType == LocalProductCodes.typeGoods &&
                (prices[p.id] ?? 0) > 0,
            productType: p.productType,
            retailPrice: prices[p.id] ?? 0,
            currency: currency,
            fetchedAt: now,
          ),
      ],
      stock: [
        for (final entry in stock.entries)
          CachedStockCompanion.insert(
            tenantId: tenantId,
            productId: entry.key,
            warehouseId: '*',
            quantity: entry.value,
            fetchedAt: now,
          ),
      ],
    );
    await _emitFromCache(staleOverride: false);
  }

  Future<void> _emitFromCache({bool? staleOverride}) async {
    final tenantId = await _tenantIdOf();
    if (tenantId == null) {
      state =
          state.copyWith(items: const [], stale: true, loading: false);
      return;
    }
    final query = state.search.trim();
    final found = query.isEmpty
        ? await _dao.list(tenantId)
        : await _dao.search(tenantId, query);
    final items = <PosProduct>[];
    for (final row in found) {
      items.add(PosProduct(
        productId: row.productId,
        name: row.name,
        sku: row.sku,
        price: row.retailPrice,
        projectedQuantity: await _dao.projectedQuantity(tenantId, row.productId),
      ));
    }
    state = state.copyWith(
      items: items,
      loading: false,
      stale: staleOverride ?? state.stale,
    );
  }
}
