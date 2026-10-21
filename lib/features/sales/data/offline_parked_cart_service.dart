import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../../../core/storage/offline_cache_dao.dart';
import '../domain/sale.dart';

/// A parked/held cart awaiting checkout.
class ParkedCart {
  const ParkedCart({
    required this.id,
    required this.label,
    required this.lines,
    required this.createdAt,
    this.customerId,
    this.customerName,
  });

  final String id;
  final String label;
  final List<CartLine> lines;
  final DateTime createdAt;
  final String? customerId;
  final String? customerName;

  double get total => lines.fold(0, (sum, l) => sum + l.lineTotal);
  int get itemCount => lines.fold(0, (sum, l) => sum + l.quantity.round());

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'createdAt': createdAt.toIso8601String(),
        'customerId': customerId,
        'customerName': customerName,
        'lines': lines
            .map((l) => {
                  'productId': l.productId,
                  'name': l.name,
                  'unitPrice': l.unitPrice,
                  'quantity': l.quantity,
                  'unitPriceOverride': l.unitPriceOverride,
                  'key': l.key,
                })
            .toList(),
      };

  factory ParkedCart.fromJson(Map<String, dynamic> json) => ParkedCart(
        id: json['id'] as String,
        label: json['label'] as String? ?? 'Oda ya Pembeni',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        customerId: json['customerId'] as String?,
        customerName: json['customerName'] as String?,
        lines: (json['lines'] as List? ?? [])
            .map((l) => CartLine(
                  productId: l['productId'] as String? ?? '',
                  name: l['name'] as String? ?? '',
                  unitPrice: (l['unitPrice'] as num?)?.toDouble() ?? 0.0,
                  quantity: (l['quantity'] as num?)?.toDouble() ?? 1.0,
                  unitPriceOverride:
                      (l['unitPriceOverride'] as num?)?.toDouble(),
                  key: l['key'] as String?,
                ))
            .toList(),
      );
}

/// Manages multiple draft carts ("Weka Oda Pembeni") in offline SQLite.
class OfflineParkedCartService {
  OfflineParkedCartService({
    required OfflineCacheDao cache,
    Uuid uuid = const Uuid(),
  })  : _cache = cache,
        _uuid = uuid;

  final OfflineCacheDao _cache;
  final Uuid _uuid;

  static const _storageKey = 'pos:parked_carts';

  /// Lists all currently parked draft carts.
  Future<List<ParkedCart>> listParkedCarts() async {
    final data = await _cache.load(_storageKey);
    if (data == null || data['items'] is! List) {
      return [];
    }
    final list = <ParkedCart>[];
    for (final item in data['items'] as List) {
      if (item is Map<String, dynamic>) {
        list.add(ParkedCart.fromJson(item));
      } else if (item is Map) {
        list.add(ParkedCart.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return list;
  }

  /// Parks the current cart lines under an identifier or customer name.
  Future<ParkedCart> parkCart({
    required List<CartLine> lines,
    String? label,
    String? customerId,
    String? customerName,
  }) async {
    final carts = await listParkedCarts();
    final now = DateTime.now();
    final defaultLabel =
        customerName?.isNotEmpty == true
            ? customerName!
            : 'Oda #${carts.length + 1} - ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final cart = ParkedCart(
      id: _uuid.v4(),
      label: label ?? defaultLabel,
      lines: lines,
      createdAt: now,
      customerId: customerId,
      customerName: customerName,
    );

    final updated = [...carts, cart];
    await _saveAll(updated);
    return cart;
  }

  /// Removes and returns a parked cart to restore it to the checkout register.
  Future<ParkedCart?> restoreCart(String cartId) async {
    final carts = await listParkedCarts();
    final index = carts.indexWhere((c) => c.id == cartId);
    if (index < 0) return null;

    final target = carts[index];
    carts.removeAt(index);
    await _saveAll(carts);
    return target;
  }

  /// Discards a parked cart permanently.
  Future<void> discardCart(String cartId) async {
    final carts = await listParkedCarts();
    carts.removeWhere((c) => c.id == cartId);
    await _saveAll(carts);
  }

  Future<void> _saveAll(List<ParkedCart> carts) async {
    await _cache.save(_storageKey, {
      'items': carts.map((c) => c.toJson()).toList(),
    });
  }
}
