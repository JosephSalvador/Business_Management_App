import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/features/invoices/domain/invoice.dart';
import 'package:jolinx_app/features/invoices/presentation/services/customer_invoice_pdf_service.dart';
import 'package:jolinx_app/features/settings/data/organization_repository.dart';

void main() {
  group('Universal CustomerInvoice Domain & A4 PDF Generator', () {
    test('serializes and deserializes all 7 universal invoice elements', () {
      final now = DateTime.utc(2026, 10, 29, 8, 0);
      final due = DateTime.utc(2026, 11, 12, 8, 0);
      final original = CustomerInvoice(
        id: 'inv-100',
        invoiceNumber: 'INV-20261029-001',
        documentTitle: 'TAX INVOICE',
        referenceNumber: 'PO-9988',
        paymentTerms: 'Net 14',
        customerId: 'cust-1',
        customerName: 'Kilimanjaro Logistics Ltd',
        customerAttention: 'Procurement Manager',
        customerPhone: '+255712000111',
        customerEmail: 'accounts@kililogistics.co.tz',
        customerAddress: 'Plot 42, Nyerere Road, Dar es Salaam',
        customerTin: '123-456-789',
        issueDate: now,
        dueDate: due,
        status: InvoiceStatus.partiallyPaid,
        subtotal: 1500000,
        discountAmount: 50000,
        taxAmount: 0,
        totalAmount: 1450000,
        amountPaid: 500000,
        balanceDue: 950000,
        notes: 'Goods remain property of seller until paid in full.',
        paymentInstructions: 'CRDB Bank • Acc: 0150123456700',
        authorizedSignatoryName: 'Jobert Salvador',
        authorizedSignatoryTitle: 'Managing Director',
        lines: const [
          CustomerInvoiceLine(
            id: 'line-1',
            productId: 'prod-1',
            description: 'Heavy Duty Tarpaulin 10x12m',
            unitOfMeasure: 'Pcs',
            quantity: 5,
            unitPrice: 300000,
            discountAmount: 0,
            taxRate: 0,
            taxAmount: 0,
            lineTotal: 1500000,
          ),
        ],
        payments: [
          CustomerInvoicePayment(
            id: 'pay-1',
            amount: 500000,
            paymentMethod: 'Bank Transfer',
            reference: 'CRDB-TX-8821',
            paidAt: now,
          ),
        ],
      );

      final json = original.toJson();
      final restored = CustomerInvoice.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.documentTitle, 'TAX INVOICE');
      expect(restored.referenceNumber, 'PO-9988');
      expect(restored.paymentTerms, 'Net 14');
      expect(restored.customerName, 'Kilimanjaro Logistics Ltd');
      expect(restored.customerAttention, 'Procurement Manager');
      expect(restored.customerTin, '123-456-789');
      expect(restored.customerPhone, '+255712000111');
      expect(restored.customerEmail, 'accounts@kililogistics.co.tz');
      expect(restored.customerAddress, 'Plot 42, Nyerere Road, Dar es Salaam');
      expect(restored.discountAmount, 50000);
      expect(restored.totalAmount, 1450000);
      expect(restored.amountPaid, 500000);
      expect(restored.balanceDue, 950000);
      expect(restored.paymentInstructions, 'CRDB Bank • Acc: 0150123456700');
      expect(restored.authorizedSignatoryName, 'Jobert Salvador');
      expect(restored.authorizedSignatoryTitle, 'Managing Director');
      expect(restored.lines.single.unitOfMeasure, 'Pcs');
    });

    test('generates a valid A4 PDF byte stream with seller branding and items',
        () async {
      final service = CustomerInvoicePdfService();
      const org = Organization(
        id: 'org-1',
        name: 'Jolinx Hardware & Supplies Ltd',
        taxId: '109-887-221',
        address: 'Kariakoo, Msimbazi Street, Dar es Salaam',
        phone: '+255 754 111 222',
        email: 'sales@jolinx.co.tz',
        currency: 'TZS',
        bankName: 'CRDB Bank PLC',
        bankAccountName: 'Jolinx Hardware & Supplies Ltd',
        bankAccountNumber: '0150998877660',
        bankBranchOrSwift: 'Azikiwe Branch / CORUTZTZ',
        mobileMoneyDetails: 'M-Pesa Lipa Namba: 5566778',
        invoiceTerms: 'Payment due within 14 days of issue.',
        authorizedSignatoryName: 'Joseph Salvador',
        authorizedSignatoryTitle: 'Finance Director',
      );

      final invoice = CustomerInvoice(
        id: 'inv-200',
        invoiceNumber: 'INV-20261029-002',
        documentTitle: 'INVOICE',
        referenceNumber: 'LPO-4410',
        paymentTerms: 'Net 14',
        customerName: 'Mlimani Construction Co.',
        customerAttention: 'Eng.David M.',
        customerTin: '144-552-990',
        customerPhone: '+255 784 999 000',
        customerAddress: 'Mikocheni Industrial Area',
        issueDate: DateTime.utc(2026, 10, 29),
        dueDate: DateTime.utc(2026, 11, 12),
        status: InvoiceStatus.unpaid,
        subtotal: 2400000,
        discountAmount: 100000,
        taxAmount: 0,
        totalAmount: 2300000,
        amountPaid: 0,
        balanceDue: 2300000,
        lines: const [
          CustomerInvoiceLine(
            id: 'l-1',
            description: 'Portland Cement 50kg (Twiga)',
            unitOfMeasure: 'Bags',
            quantity: 100,
            unitPrice: 20000,
            discountAmount: 0,
            taxRate: 0,
            taxAmount: 0,
            lineTotal: 2000000,
          ),
          CustomerInvoiceLine(
            id: 'l-2',
            description: 'Site Delivery & Offloading',
            unitOfMeasure: 'Trips',
            quantity: 1,
            unitPrice: 400000,
            discountAmount: 0,
            taxRate: 0,
            taxAmount: 0,
            lineTotal: 400000,
          ),
        ],
      );

      final pdfBytes = await service.buildA4Pdf(
        invoice: invoice,
        organization: org,
      );

      expect(pdfBytes, isNotEmpty);
      // PDF magic header "%PDF-"
      expect(String.fromCharCodes(pdfBytes.take(5)), '%PDF-');
    });
  });
}
