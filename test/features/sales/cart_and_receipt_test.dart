import 'package:flutter_test/flutter_test.dart';
import 'package:business_management_system/features/sales/application/cart_controller.dart';
import 'package:business_management_system/features/sales/domain/receipt.dart';
import 'package:business_management_system/features/sales/domain/sale.dart';

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
      final controller = CartController();

      controller.add('p1', 'Mchele', 2500);
      controller.add('p2', 'Sukari', 3000);
      controller.add('p1', 'Mchele', 2500);

      expect(controller.state.lines.length, 2);
      expect(controller.state.itemCount, 3);
      expect(controller.state.lines.first.quantity, 2);
      expect(controller.state.total, 8000);
    });

    test('decrement to zero removes the line entirely', () {
      final controller = CartController()..add('p1', 'Mchele', 2500);

      controller.decrement('p1');

      expect(controller.state.isEmpty, isTrue);
    });

    test('remove drops a specific line and clear empties the cart', () {
      final controller = CartController()
        ..add('p1', 'Mchele', 2500)
        ..add('p2', 'Sukari', 3000);

      controller.remove('p1');
      expect(controller.state.lines.single.productId, 'p2');

      controller.clear();
      expect(controller.state.isEmpty, isTrue);
      expect(controller.state.total, 0);
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

  group('buildReceiptText', () {
    test('renders business name, number, lines, tax split and payment',
        () {
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

      final receipt = buildReceiptText(
        sale: sale,
        businessName: 'Duka la Mama',
        now: DateTime(2026, 8, 23, 13, 45),
      );

      expect(receipt, contains('Duka la Mama'));
      expect(receipt, contains('RISITI: S-2026-000001'));
      expect(receipt, contains('2026-08-23 13:45'));
      expect(receipt, contains('Mchele wa Tanga'));
      expect(receipt, contains('2 × 2,500'));
      expect(receipt, contains('Jumla ndogo: TSh 7,394.92'));
      expect(receipt, contains('Kodi (VAT): TSh 1,325.08'));
      expect(receipt, contains('Punguzo: TSh 200'));
      expect(receipt, contains('JUMLA: TSh 8,720'));
      expect(receipt, contains('Malipo: Cash'));
    });
  });
}
