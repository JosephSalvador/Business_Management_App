import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/features/receipts/domain/receipt_preview.dart';
import 'package:jolinx_app/features/receipts/domain/receipt_renderer.dart';
import 'package:jolinx_app/features/receipts/domain/receipt_qr.dart';
import 'package:jolinx_app/features/receipts/domain/receipt_layout.dart';
import 'package:jolinx_app/features/receipts/domain/business_identity.dart';

void main() {
  group('ReceiptPreview', () {
    test('fromJson deserializes complete receipt', () {
      final json = {
        'saleId': 'test-sale-id',
        'saleNumber': 'S-2026-000001',
        'saleDate': '2026-09-07T10:30:00Z',
        'subtotal': 100.0,
        'taxAmount': 15.25,
        'totalAmount': 100.0,
        'discountAmount': 0.0,
        'amountPaid': 100.0,
        'change': 0.0,
        'printCount': 0,
        'isReprint': false,
        'isVoided': false,
        'hasMetadata': true,
        'businessName': 'Jolinx Shop',
        'tin': '123456789',
        'address': 'Dar es Salaam',
        'phone': '+255712345678',
        'email': 'info@jolinx.co.tz',
        'branchName': 'Downtown Branch',
        'cashierName': 'John Doe',
        'customerName': 'Jane Customer',
        'currency': 'TZS',
        'qrPayload': 'Jolinx Shop\nRISITI: S-2026-000001',
        'lines': [
          {
            'productName': 'Fanta 500ml',
            'quantity': 1,
            'unitPrice': 100.0,
            'discountAmount': 0,
            'taxCode': 'A',
            'taxAmount': 15.25,
            'lineTotal': 100.0,
          }
        ],
        'payments': [
          {
            'method': 'Card',
            'amount': 100.0,
            'reference': 'TXN-56587451236',
          }
        ],
      };

      final receipt = ReceiptPreview.fromJson(json);

      expect(receipt.saleId, 'test-sale-id');
      expect(receipt.saleNumber, 'S-2026-000001');
      expect(receipt.lines, hasLength(1));
      expect(receipt.lines.first.productName, 'Fanta 500ml');
      expect(receipt.payments, hasLength(1));
      expect(receipt.businessName, 'Jolinx Shop');
      expect(receipt.tin, '123456789');
      expect(receipt.address, 'Dar es Salaam');
      expect(receipt.phone, '+255712345678');
      expect(receipt.qrPayload, contains('Jolinx Shop'));

      // Identity + sale projection added for the redesigned ticket.
      expect(receipt.email, 'info@jolinx.co.tz');
      expect(receipt.branchName, 'Downtown Branch');
      expect(receipt.cashierName, 'John Doe');
      expect(receipt.customerName, 'Jane Customer');
      expect(receipt.currency, 'TZS');
      expect(receipt.payments.first.reference, 'TXN-56587451236');
    });

    test('fromJson handles optional fields', () {
      final json = {
        'saleId': 'test-sale-id',
        'saleNumber': 'S-2026-000001',
        'saleDate': '2026-09-07T10:30:00Z',
        'subtotal': 100.0,
        'taxAmount': 15.25,
        'totalAmount': 100.0,
        'discountAmount': 0.0,
        'amountPaid': 100.0,
        'change': 0.0,
        'printCount': 0,
        'isReprint': false,
        'isVoided': false,
        'hasMetadata': false,
        'businessName': 'Jolinx Shop',
        'lines': [],
        'payments': [],
      };

      final receipt = ReceiptPreview.fromJson(json);
      expect(receipt.tin, isNull);
      expect(receipt.address, isNull);
      expect(receipt.phone, isNull);
      expect(receipt.email, isNull);
      expect(receipt.branchName, isNull);
      expect(receipt.cashierName, isNull);
      expect(receipt.customerName, isNull);
      // Missing key on a pre-upgrade cache file → platform default currency.
      expect(receipt.currency, 'TZS');
      // Missing payload reads as empty string, never null.
      expect(receipt.qrPayload, '');
      expect(receipt.payments, isEmpty);
    });

    test('fromJson handles reprint flag', () {
      final json = {
        'saleId': 'test-sale-id',
        'saleNumber': 'S-2026-000001',
        'saleDate': '2026-09-07T10:30:00Z',
        'subtotal': 100.0,
        'taxAmount': 15.25,
        'totalAmount': 100.0,
        'discountAmount': 0.0,
        'amountPaid': 100.0,
        'change': 0.0,
        'printCount': 2,
        'isReprint': true,
        'isVoided': false,
        'hasMetadata': true,
        'businessName': 'Jolinx Shop',
        'lines': [],
        'payments': [],
      };

      final receipt = ReceiptPreview.fromJson(json);
      expect(receipt.isReprint, isTrue);
      expect(receipt.printCount, 2);
    });

    test('toJson round-trips every field through the local cache', () {
      final original = _createTestReceipt(
        fiscalHash: 'a1b2c3d4',
        qrPayload: 'Jolinx Shop\nRISITI: S-2026-000001',
      );

      final restored = ReceiptPreview.fromJson(original.toJson());

      expect(restored.saleId, original.saleId);
      expect(restored.saleNumber, original.saleNumber);
      expect(restored.saleDate, original.saleDate);
      expect(restored.businessName, original.businessName);
      expect(restored.email, original.email);
      expect(restored.branchName, original.branchName);
      expect(restored.cashierName, original.cashierName);
      expect(restored.customerName, original.customerName);
      expect(restored.currency, original.currency);
      expect(restored.fiscalHash, original.fiscalHash);
      expect(restored.qrPayload, original.qrPayload);
      expect(restored.payments.single.reference,
          original.payments.single.reference);
      expect(restored.lines, hasLength(original.lines.length));
      expect(restored.lines.first.unitPrice, original.lines.first.unitPrice);
      expect(restored.subtotal, original.subtotal);
      expect(restored.totalAmount, original.totalAmount);
      expect(restored.amountPaid, original.amountPaid);
      expect(restored.change, original.change);
    });
  });

  group('Thermal80mmRenderer', () {
    late Thermal80mmRenderer renderer;

    setUp(() {
      renderer = const Thermal80mmRenderer();
    });

    test('render includes business name', () {
      final output = renderer.render(receipt: _createTestReceipt());
      expect(output, contains('Jolinx Shop'));
    });

    test('render includes branch, address, phone, email and tax number', () {
      final output = renderer.render(receipt: _createTestReceipt());
      expect(output, contains('Downtown Branch'));
      expect(output, contains('Dar es Salaam'));
      expect(output, contains('Phone: +255712345678'));
      expect(output, contains('Email: info@jolinx.co.tz'));
      expect(output, contains('TIN: 123456789'));
    });

    test('render omits header lines that have no value', () {
      final receipt = ReceiptPreview(
        saleId: 's',
        saleNumber: 'S-1',
        saleDate: DateTime(2026, 9, 7, 10, 30),
        isVoided: false,
        hasMetadata: false,
        isReprint: false,
        printCount: 0,
        businessName: 'Jolinx Shop',
        currency: 'TZS',
        qrPayload: '',
        lines: [],
        payments: [],
        subtotal: 0,
        taxAmount: 0,
        discountAmount: 0,
        totalAmount: 0,
        amountPaid: 0,
        change: 0,
      );

      final output = renderer.render(receipt: receipt);
      expect(output, contains('Jolinx Shop'));
      expect(output, isNot(contains('Phone:')));
      expect(output, isNot(contains('Email:')));
      expect(output, isNot(contains('TIN:')));
      expect(output, isNot(contains('Downtown Branch')));
    });

    test('render includes the meta block', () {
      final output = renderer.render(receipt: _createTestReceipt());
      expect(output, contains('Receipt No.     : S-2026-000001'));
      expect(output, contains('Date / Time     : 07-Sep-2026 10:30 AM'));
      expect(output, contains('Cashier         : John Doe'));
      expect(output, contains('Customer        : Walk-in Customer'));
    });

    test('render falls back to the walk-in label when customer is null', () {
      final output = renderer.render(
        receipt: _createTestReceipt(customerName: null),
      );
      expect(output, contains('Customer        : Walk-in Customer'));
    });

    test('render omits the cashier row when there is no cashier', () {
      final output = renderer.render(
        receipt: _createTestReceipt(cashierName: null),
      );
      expect(output, isNot(contains('Cashier')));
    });

    test('render includes item header and unit price plus line total', () {
      final output = renderer.render(receipt: _createTestReceipt());
      expect(output, contains('ITEM'));
      expect(output, contains('TOTAL'));
      expect(output, contains('Paracetamol 500mg'));
      expect(output, contains('  4 x 2.50'));
      expect(output, matches(RegExp(r'10\.00')));
    });

    test('render emits subtotal and discount percent, never a tax row', () {
      final output = renderer.render(receipt: _createTestReceipt());
      expect(output, contains('Subtotal'));
      expect(output, contains('TZS 20.00'));
      expect(output, contains('Discount (5%)'));
      expect(output, contains('-TZS 1.00'));
      // VAT is not implemented yet: no tax row, no derived percentage.
      expect(output, isNot(contains('VAT')));
      expect(output, isNot(contains('TZS 1.90')));
    });

    test('render omits the discount row when it is zero', () {
      final output = renderer.render(
        receipt: _createTestReceipt(discountAmount: 0, taxAmount: 0),
      );
      expect(output, isNot(contains('Discount')));
      expect(output, contains('TZS 20.00'));
    });

    test('render prints the grand total under the equals rule', () {
      final output = renderer.render(receipt: _createTestReceipt());
      expect(output, contains('=' * 42));
      expect(output, contains('GRAND TOTAL'));
      expect(output, contains('TZS 20.90'));
    });

    test('render includes sale number', () {
      final output = renderer.render(receipt: _createTestReceipt());
      expect(output, contains('S-2026-000001'));
    });

    test('render includes product name and quantity', () {
      final output = renderer.render(receipt: _createTestReceipt());
      expect(output, contains('Paracetamol 500mg'));
      expect(output, contains('Vitamin C 1000mg'));
      // two-line layout: indented calculation on line 2, line total on right.
      expect(output, contains('  4 x 2.50'));
      expect(output, contains('10.00'));
      expect(output, contains('  2 x 5.00'));
    });

    test('render includes payment method and paid amount', () {
      final output = renderer.render(receipt: _createTestReceipt());
      expect(output, contains('Payment Method'));
      expect(output, contains('Card'));
      expect(output, contains('Paid Amount'));
      expect(output, contains('TZS 70.90'));
      expect(output, contains('Change'));
      expect(output, contains('TZS 50.00'));
    });

    test('render includes transaction id when a payment has a reference', () {
      final output = renderer.render(receipt: _createTestReceipt());
      expect(output, contains('Transaction ID'));
      expect(output, contains('TXN-56587451236'));
    });

    test('render omits transaction id when no payment has a reference', () {
      final output = renderer.render(
        receipt: _createTestReceipt(payments: [
          const ReceiptPayment(method: 'Cash', amount: 70.9),
        ]),
      );
      expect(output, isNot(contains('Transaction ID')));
      expect(output, contains('Cash'));
    });

    test('render includes the policy footer', () {
      final output = renderer.render(receipt: _createTestReceipt());
      expect(output, contains('Thank you for shopping with us!'));
      expect(output, contains('Goods once sold will not be taken back.'));
      expect(output, contains('Visit us again!'));
      expect(output, contains('Jolinx ERP'));
    });

    test('render includes date', () {
      final output = renderer.render(receipt: _createTestReceipt());
      expect(output, contains('2026'));
    });

    test('render shows reprint watermark when isReprint is true', () {
      final output = renderer.render(
        receipt: _createTestReceipt(),
        isReprint: true,
      );
      expect(output, contains('*** REPRINT ***'));
    });

    test('render does not show reprint watermark for original', () {
      final output = renderer.render(receipt: _createTestReceipt());
      expect(output, isNot(contains('REPRINT')));
    });

    test('render shows the voided marker for a voided sale', () {
      final receipt = ReceiptPreview(
        saleId: 's',
        saleNumber: 'S-1',
        saleDate: DateTime(2026, 9, 7),
        isVoided: true,
        hasMetadata: true,
        isReprint: false,
        printCount: 0,
        businessName: 'Jolinx Shop',
        currency: 'TZS',
        qrPayload: '',
        lines: const [],
        payments: const [],
        subtotal: 0,
        taxAmount: 0,
        discountAmount: 0,
        totalAmount: 0,
        amountPaid: 0,
        change: 0,
      );
      expect(
          renderer.render(receipt: receipt), contains('*** SALE VOIDED ***'));
    });

    test('render prints the tenant currency with two decimals', () {
      final output = renderer.render(receipt: _createTestReceipt());
      expect(output, contains('TZS 20.90'));
      expect(output, contains('TZS 20.00'));
      expect(output, isNot(contains('TSh')));
    });

    test('render keeps the sale currency from the tenant', () {
      final output = renderer.render(
        receipt: _createTestReceipt(currency: 'KES'),
      );
      expect(output, contains('KES 20.90'));
    });

    test('render includes fiscal hash when present', () {
      final output = renderer.render(
        receipt: _createTestReceipt(fiscalHash: 'abc123hash'),
      );
      expect(output, contains('Verification: abc123hash'));
    });

    test('render omits the verification row when there is no fiscal hash', () {
      final output = renderer.render(receipt: _createTestReceipt());
      expect(output, isNot(contains('Verification')));
    });

    test('render renders in Swahili when asked', () {
      const swahili = Thermal80mmRenderer(language: ReceiptLanguage.swahili);
      final output = swahili.render(
        receipt: _createTestReceipt(
          fiscalHash: 'abc123hash',
          customerName: null,
        ),
      );
      expect(output, contains('Risiti Na.'));
      expect(output, contains('Tarehe / Muda'));
      expect(output, contains('Mteja wa kupita-njia'));
      expect(output, contains('Jumla ndogo'));
      expect(output, contains('Punguzo (5%)'));
      // VAT is not implemented yet: no tax row and no tax figure anywhere.
      expect(output, isNot(contains('VAT')));
      expect(output, isNot(contains('TZS 1.90')));
      expect(output, contains('Thibitisho: abc123hash'));
      expect(output, isNot(contains('Verification')));
    });

    test('render includes the QR marker and sale caption when a payload exists',
        () {
      final output = renderer.render(
        receipt: _createTestReceipt(qrPayload: 'Test QR payload'),
      );
      expect(output, contains('[QR CODE]'));
      expect(output, contains('S-2026-000001'));
    });

    test('render omits the QR marker when the payload is empty', () {
      final output = renderer.render(receipt: _createTestReceipt());
      expect(output, isNot(contains('[QR CODE]')));
    });

    test('every rendered line fits the 42 column paper', () {
      final receipt = _createTestReceipt(
        lines: [
          ReceiptLine(
            productName:
                'Extremely Long Product Name That Will Not Fit In One Line At All',
            quantity: 12.5,
            unitPrice: 1234567.89,
            discountAmount: 0,
            taxCode: 'A',
            taxAmount: 0,
            lineTotal: 15432098.63,
          ),
          const ReceiptLine(
            productName: 'Sukari ya Tanga Bag 25kg',
            quantity: 3,
            unitPrice: 100000,
            discountAmount: 0,
            taxCode: 'A',
            taxAmount: 0,
            lineTotal: 300000,
          ),
        ],
        subtotal: 99999999.99,
        discountAmount: 5000000.00,
        taxAmount: 14250000.00,
        totalAmount: 109249999.99,
        amountPaid: 110000000.00,
        change: 750000.01,
        customerName:
            'A Customer Name That Is Far Too Long For The Meta Column',
        cashierName: 'A Cashier Name That Is Also Far Too Long For The Column',
      );

      final output = renderer.render(receipt: receipt, isReprint: true);

      for (final line in output.split('\n')) {
        expect(line.length, lessThanOrEqualTo(42),
            reason: 'line too wide: "$line"');
      }
    });

    test('every rendered line fits the 32 column paper on 58mm preset', () {
      final renderer58 = Thermal80mmRenderer.mm58();
      final receipt = _createTestReceipt(
        lines: [
          ReceiptLine(
            productName:
                'Extremely Long Product Name That Will Not Fit In One Line At All',
            quantity: 12.5,
            unitPrice: 1234567.89,
            discountAmount: 0,
            taxCode: 'A',
            taxAmount: 0,
            lineTotal: 15432098.63,
          ),
          const ReceiptLine(
            productName: 'Sukari ya Tanga Bag 25kg',
            quantity: 3,
            unitPrice: 100000,
            discountAmount: 0,
            taxCode: 'A',
            taxAmount: 0,
            lineTotal: 300000,
          ),
        ],
        subtotal: 99999999.99,
        discountAmount: 5000000.00,
        taxAmount: 14250000.00,
        totalAmount: 109249999.99,
        amountPaid: 110000000.00,
        change: 750000.01,
        customerName:
            'A Customer Name That Is Far Too Long For The Meta Column',
        cashierName: 'A Cashier Name That Is Also Far Too Long For The Column',
      );

      final output = renderer58.render(receipt: receipt, isReprint: true);

      for (final line in output.split('\n')) {
        expect(line.length, lessThanOrEqualTo(32),
            reason: 'line too wide for 58mm: "$line"');
      }
    });
  });

  group('ReceiptLayout', () {
    test('fromJson deserializes layout', () {
      final json = {
        'id': 'test-layout-id',
        'layoutId': 'thermal_80mm_default',
        'version': 1,
        'isActive': true,
      };

      final layout = ReceiptLayout.fromJson(json);
      expect(layout.layoutId, 'thermal_80mm_default');
      expect(layout.version, 1);
      expect(layout.isActive, isTrue);
    });

    test('fromJson handles optional specJson', () {
      final json = {
        'id': 'test-layout-id',
        'layoutId': 'thermal_80mm_default',
        'version': 2,
        'isActive': false,
        'specJson': '{"margins":10}',
      };

      final layout = ReceiptLayout.fromJson(json);
      expect(layout.version, 2);
      expect(layout.isActive, isFalse);
      expect(layout.specJson, '{"margins":10}');
    });
  });

  group('BusinessIdentity', () {
    test('fromJson deserializes identity', () {
      final json = {
        'businessName': 'Jolinx Shop',
        'tin': '123456789',
        'address': 'Dar es Salaam',
        'phone': '+255712345678',
        'email': 'info@jolinx.co.tz',
      };

      final identity = BusinessIdentity.fromJson(json);
      expect(identity.businessName, 'Jolinx Shop');
      expect(identity.tin, '123456789');
      expect(identity.address, 'Dar es Salaam');
      expect(identity.phone, '+255712345678');
      expect(identity.email, 'info@jolinx.co.tz');
    });

    test('fromJson handles optional fields', () {
      final json = {
        'businessName': 'Jolinx Shop',
      };

      final identity = BusinessIdentity.fromJson(json);
      expect(identity.businessName, 'Jolinx Shop');
      expect(identity.tin, isNull);
      expect(identity.address, isNull);
    });

    test('toJson round-trips correctly', () {
      const identity = BusinessIdentity(
        businessName: 'Jolinx Shop',
        tin: '123456789',
        address: 'Dar es Salaam',
      );

      final json = identity.toJson();
      final restored = BusinessIdentity.fromJson(json);
      expect(restored.businessName, 'Jolinx Shop');
      expect(restored.tin, '123456789');
      expect(restored.address, 'Dar es Salaam');
    });
  });

  group('ReceiptDtos', () {
    test('PrintEventRecorded.fromJson deserializes', () {
      final json = {
        'eventId': 'test-event-id',
        'saleId': 'test-sale-id',
        'type': 'Original',
        'printedAt': '2026-09-07T10:30:00Z',
      };

      final recorded = PrintEventRecorded.fromJson(json);
      expect(recorded.eventId, 'test-event-id');
      expect(recorded.saleId, 'test-sale-id');
      expect(recorded.type, 'Original');
    });
  });

  group('buildQrPayload', () {
    test('builds sale info without a fiscal hash', () {
      final payload = buildQrPayload(
        businessName: 'Jolinx Shop',
        saleNumber: 'S-2026-000001',
        totalAmount: 100.0,
        saleDate: DateTime(2026, 9, 7),
        fiscalHash: null,
      );
      expect(payload, isNotNull);
      expect(payload, contains('Jolinx Shop'));
      expect(payload, contains('RISITI: S-2026-000001'));
      expect(payload, isNot(contains('THIBITISHO')));
    });

    test('builds sale info with an empty fiscal hash', () {
      final payload = buildQrPayload(
        businessName: 'Jolinx Shop',
        saleNumber: 'S-2026-000001',
        totalAmount: 100.0,
        saleDate: DateTime(2026, 9, 7),
        fiscalHash: '',
      );
      expect(payload, isNotNull);
      expect(payload, contains('S-2026-000001'));
      expect(payload, isNot(contains('THIBITISHO')));
    });

    test('generates text payload with all fields', () {
      final payload = buildQrPayload(
        businessName: 'Jolinx Shop',
        saleNumber: 'S-2026-000001',
        totalAmount: 100.0,
        saleDate: DateTime(2026, 9, 7),
        fiscalHash: 'a1b2c3d4e5f6',
      );
      expect(payload, contains('Jolinx Shop'));
      expect(payload, contains('RISITI: S-2026-000001'));
      expect(payload, contains('TZS'));
      expect(payload, contains('07/09/2026'));
      expect(payload, contains('a1b2c3d4'));
    });

    test('carries the sale currency into the QR total', () {
      final payload = buildQrPayload(
        businessName: 'Jolinx Shop',
        saleNumber: 'S-2026-000001',
        totalAmount: 8720.0,
        saleDate: DateTime(2026, 9, 7),
        currency: 'KES',
      );
      expect(payload, contains('JUMLA: KES 8,720'));
      expect(payload, isNot(contains('TSh')));
    });

    test('truncates long fiscal hash to 8 chars', () {
      final payload = buildQrPayload(
        businessName: 'Jolinx Shop',
        saleNumber: 'S-2026-000001',
        totalAmount: 100.0,
        saleDate: DateTime(2026, 9, 7),
        fiscalHash: 'a1b2c3d4e5f6g7h8i9j0',
      );
      expect(payload, contains('a1b2c3d4'));
      expect(payload, isNot(contains('a1b2c3d4e5f6g7h8i9j0')));
    });

    test('buildQrPayloadFromReceipt matches the receipt currency', () {
      final payload = buildQrPayloadFromReceipt(
        _createTestReceipt(currency: 'TZS', fiscalHash: 'a1b2c3d4'),
      );
      expect(payload, contains('JUMLA: TZS 21'));
      expect(payload, contains('a1b2c3d4'));
    });
  });
}

