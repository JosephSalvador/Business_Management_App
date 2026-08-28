import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sale.dart';

/// The POS cart. Holds product snapshots; prices are refreshed from the
/// pricing API at checkout time, so a stale cart price can never be charged.
class CartState {
  const CartState({this.lines = const []});

  final List<CartLine> lines;

  bool get isEmpty => lines.isEmpty;
  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity.round());
  double get total => lines.fold(0, (sum, line) => sum + line.lineTotal);
}

class CartController extends StateNotifier<CartState> {
  CartController() : super(const CartState());

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

  void increment(String productId) {
    final lines = [...state.lines];
    final index = lines.indexWhere((line) => line.productId == productId);
    if (index < 0) {
      return;
    }
    lines[index].quantity += 1;
    state = CartState(lines: lines);
  }

  /// Decrements; removing the last unit drops the line entirely.
  void decrement(String productId) {
    final lines = [...state.lines];
    final index = lines.indexWhere((line) => line.productId == productId);
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

  void remove(String productId) {
    state = CartState(
      lines: [
        ...state.lines.where((line) => line.productId != productId),
      ],
    );
  }

  void clear() => state = const CartState();
}
