import 'package:drift/drift.dart';

import 'local_database.dart';
import 'tables.dart';

export 'tables.dart' show LocalSaleStatus, LocalProductCodes;

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
  }) {
    return _db.transaction(() async {
      await (_db.delete(_db.cachedProducts)
            ..where((t) => t.tenantId.equals(tenantId)))
          .go();
      await (_db.delete(_db.cachedStock)
            ..where((t) => t.tenantId.equals(tenantId)))
          .go();
      if (products.isNotEmpty) {
        await _db.batch((b) => b.insertAll(_db.cachedProducts, products));
      }
      if (stock.isNotEmpty) {
        await _db.batch((b) => b.insertAll(_db.cachedStock, stock));
      }
      await _db.into(_db.metaEntries).insertOnConflictUpdate(MetaEntriesCompanion(
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
              (t.name.like(like) |
                  t.sku.like(like) |
                  t.barcode.like(like)))
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

    final pendingQty = await (_db.selectOnly(_db.localSaleLines)
          .join([
            innerJoin(_db.localSales, _db.localSales.clientSaleId
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

  Future<DateTime?> lastRefresh() async {
    final row = await (_db.select(_db.metaEntries)
          ..where((t) => t.key.equals('last_catalog_refresh')))
        .getSingleOrNull();
    return row == null ? null : DateTime.tryParse(row.value)?.toUtc();
  }
}
