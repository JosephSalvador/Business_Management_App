import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/features/receipts/domain/receipt_preview.dart';
import 'package:jolinx_app/features/receipts/domain/receipt_renderer.dart';
import 'package:jolinx_app/features/receipts/presentation/widgets/receipt_ticket_card.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  Future<void> pumpCard(WidgetTester tester, ReceiptPreview receipt) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReceiptTicketCard(receipt: receipt),
          ),
        ),
      ),
    );
  }

  group('ReceiptTicketCard', () {
    testWidgets('renders the business header, meta block and item table',
        (tester) async {
      await pumpCard(tester, _createTestReceipt());

      expect(find.text('Jolinx Shop'), findsOneWidget);
      expect(find.text('Downtown Branch'), findsOneWidget);
      expect(find.text('Dar es Salaam'), findsOneWidget);
      expect(find.text('Phone: +255712345678'), findsOneWidget);
      expect(find.text('Email: info@jolinx.co.tz'), findsOneWidget);
      expect(find.text('Tax No: 123456789'), findsOneWidget);

      expect(find.text('Receipt No.'), findsOneWidget);
      // meta row + QR caption
      expect(find.text('S-2026-000001'), findsNWidgets(2));
      expect(find.text('Cashier'), findsOneWidget);
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('Walk-in Customer'), findsOneWidget);

      expect(find.text('Item'), findsOneWidget);
      expect(find.text('Qty'), findsOneWidget);
      expect(find.text('Price'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Paracetamol 500mg'), findsOneWidget);
      // unit price and line total of the first row
      expect(find.text('2.50'), findsOneWidget);
      expect(find.text('10.00'), findsNWidgets(2));
    });

    testWidgets('renders totals, payment block and transaction id',
        (tester) async {
      await pumpCard(tester, _createTestReceipt());

      expect(find.text('Subtotal'), findsOneWidget);
      expect(find.text('Discount (5%)'), findsOneWidget);
      expect(find.textContaining('VAT'), findsNothing);

      expect(find.text('GRAND TOTAL'), findsOneWidget);
      expect(find.text('TZS 20.90'), findsOneWidget);

      expect(find.text('Paid Amount'), findsOneWidget);
      expect(find.text('Payment Method'), findsOneWidget);
      expect(find.text('Card'), findsOneWidget);
      expect(find.text('Transaction ID'), findsOneWidget);
      expect(find.text('TXN-56587451236'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
    });

    testWidgets('renders the policy footer and the QR block', (tester) async {
      await pumpCard(tester, _createTestReceipt());

      expect(find.text('Thank you for shopping with us!'), findsOneWidget);
      expect(
          find.text('Goods once sold will not be taken back.'), findsOneWidget);
      expect(find.text('Jolinx ERP'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
    });

    testWidgets('omits the QR block when the payload is empty', (tester) async {
      await pumpCard(tester, _createTestReceipt(qrPayload: ''));

      expect(find.byType(QrImageView), findsNothing);
    });

    testWidgets('shows the reprint watermark when asked', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReceiptTicketCard(
                receipt: _createTestReceipt(),
                isReprint: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('*** REPRINT ***'), findsOneWidget);
    });

    testWidgets('renders Swahili labels for the sw locale language',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReceiptTicketCard(
                receipt: _createTestReceipt(),
                language: ReceiptLanguage.swahili,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Risiti Na.'), findsOneWidget);
      expect(find.text('Jumla ndogo'), findsOneWidget);
      expect(find.text('Thibitisho: abc123hash'), findsOneWidget);
    });
  });
}

ReceiptPreview _createTestReceipt({String qrPayload = 'Test QR payload'}) {
  return ReceiptPreview(
    saleId: 'test-sale-id',
    saleNumber: 'S-2026-000001',
    saleDate: DateTime(2026, 9, 7, 10, 30, 0),
    subtotal: 20.0,
    taxAmount: 1.9,
    totalAmount: 20.9,
    discountAmount: 1.0,
    amountPaid: 70.9,
    change: 50.0,
    printCount: 0,
    isReprint: false,
    isVoided: false,
    hasMetadata: true,
    businessName: 'Jolinx Shop',
    tin: '123456789',
    address: 'Dar es Salaam',
    phone: '+255712345678',
    email: 'info@jolinx.co.tz',
    branchName: 'Downtown Branch',
    cashierName: 'John Doe',
    customerName: 'Walk-in Customer',
    currency: 'TZS',
    fiscalHash: 'abc123hash',
    qrPayload: qrPayload,
    lines: const [
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
    payments: const [
      ReceiptPayment(
        method: 'Card',
        amount: 70.9,
        reference: 'TXN-56587451236',
      ),
    ],
  );
}
