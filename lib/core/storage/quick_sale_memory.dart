import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import 'local_database.dart';

class RecentQuickSale {
  const RecentQuickSale({
    required this.name,
    required this.price,
    required this.count,
    required this.lastUsed,
  });

  final String name;
  final double price;
  final int count;
  final DateTime lastUsed;

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        'count': count,
        'lastUsed': lastUsed.toIso8601String(),
      };

  factory RecentQuickSale.fromJson(Map<String, dynamic> json) =>
      RecentQuickSale(
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        count: (json['count'] as num?)?.toInt() ?? 1,
        lastUsed: DateTime.tryParse(json['lastUsed'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Remembers the most recent quick-sale items per tenant so repeat sellers
/// (e.g. the market vendor who sells the same produce every day) can re-sell
/// them with a single tap.  Stored in the existing [MetaEntries] key-value
/// table — no schema migration required.  Fully offline.
class QuickSaleMemoryDao {
  QuickSaleMemoryDao(this._db);

  final LocalDatabase _db;
  static const _maxEntries = 8;
  static const _prefix = 'recent_quick_sales:';
  static const _productIdPrefix = 'quick_sale_product_id:';

  String _key(String tenantId) => '$_prefix$tenantId';

  /// Returns recent quick-sale entries for [tenantId], most recently used first.
  Future<List<RecentQuickSale>> recent(String tenantId) async {
    final row = await (_db.select(_db.metaEntries)
          ..where((t) => t.key.equals(_key(tenantId))))
        .getSingleOrNull();
    if (row == null) return [];
    try {
      final list = (jsonDecode(row.value) as List).cast<Map<String, dynamic>>();
      return list.map(RecentQuickSale.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  /// Remembers (or bumps the count of) a quick-sale item.
  /// The newest entry stays at the top; the list is capped at [_maxEntries].
  Future<void> remember(String tenantId, String name, double price) async {
    final existing = await recent(tenantId);
    final updated = <RecentQuickSale>[];
    var found = false;
    for (final item in existing) {
      if (item.name.toLowerCase() == name.toLowerCase()) {
        updated.add(RecentQuickSale(
          name: item.name,
          price: price,
          count: item.count + 1,
          lastUsed: DateTime.now(),
        ));
        found = true;
      } else {
        updated.add(item);
      }
    }
    if (!found) {
      updated.add(RecentQuickSale(
        name: name,
        price: price,
        count: 1,
        lastUsed: DateTime.now(),
      ));
    }
    updated.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
    final trimmed = updated.take(_maxEntries).toList();
    final now = DateTime.now().toUtc();
    await _db.into(_db.metaEntries).insertOnConflictUpdate(
          MetaEntriesCompanion(
            key: Value(_key(tenantId)),
            value: Value(jsonEncode([
              for (final item in trimmed) item.toJson(),
            ])),
            updatedAt: Value(now),
          ),
        );
  }

  /// Remembers the hidden quick-sale product id for [tenantId]. Persisted
  /// separately from the catalogue (M11 S3): the backend no longer lists the
  /// reserved-SKU product, so offline id recovery relies on this row.
  Future<void> rememberProductId(String tenantId, String productId) async {
    await _db.into(_db.metaEntries).insertOnConflictUpdate(
          MetaEntriesCompanion(
            key: Value('$_productIdPrefix$tenantId'),
            value: Value(productId),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  /// Returns the remembered quick-sale product id for [tenantId], if any.
  Future<String?> productId(String tenantId) async {
    final row = await (_db.select(_db.metaEntries)
          ..where((t) => t.key.equals('$_productIdPrefix$tenantId')))
        .getSingleOrNull();
    return row?.value;
  }
}
