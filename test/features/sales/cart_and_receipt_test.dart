import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/app/providers.dart';
import 'package:jolinx_app/features/receipts/domain/receipt_renderer.dart';
import 'package:jolinx_app/features/sales/data/receipt_printer_service.dart';
import 'package:jolinx_app/features/sales/domain/sale.dart';

CartLine line(String id, String name, double price, [double quantity = 1]) =>
    CartLine(
      productId: id,
      name: name,
      unitPrice: price,
      quantity: quantity,
    );

void main() {
  group('CartController', () {
    test('add appends new products and increments existing ones', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(cartControllerProvider.notifier);

      controller.add('p1', 'Mchele', 2500);
      controller.add('p2', 'Sukari', 3000);
      controller.add('p1', 'Mchele', 2500);

      expect(controller.state.lines.length, 2);
      expect(controller.state.itemCount, 3);
      expect(controller.state.lines.first.quantity, 2);
      expect(controller.state.total, 8000);
    });

    test('decrement to zero removes the line entirely', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(cartControllerProvider.notifier);
      controller.add('p1', 'Mchele', 2500);

      controller.decrement('p1');

      expect(controller.state.isEmpty, isTrue);
    });

    test('remove drops a specific line and clear empties the cart', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(cartControllerProvider.notifier);
      controller
        ..add('p1', 'Mchele', 2500)
        ..add('p2', 'Sukari', 3000);

      controller.remove('p1');
      expect(controller.state.lines.single.productId, 'p2');

      controller.clear();
      expect(controller.state.isEmpty, isTrue);
      expect(controller.state.total, 0);
    });

    test('addQuickSale appends distinct lines with a client-fixed price', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(cartControllerProvider.notifier);

      controller.addQuickSale(
        productId: 'p-quick',
        name: 'Uza Haraka',
        unitPrice: 15000,
      );
      controller.addQuickSale(
        productId: 'p-quick',
        name: 'Uza Haraka',
        unitPrice: 20000,
      );

      // Two quick lines never merge even though they share the product id.
      expect(controller.state.lines.length, 2);
      expect(controller.state.total, 35000);
      expect(controller.state.lines.first.unitPriceOverride, 15000);
      expect(controller.state.lines.last.unitPriceOverride, 20000);
      expect(controller.state.lines.first.key,
          isNot(controller.state.lines.last.key));

      controller.remove(controller.state.lines.first.key);
      expect(controller.state.lines.single.unitPrice, 20000);
    });

    test('addQuickSale lines are quantity-editable without merging', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(cartControllerProvider.notifier);

      controller.addQuickSale(
        productId: 'p-quick',
        name: 'Uza Haraka',
        unitPrice: 10000,
      );
      final key = controller.state.lines.single.key;

      controller.setQuantity(key, 3);
      expect(controller.state.total, 30000);
      expect(controller.state.lines.single.quantity, 3);

      controller.decrement(key);
      expect(controller.state.lines.single.quantity, 2);
    });
  });

  group('buildCreateSaleBody', () {
    test('sends only client-allowed data with enum ints', () {
      final body = buildCreateSaleBody(
        branchId: 'b1',
        clientSaleId: 'sale-1',
        lines: [line('p1', 'Mchele', 2500, 2)],
        paymentMethod: PaymentMethod.mobileMoney,
        total: 5000,
        effectiveAt: DateTime.utc(2026, 8, 23, 9),
      );

      expect(body['branchId'], 'b1');
      expect(body['clientSaleId'], 'sale-1');
      expect(body['source'], 0);
      expect(body['effectiveAt'], '2026-08-23T09:00:00.000Z');
      expect(body['isElectronicPayment'], true);
      expect(body['lines'], [
        {'productId': 'p1', 'quantity': 2},
      ]);
      expect(body['payments'], [
        {'method': 1, 'amount': 5000},
      ]);
      expect(body.containsKey('subtotal'), isFalse);
      expect(body.containsKey('taxAmount'), isFalse);
      expect((body['lines'] as List).single.containsKey('unitPrice'), isFalse,
          reason: 'prices are resolved by the backend');
    });

    test('quick-sale line sends the typed name so the receipt shows it', () {
      final quick = CartLine(
        productId: 'p-quick',
        name: 'Dagaa wa kuchoma',
        unitPrice: 1500,
        unitPriceOverride: 1500,
        key: 'quick-1',
      );
      final body = buildCreateSaleBody(
        branchId: 'b1',
        clientSaleId: 'sale-1',
        lines: [quick],
        paymentMethod: PaymentMethod.cash,
        total: 1500,
      );

      final lines = body['lines'] as List;
      expect(
          lines,
          [
            {
              'productId': 'p-quick',
              'quantity': 1,
              'unitPrice': 1500,
              'productName': 'Dagaa wa kuchoma',
            },
          ],
          reason:
              'the receipt must carry the cashier-typed name, not "Bila Jina"');
    });

    test('credit sale links a customer and stays non-electronic', () {
      final body = buildCreateSaleBody(
        branchId: 'b1',
        clientSaleId: 'sale-1',
        lines: [line('p1', 'Mchele', 2500, 2)],
        paymentMethod: PaymentMethod.credit,
        total: 5000,
        customerId: 'cust-1',
      );

      expect(body['customerId'], 'cust-1');
      expect(body['isElectronicPayment'], isFalse,
          reason: 'an in-house credit balance is not an electronic tender');
      expect(body['payments'], [
        {'method': 4, 'amount': 0},
      ]);
    });

    test('credit sale honours an explicit initial payment', () {
      final body = buildCreateSaleBody(
        branchId: 'b1',
        clientSaleId: 'sale-1',
        lines: [line('p1', 'Mchele', 2500, 2)],
        paymentMethod: PaymentMethod.credit,
        total: 5000,
        paymentAmount: 2000,
      );

      expect(body['payments'], [
        {'method': 4, 'amount': 2000},
      ]);
    });
  });

  group('SaleDto parsing', () {
    test('parses totals, lines and payment labels', () {
      final sale = SaleDto.fromJson({
        'id': 's1',
        'number': 'S-2026-000042',
        'status': 0,
        'saleDate': '2026-08-23T10:00:00Z',
        'currency': 'TZS',
        'subtotal': 7394.92,
        'discountAmount': 0,
        'taxAmount': 1325.08,
        'totalAmount': 8720,
        'amountPaid': 8720,
        'change': 0,
        'customer': null,
        'lines': [
          {
            'productName': 'Mchele',
            'quantity': 2,
            'unitPrice': 2500,
            'discountAmount': 0,
            'taxCode': 'A',
            'appliedRate': 0.18,
            'baseAmount': 6779.66,
            'taxAmount': 720,
            'lineTotal': 5000,
          },
        ],
        'payments': [
          {'method': 1, 'amount': 8720},
        ],
      });

      expect(sale.number, 'S-2026-000042');
      expect(sale.totalAmount, 8720);
      expect(sale.taxAmount, closeTo(1325.08, 0.001));
      expect(sale.lines.single.productName, 'Mchele');
      expect(sale.payments.single.label, 'Mobile Money');
      expect(sale.isVoided, isFalse);
    });

    test('tolerates null optionals from older payloads', () {
      final sale = SaleDto.fromJson({
        'id': 's2',
        'totalAmount': 100,
        'lines': <dynamic>[],
        'payments': <dynamic>[],
      });

      expect(sale.number, '');
      expect(sale.subtotal, 0);
      expect(sale.isVoided, isFalse);
    });
  });

  group('saleToReceipt + Thermal80mmRenderer', () {
    test('renders business name, number, lines, tax split and payment', () {
      final sale = SaleDto.fromJson({
        'id': 's1',
        'number': 'S-2026-000001',
        'status': 0,
        'saleDate': '2026-08-23T10:00:00Z',
        'currency': 'TZS',
        'subtotal': 7394.92,
        'discountAmount': 200,
        'taxAmount': 1325.08,
        'totalAmount': 8720,
        'amountPaid': 8720,
        'change': 0,
        'lines': [
          {
            'productName': 'Mchele wa Tanga',
            'quantity': 2,
            'unitPrice': 2500,
            'discountAmount': 0,
            'taxCode': 'A',
            'lineTotal': 5000,
          },
          {
            'productName': 'Sukari',
            'quantity': 1,
            'unitPrice': 3000,
            'discountAmount': 200,
            'taxCode': 'A',
            'lineTotal': 3000,
          },
        ],
        'payments': [
          {'method': 0, 'amount': 8720},
        ],
      });

      final receipt = ReceiptPrinterService().saleToReceipt(
        sale: sale,
        businessName: 'Duka la Mama',
      );
      final text = const Thermal80mmRenderer(
        language: ReceiptLanguage.swahili,
      ).render(receipt: receipt);

      expect(text, contains('Duka la Mama'));
      expect(text, contains('Risiti Na.'));
      expect(text, contains('S-2026-000001'));
      expect(text, matches(RegExp(r'\d{2}-Aug-2026')));

      expect(text, contains('Mchele wa Tanga'));
      expect(text, contains('Sukari'));
      // two-line layout: indented calculation on left, line total on right.
      expect(text, contains('  2 x 2,500.00'));
      expect(text, contains('5,000.00'));
      expect(text, contains('  1 x 3,000.00'));
      expect(text, contains('3,000.00'));

      expect(text, contains('Jumla ndogo'));
      expect(text, contains('TZS 7,394.92'));
      expect(text, contains('Punguzo (3%)'));
      expect(text, contains('-TZS 200.00'));
      expect(text, isNot(contains('VAT')));
      expect(text, isNot(contains('1,325.08')));

      expect(text, contains('JUMLA'));
      expect(text, contains('TZS 8,720.00'));
      expect(text, contains('Njia ya Malipo'));
      expect(text, contains('Cash'));
      expect(text, isNot(contains('Change')));
    });
  });
}
