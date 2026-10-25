import 'package:drift/drift.dart';

import 'local_database.dart';
import 'tables.dart';

export 'tables.dart' show LocalSaleStatus, LocalProductCodes;

/// Lightweight read model for the stock hub's cache-first read: one row per
/// product per warehouse with the product name attached.
class StockRowCache {
  const StockRowCache({
    required this.tenantId,
    required this.warehouseId,
    required this.productId,
    required this.productName,
    required this.quantity,
  });

  final String tenantId;
  final String warehouseId;
  final String productId;
  final String productName;
  final double quantity;
}

/// Read/write access to the offline catalog cache (M5.3). The cache holds
/// only what selling needs; it is replaced wholesale on refresh and never
/// mutated by sales — projected availability is computed from pending local
/// sales on read.
class CachedCatalogDao {
  CachedCatalogDao(this._db);

  final LocalDatabase _db;

  /// Replaces the whole tenant cache in one transaction (full refetch
  /// strategy — the backend has no delta cursor yet).
  Future<void> replaceCatalog({
    required String tenantId,
    required List<CachedProductsCompanion> products,
    required List<CachedStockCompanion> stock,
    List<CachedWarehousesCompanion> warehouses = const [],
  }) {
    return _db.transaction(() async {
      await (_db.delete(_db.cachedProducts)
            ..where((t) => t.tenantId.equals(tenantId)))
          .go();
      await (_db.delete(_db.cachedStock)
            ..where((t) => t.tenantId.equals(tenantId)))
          .go();
      await (_db.delete(_db.cachedWarehouses)
            ..where((t) => t.tenantId.equals(tenantId)))
          .go();
      if (products.isNotEmpty) {
        await _db.batch((b) => b.insertAll(_db.cachedProducts, products));
      }
      if (stock.isNotEmpty) {
        await _db.batch((b) => b.insertAll(_db.cachedStock, stock));
      }
      if (warehouses.isNotEmpty) {
        await _db.batch((b) => b.insertAll(_db.cachedWarehouses, warehouses));
      }
      await _db
          .into(_db.metaEntries)
          .insertOnConflictUpdate(MetaEntriesCompanion(
            key: const Value('last_catalog_refresh'),
            value: Value(DateTime.now().toUtc().toIso8601String()),
            updatedAt: Value(DateTime.now().toUtc()),
          ));
    });
  }

  /// Replaces product cache only without deleting cached stock balances.
  Future<void> replaceProductsOnly({
    required String tenantId,
    required List<CachedProductsCompanion> products,
  }) {
    return _db.transaction(() async {
      await (_db.delete(_db.cachedProducts)
            ..where((t) => t.tenantId.equals(tenantId)))
          .go();
      if (products.isNotEmpty) {
        await _db.batch((b) => b.insertAll(_db.cachedProducts, products));
      }
      await _db
          .into(_db.metaEntries)
          .insertOnConflictUpdate(MetaEntriesCompanion(
            key: const Value('last_catalog_refresh'),
            value: Value(DateTime.now().toUtc().toIso8601String()),
            updatedAt: Value(DateTime.now().toUtc()),
          ));
    });
  }

