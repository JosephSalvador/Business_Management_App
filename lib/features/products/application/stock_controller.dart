import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';

/// The Stock tab: what is on the shelf, per product, in the default warehouse.
sealed class StockState {
  const StockState();
}

class StockLoading extends StockState {
  const StockLoading();
}

class StockReady extends StockState {
  const StockReady({required this.lines});

  /// One line per product that has any balance, highest quantity first.
  final List<StockLine> lines;
}

class StockEmpty extends StockState {
  const StockEmpty();
}

class StockFailure extends StockState {
  const StockFailure(this.message);

  final String message;
}

class StockLine {
  const StockLine({
    required this.product,
    required this.quantity,
    required this.warehouseName,
  });

  final Product product;
  final double quantity;
  final String warehouseName;
}

class StockController extends StateNotifier<StockState> {
  StockController(this._repository) : super(const StockLoading());

  final ProductRepository _repository;

  Future<void> load() async {
    state = const StockLoading();
    try {
      final results = await (
        _repository.balances(),
        _repository.list(pageSize: 200),
        _repository.warehouses(),
      ).wait;
      final balances = results.$1;
      if (balances.isEmpty) {
        state = const StockEmpty();
        return;
      }
      final products = {
        for (final product in results.$2.items) product.id: product,
      };
      final warehouses = {
        for (final warehouse in results.$3) warehouse.id: warehouse.name,
      };
      final quantities = <String, double>{};
      final productWarehouse = <String, String>{};
      for (final balance in balances) {
        quantities[balance.productId] =
            (quantities[balance.productId] ?? 0) + balance.quantity;
        productWarehouse.putIfAbsent(balance.productId, () => balance.warehouseId);
      }
      final lines = quantities.entries
          .where((entry) => products.containsKey(entry.key))
          .map((entry) => StockLine(
                product: products[entry.key]!,
                quantity: entry.value,
                warehouseName:
                    warehouses[productWarehouse[entry.key]] ?? 'Main Store',
              ))
          .toList(growable: false)
        ..sort((a, b) => b.quantity.compareTo(a.quantity));
      state = StockReady(lines: lines);
    } on AppException catch (error) {
      state = StockFailure(error.message);
    }
  }

  /// Records opening stock through the backend; the returned truth refreshes
  /// this tab.
  Future<void> recordOpening(OpeningStockEntry entry) async {
    await _repository.recordOpeningStock(entry);
    await load();
  }

  void reset() {
    state = const StockLoading();
  }
}
