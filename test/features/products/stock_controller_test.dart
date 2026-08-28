import 'package:flutter_test/flutter_test.dart';
import 'package:business_management_system/core/network/app_exception.dart';
import 'package:business_management_system/features/products/application/stock_controller.dart';
import 'package:business_management_system/features/products/data/product_repository.dart';
import 'package:business_management_system/features/products/domain/catalog.dart';
import 'package:business_management_system/features/products/domain/product.dart';
import 'products_controller_test.dart';

void main() {
  group('StockController', () {
    test('aggregates balances per product and sorts by quantity', () async {
      final repository = FakeProductRepository()
        ..products = [
          const Product(
            id: 'p1',
            name: 'Mchele',
            unitOfMeasureId: 'u1',
            productType: ProductType.goods,
            status: ProductStatus.active,
          ),
          const Product(
            id: 'p2',
            name: 'Sukari',
            unitOfMeasureId: 'u1',
            productType: ProductType.goods,
            status: ProductStatus.active,
          ),
        ]
        ..openingQuantities = {'p1': 50, 'p2': 5};
      final controller = StockController(repository);

      await controller.load();

      final state = controller.state as StockReady;
      expect(state.lines.first.product.id, 'p1');
      expect(state.lines.first.quantity, 50);
      expect(state.lines.length, 2);
    });

    test('empty balances transition to the empty state', () async {
      final controller = StockController(FakeProductRepository());

      await controller.load();

      expect(controller.state, isA<StockEmpty>());
    });

    test('recordOpening posts through and reloads', () async {
      final repository = FakeProductRepository()
        ..products = [
          const Product(
            id: 'p1',
            name: 'Mchele',
            unitOfMeasureId: 'u1',
            productType: ProductType.goods,
            status: ProductStatus.active,
          ),
        ];
      final controller = StockController(repository);

      await controller.recordOpening(const OpeningStockEntry(
        warehouseId: 'w1',
        productId: 'p1',
        quantity: 12,
        unitOfMeasureId: 'u1',
      ));

      expect(repository.lastOpening!.quantity, 12);
      expect(controller.state, isA<StockReady>());
    });

    test('backend errors bubble to the caller (page shows the message)',
        () async {
      final controller = StockController(_ThrowingRepository());

      await expectLater(
        controller.recordOpening(const OpeningStockEntry(
          warehouseId: 'w1',
          productId: 'p1',
          quantity: 0,
          unitOfMeasureId: 'u1',
        )),
        throwsA(isA<ConflictException>()),
      );
    });
  });
}

class _ThrowingRepository extends FakeProductRepository {
  @override
  Future<StockBalance> recordOpeningStock(OpeningStockEntry entry) async {
    throw ConflictException(
      'Opening stock has already been recorded for this product.',
    );
  }
}