ReceiptPreview _createTestReceipt({
  bool isReprint = false,
  int printCount = 0,
  String? fiscalHash,
  String qrPayload = '',
  String currency = 'TZS',
  String? branchName = 'Downtown Branch',
  String? cashierName = 'John Doe',
  String? customerName = 'Walk-in Customer',
  String? email = 'info@jolinx.co.tz',
  double subtotal = 20.0,
  double discountAmount = 1.0,
  double taxAmount = 1.9,
  double totalAmount = 20.9,
  double amountPaid = 70.9,
  double change = 50.0,
  List<ReceiptLine>? lines,
  List<ReceiptPayment>? payments,
}) {
  return ReceiptPreview(
    saleId: 'test-sale-id',
    saleNumber: 'S-2026-000001',
    saleDate: DateTime(2026, 9, 7, 10, 30, 0),
    subtotal: subtotal,
    taxAmount: taxAmount,
    totalAmount: totalAmount,
    discountAmount: discountAmount,
    amountPaid: amountPaid,
    change: change,
    printCount: printCount,
    isReprint: isReprint,
    isVoided: false,
    hasMetadata: true,
    businessName: 'Jolinx Shop',
    tin: '123456789',
    address: 'Dar es Salaam',
    phone: '+255712345678',
    email: email,
    branchName: branchName,
    cashierName: cashierName,
    customerName: customerName,
    currency: currency,
    fiscalHash: fiscalHash,
    qrPayload: qrPayload,
    lines: lines ??
        [
          ReceiptLine(
            productName: 'Paracetamol 500mg',
            quantity: 4,
            unitPrice: 2.50,
            discountAmount: 0,
            taxCode: 'A',
            taxAmount: 0,
            lineTotal: 10.00,
          ),
          ReceiptLine(
            productName: 'Vitamin C 1000mg',
            quantity: 2,
            unitPrice: 5.00,
            discountAmount: 0,
            taxCode: 'A',
            taxAmount: 0,
            lineTotal: 10.00,
          ),
        ],
    payments: payments ??
        [
          ReceiptPayment(
            method: 'Card',
            amount: amountPaid,
            reference: 'TXN-56587451236',
          ),
        ],
  );
}
