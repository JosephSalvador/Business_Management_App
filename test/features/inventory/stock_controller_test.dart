import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/features/inventory/application/stock_controller.dart';
import 'package:jolinx_app/features/products/domain/catalog.dart';

void main() {
  group('StockRow', () {
    test('status returns out when quantity is zero', () {
      const row = StockRow(
        warehouseId: 'w1',
        warehouseName: 'Main Store',
        productId: 'p1',
        name: 'Mchele',
        sku: null,
        barcode: null,
        unitOfMeasureName: 'kg',
        quantity: 0,
      );
      expect(row.status(5), StockHealth.out);
    });

    test('status returns out when quantity is negative', () {
      const row = StockRow(
        warehouseId: 'w1',
        warehouseName: 'Main Store',
        productId: 'p1',
        name: 'Mchele',
        sku: null,
        barcode: null,
        unitOfMeasureName: 'kg',
        quantity: -3,
      );
      expect(row.status(5), StockHealth.out);
    });

    test('status returns low when quantity is below threshold', () {
      const row = StockRow(
        warehouseId: 'w1',
        warehouseName: 'Main Store',
        productId: 'p1',
        name: 'Mchele',
        sku: null,
        barcode: null,
        unitOfMeasureName: 'kg',
        quantity: 3,
      );
      expect(row.status(5), StockHealth.low);
    });

    test('status returns ok when quantity meets threshold', () {
      const row = StockRow(
        warehouseId: 'w1',
        warehouseName: 'Main Store',
        productId: 'p1',
        name: 'Mchele',
        sku: null,
        barcode: null,
        unitOfMeasureName: 'kg',
        quantity: 10,
      );
      expect(row.status(5), StockHealth.ok);
    });
  });

  group('StockReady.visible', () {
    StockReady makeState({
      required List<StockRow> rows,
      String search = '',
      bool lowOnly = false,
      String? selectedWarehouseId,
    }) {
      return StockReady(
        rows: rows,
        warehouses: const [
          Warehouse(id: 'w1', name: 'Main Store', code: 'MAINSTORE'),
        ],
        search: search,
        lowOnly: lowOnly,
        sort: StockSort.alphabetical,
        lowThreshold: 5,
        selectedWarehouseId: selectedWarehouseId,
        stale: false,
      );
    }

    test('filters by search query', () {
      final state = makeState(rows: const [
        StockRow(
          warehouseId: 'w1',
          warehouseName: 'Main Store',
          productId: 'p1',
          name: 'Mchele',
          sku: null,
          barcode: null,
          unitOfMeasureName: 'kg',
          quantity: 10,
        ),
        StockRow(
          warehouseId: 'w1',
          warehouseName: 'Main Store',
          productId: 'p2',
          name: 'Sukari',
          sku: null,
          barcode: null,
          unitOfMeasureName: 'kg',
          quantity: 20,
        ),
      ], search: 'Mche');

      expect(state.visible.length, 1);
      expect(state.visible.first.name, 'Mchele');
    });

    test('filters low-only items', () {
      final state = makeState(rows: const [
        StockRow(
          warehouseId: 'w1',
          warehouseName: 'Main Store',
          productId: 'p1',
          name: 'Mchele',
          sku: null,
          barcode: null,
          unitOfMeasureName: 'kg',
          quantity: 1,
        ),
        StockRow(
          warehouseId: 'w1',
          warehouseName: 'Main Store',
          productId: 'p2',
          name: 'Sukari',
          sku: null,
          barcode: null,
          unitOfMeasureName: 'kg',
          quantity: 50,
        ),
      ], lowOnly: true);

      expect(state.visible.length, 1);
      expect(state.visible.first.name, 'Mchele');
    });

    test('filters by warehouse', () {
      final state = makeState(rows: const [
        StockRow(
          warehouseId: 'w1',
          warehouseName: 'Main Store',
          productId: 'p1',
          name: 'Mchele',
          sku: null,
          barcode: null,
          unitOfMeasureName: 'kg',
          quantity: 10,
        ),
        StockRow(
          warehouseId: 'w2',
          warehouseName: 'Branch 2',
          productId: 'p2',
          name: 'Sukari',
          sku: null,
          barcode: null,
          unitOfMeasureName: 'kg',
          quantity: 20,
        ),
      ], selectedWarehouseId: 'w1');

      expect(state.visible.length, 1);
      expect(state.visible.first.productId, 'p1');
    });

    test('sorts alphabetically by default', () {
      final state = makeState(rows: const [
        StockRow(
          warehouseId: 'w1',
          warehouseName: 'Main Store',
          productId: 'p2',
          name: 'Sukari',
          sku: null,
          barcode: null,
          unitOfMeasureName: 'kg',
          quantity: 10,
        ),
        StockRow(
          warehouseId: 'w1',
          warehouseName: 'Main Store',
          productId: 'p1',
          name: 'Mchele',
          sku: null,
          barcode: null,
          unitOfMeasureName: 'kg',
          quantity: 20,
        ),
      ]);

      expect(state.visible.first.name, 'Mchele');
      expect(state.visible.last.name, 'Sukari');
    });

    test('counts ok/low/out correctly', () {
      final state = makeState(rows: const [
        StockRow(
          warehouseId: 'w1',
          warehouseName: 'Main Store',
          productId: 'p1',
          name: 'Mchele',
          sku: null,
          barcode: null,
          unitOfMeasureName: 'kg',
          quantity: 10,
        ),
        StockRow(
          warehouseId: 'w1',
          warehouseName: 'Main Store',
          productId: 'p2',
          name: 'Sukari',
          sku: null,
          barcode: null,
          unitOfMeasureName: 'kg',
          quantity: 2,
        ),
        StockRow(
          warehouseId: 'w1',
          warehouseName: 'Main Store',
          productId: 'p3',
          name: 'Mafuta',
          sku: null,
          barcode: null,
          unitOfMeasureName: 'ltr',
          quantity: 0,
        ),
      ]);

      final counts = state.counts;
      expect(counts.ok, 1);
      expect(counts.low, 1);
      expect(counts.out, 1);
      expect(counts.total, 3);
    });
  });
}
