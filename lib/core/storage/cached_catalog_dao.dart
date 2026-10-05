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

  Future<DateTime?> lastRefresh() async {
    final row = await (_db.select(_db.metaEntries)
          ..where((t) => t.key.equals('last_stock_refresh')))
        .getSingleOrNull();
    return row == null ? null : DateTime.tryParse(row.value)?.toUtc();
  }
}
