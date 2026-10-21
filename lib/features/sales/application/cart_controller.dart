import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sale.dart';

/// The POS cart. Holds product snapshots; prices are refreshed from the
/// pricing API at checkout time, so a stale cart price can never be charged.
class CartState {
  const CartState({this.lines = const []});

  final List<CartLine> lines;

  bool get isEmpty => lines.isEmpty;
  int get itemCount =>
      lines.fold(0, (sum, line) => sum + line.quantity.round());
  double get total => lines.fold(0, (sum, line) => sum + line.lineTotal);
}

class CartController extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  void add(String productId, String name, double unitPrice) {
    final lines = [...state.lines];
    final index = lines.indexWhere((line) => line.productId == productId);
    if (index >= 0) {
      lines[index].quantity += 1;
    } else {
      lines.add(CartLine(
        productId: productId,
        name: name,
        unitPrice: unitPrice,
      ));
    }
    state = CartState(lines: lines);
  }

  /// Adds a one-off quick-sale line ("Uza Haraka") at a client-fixed price.
  /// Each quick line gets a unique key so two open-price rows never merge.
  void addQuickSale({
    required String productId,
    required String name,
    required double unitPrice,
    double quantity = 1,
  }) {
    final lines = [
      ...state.lines,
      CartLine(
        productId: productId,
        name: name,
        unitPrice: unitPrice,
        quantity: quantity,
        unitPriceOverride: unitPrice,
        key: 'quick-${DateTime.now().microsecondsSinceEpoch}',
      )
    ];
    state = CartState(lines: lines);
  }

  void increment(String key) {
    final lines = [...state.lines];
    final index = lines.indexWhere((line) => line.key == key);
    if (index < 0) {
      return;
    }
    lines[index].quantity += 1;
    state = CartState(lines: lines);
  }

  /// Decrements; removing the last unit drops the line entirely.
  void decrement(String key) {
    final lines = [...state.lines];
    final index = lines.indexWhere((line) => line.key == key);
    if (index < 0) {
      return;
    }
    if (lines[index].quantity <= 1) {
      lines.removeAt(index);
    } else {
      lines[index].quantity -= 1;
    }
    state = CartState(lines: lines);
  }

  /// Sets an exact quantity (supports decimals for weigh-and-sell lines like
  /// 0.5 kg). Quantities ≤ 0 remove the line.
  void setQuantity(String key, double quantity) {
    final lines = [...state.lines];
    final index = lines.indexWhere((line) => line.key == key);
    if (index < 0) {
      return;
    }
    if (quantity <= 0) {
      lines.removeAt(index);
    } else {
      lines[index].quantity = quantity;
    }
    state = CartState(lines: lines);
  }

  void remove(String key) {
    state = CartState(
      lines: [
        ...state.lines.where((line) => line.key != key),
      ],
    );
  }

  /// Overrides the unit price for a specific line (price override from cart).
  void setPriceOverride(String key, double newPrice) {
    final lines = [...state.lines];
    final index = lines.indexWhere((line) => line.key == key);
    if (index < 0) return;
    final old = lines[index];
    lines[index] = CartLine(
      productId: old.productId,
      name: old.name,
      unitPrice: old.unitPrice,
      quantity: old.quantity,
      unitPriceOverride: newPrice,
      key: old.key,
    );
    state = CartState(lines: lines);
  }

  void restoreLines(List<CartLine> lines) {
    state = CartState(lines: lines);
  }

  void clear() => state = const CartState();
}