  /// Offline POS search: name/sku/barcode substring match over active,
  /// sellable goods, newest fetch first. Never touches the network.
  Future<List<CachedProduct>> search(String tenantId, String query,
      {int limit = 50}) {
    final like = '%${query.trim()}%';
    return (_db.select(_db.cachedProducts)
          ..where((t) =>
              t.tenantId.equals(tenantId) &
              t.status.equals(LocalProductCodes.statusActive) &
              t.sellable.equals(true) &
              t.productType.equals(LocalProductCodes.typeGoods) &
              (t.name.like(like) | t.sku.like(like) | t.barcode.like(like)))
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
  }

  Future<List<CachedProduct>> list(String tenantId, {int limit = 200}) {
    return (_db.select(_db.cachedProducts)
          ..where((t) =>
              t.tenantId.equals(tenantId) &
              t.status.equals(LocalProductCodes.statusActive) &
              t.sellable.equals(true))
          ..orderBy([(t) => OrderingTerm(expression: t.name)])
          ..limit(limit))
        .get();
  }

  Future<List<CachedProduct>> all({int limit = 500}) {
    return (_db.select(_db.cachedProducts)
          ..orderBy([(t) => OrderingTerm(expression: t.name)])
          ..limit(limit))
        .get();
  }

  Future<CachedProduct?> byId(String tenantId, String productId) {
    return (_db.select(_db.cachedProducts)
          ..where((t) =>
              t.tenantId.equals(tenantId) & t.productId.equals(productId)))
        .getSingleOrNull();
  }

  /// Looks a row up by its reserved SKU (e.g. the hidden quick-sale product)
  /// regardless of sellability — used to recover a system product id offline.
  Future<CachedProduct?> bySku(String tenantId, String sku) {
    return (_db.select(_db.cachedProducts)
          ..where((t) => t.tenantId.equals(tenantId) & t.sku.equals(sku)))
        .getSingleOrNull();
  }

  /// Last-known server balance minus quantities held by still-pending offline
  /// sales. This projection is what the POS sells against (M5.5); the cache
  /// itself is never modified by sales.
  Future<double> projectedQuantity(
    String tenantId,
    String productId,
  ) async {
    final known = await (_db.selectOnly(_db.cachedStock)
          ..addColumns([_db.cachedStock.quantity])
          ..where(_db.cachedStock.tenantId.equals(tenantId) &
              _db.cachedStock.productId.equals(productId)))
        .map((row) => row.read(_db.cachedStock.quantity) ?? 0)
        .get();
    final balance = known.isEmpty ? 0.0 : known.reduce((a, b) => a + b);

    final pendingQty = await (_db.selectOnly(_db.localSaleLines).join([
      innerJoin(
          _db.localSales,
          _db.localSales.clientSaleId
              .equalsExp(_db.localSaleLines.clientSaleId)),
    ])
          ..addColumns([_db.localSaleLines.quantity])
          ..where(_db.localSales.tenantId.equals(tenantId) &
              _db.localSales.status.equals(LocalSaleStatus.pending) &
              _db.localSaleLines.productId.equals(productId)))
        .map((row) => row.read(_db.localSaleLines.quantity) ?? 0)
        .get();

    return balance - pendingQty.fold(0.0, (a, b) => a + b);
  }

  /// Batch computes projected available quantities for all cached products
  /// in the given tenant in 2 fast queries instead of 2*N individual queries.
  Future<Map<String, double>> projectedQuantities(String tenantId) async {
    final balances = <String, double>{};
    try {
      final stockRows = await (_db.selectOnly(_db.cachedStock)
            ..addColumns([_db.cachedStock.productId, _db.cachedStock.quantity])
            ..where(_db.cachedStock.tenantId.equals(tenantId)))
          .get()
          .timeout(const Duration(milliseconds: 2000));
      for (final row in stockRows) {
        final pid = row.read(_db.cachedStock.productId);
        final qty = row.read(_db.cachedStock.quantity) ?? 0.0;
        if (pid != null) {
          balances[pid] = (balances[pid] ?? 0.0) + qty;
        }
      }

      final pendingRows = await (_db.selectOnly(_db.localSaleLines).join([
        innerJoin(
            _db.localSales,
            _db.localSales.clientSaleId
                .equalsExp(_db.localSaleLines.clientSaleId)),
      ])
            ..addColumns(
                [_db.localSaleLines.productId, _db.localSaleLines.quantity])
            ..where(_db.localSales.tenantId.equals(tenantId) &
                _db.localSales.status.equals(LocalSaleStatus.pending)))
          .get()
          .timeout(const Duration(milliseconds: 2000));
      for (final row in pendingRows) {
        final pid = row.read(_db.localSaleLines.productId);
        final qty = row.read(_db.localSaleLines.quantity) ?? 0.0;
        if (pid != null) {
          balances[pid] = (balances[pid] ?? 0.0) - qty;
        }
      }
    } catch (_) {}
    return balances;
  }

  /// Per-product, per-warehouse balances with product names attached (the
  /// stock hub's cache-first read). Instant and offline OK; the enriched
  /// names ride along in the projection so the hub never does N+1 lookups.
  Future<List<StockRowCache>> listStockRows(String tenantId) {
    return (_db.select(_db.cachedStock).join([
      innerJoin(
        _db.cachedProducts,
        _db.cachedProducts.tenantId.equalsExp(_db.cachedStock.tenantId) &
            _db.cachedProducts.productId.equalsExp(_db.cachedStock.productId),
      ),
    ])
          ..where(_db.cachedStock.tenantId.equals(tenantId)))
        .map((row) => StockRowCache(
              tenantId: row.readTable(_db.cachedStock).tenantId,
              warehouseId: row.readTable(_db.cachedStock).warehouseId,
              productId: row.readTable(_db.cachedStock).productId,
              productName: row.readTable(_db.cachedProducts).name,
              quantity: row.readTable(_db.cachedStock).quantity,
            ))
        .get();
  }

  /// Cached warehouse catalog (multi-warehouse hubs + POS). The read model
  /// is replaced wholesale on refresh, exactly like products/stock.
  Future<List<CachedWarehouse>> warehouses(String tenantId) {
    return (_db.select(_db.cachedWarehouses)
          ..where((t) => t.tenantId.equals(tenantId))
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
  }

  /// Replaces stock + warehouse rows only (hub refresh), leaving the product
  /// cache untouched — cheaper than a full [replaceCatalog] and the correct
  /// operation when balances changed but the catalog did not.
  Future<void> replaceStockBalances({
    required String tenantId,
    List<CachedStockCompanion> stock = const [],
    List<CachedWarehousesCompanion> warehouses = const [],
  }) {
    return _db.transaction(() async {
      await (_db.delete(_db.cachedStock)
            ..where((t) => t.tenantId.equals(tenantId)))
          .go();
      await (_db.delete(_db.cachedWarehouses)
            ..where((t) => t.tenantId.equals(tenantId)))
          .go();
      if (stock.isNotEmpty) {
        await _db.batch((b) => b.insertAll(_db.cachedStock, stock));
      }
      if (warehouses.isNotEmpty) {
        await _db.batch((b) => b.insertAll(_db.cachedWarehouses, warehouses));
      }
      await _db
          .into(_db.metaEntries)
          .insertOnConflictUpdate(MetaEntriesCompanion(
            key: const Value('last_stock_refresh'),
            value: Value(DateTime.now().toUtc().toIso8601String()),
            updatedAt: Value(DateTime.now().toUtc()),
          ));
    });
  }

  Future<void> incrementCachedStock({
    required String tenantId,
    required String productId,
    required String warehouseId,
    required double quantity,
  }) async {
    final existing = await (_db.select(_db.cachedStock)
          ..where((t) =>
              t.tenantId.equals(tenantId) &
              t.productId.equals(productId) &
              t.warehouseId.equals(warehouseId)))
        .getSingleOrNull();

    final now = DateTime.now().toUtc();
    if (existing != null) {
      await (_db.update(_db.cachedStock)
            ..where((t) =>
                t.tenantId.equals(tenantId) &
                t.productId.equals(productId) &
                t.warehouseId.equals(warehouseId)))
          .write(CachedStockCompanion(
        quantity: Value(existing.quantity + quantity),
        fetchedAt: Value(now),
      ));
    } else {
      await _db.into(_db.cachedStock).insert(CachedStockCompanion.insert(
            tenantId: tenantId,
            productId: productId,
            warehouseId: warehouseId,
            quantity: quantity,
            fetchedAt: now,
          ));
    }
  }

  Future<void> upsertProduct(CachedProductsCompanion product) async {
    await _db.into(_db.cachedProducts).insertOnConflictUpdate(product);
  }

  Future<void> updateRetailPrice({
    required String tenantId,
    required String productId,
    required double price,
  }) async {
    await (_db.update(_db.cachedProducts)
          ..where((t) =>
              t.tenantId.equals(tenantId) & t.productId.equals(productId)))
        .write(CachedProductsCompanion(
      retailPrice: Value(price),
      fetchedAt: Value(DateTime.now().toUtc()),
    ));
  }

  Future<void> remapProductId({
    required String tenantId,
    required String localProductId,
    required String serverProductId,
  }) async {
    final products = await byId(tenantId, localProductId);
    if (products != null) {
      await upsertProduct(CachedProductsCompanion.insert(
        tenantId: tenantId,
        productId: serverProductId,
        name: products.name,
        sku: Value(products.sku),
        barcode: Value(products.barcode),
        retailPrice: products.retailPrice,
        currency: products.currency,
        status: products.status,
        sellable: products.sellable,
        productType: products.productType,
        fetchedAt: products.fetchedAt,
      ));
    }
    final stock = await (_db.select(_db.cachedStock)
          ..where((t) =>
              t.tenantId.equals(tenantId) & t.productId.equals(localProductId)))
        .get();
    for (final row in stock) {
      await incrementCachedStock(
        tenantId: tenantId,
        productId: serverProductId,
        warehouseId: row.warehouseId,
        quantity: row.quantity,
      );
    }
    await (_db.delete(_db.cachedStock)
          ..where((t) =>
              t.tenantId.equals(tenantId) & t.productId.equals(localProductId)))
        .go();
    await (_db.delete(_db.cachedProducts)
          ..where((t) =>
              t.tenantId.equals(tenantId) & t.productId.equals(localProductId)))
        .go();
  }

  /// When the product catalog was last fully replaced via [replaceCatalog].
  /// (`replaceStockBalances` stamps its own `last_stock_refresh` key.)
  Future<DateTime?> lastRefresh() async {
    final row = await (_db.select(_db.metaEntries)
          ..where((t) => t.key.equals('last_catalog_refresh')))
        .getSingleOrNull();
    return row == null ? null : DateTime.tryParse(row.value)?.toUtc();
  }
}
