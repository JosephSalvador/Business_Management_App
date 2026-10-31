import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/features/invoices/domain/delivery_note.dart';
import 'package:jolinx_app/features/invoices/domain/invoice.dart';
import 'package:jolinx_app/features/invoices/presentation/services/local_pdf_document_generator.dart';
import 'package:jolinx_app/features/settings/data/organization_repository.dart';

void main() {
  group('Offline Invoice Domain Model', () {
    test('defaults isSynced to true from server json and false when offline created', () {
      final serverJson = {
        'id': 'inv-123',
        'number': 'CINV-2026-0001',
        'customerId': 'cust-1',
        'customerName': 'Azam Bakeries Ltd',
        'currency': 'TZS',
        'issueDate': '2026-10-31T10:00:00.000Z',
        'status': 0,
        'subtotal': 150000.0,
        'taxAmount': 27000.0,
        'totalAmount': 177000.0,
        'amountPaid': 0.0,
        'balanceDue': 177000.0,
        'lines': [
          {
            'id': 'line-1',
            'description': 'Wheat Flour 50kg',
            'quantity': 2.0,
            'unitPrice': 75000.0,
            'taxRatePercent': 18.0,
            'lineTotal': 150000.0,
            'taxAmount': 27000.0,
          }
        ],
      };

      final serverInvoice = CustomerInvoice.fromJson(serverJson);
      expect(serverInvoice.isSynced, isTrue);

      final offlineInvoice = serverInvoice.copyWith(isSynced: false);
      expect(offlineInvoice.isSynced, isFalse);

      final summary = offlineInvoice.toSummary();
      expect(summary.isSynced, isFalse);
      expect(summary.totalAmount, 177000.0);

      final summaryJson = summary.toJson();
      expect(summaryJson['isSynced'], isFalse);

      final restoredSummary = CustomerInvoiceSummary.fromJson(summaryJson);
      expect(restoredSummary.isSynced, isFalse);
    });
  });

  group('Offline Delivery Note Domain Model', () {
    test('parses DeliveryNoteStatus and calculates totalQuantity accurately', () {
      expect(DeliveryNoteStatus.fromCode(0), DeliveryNoteStatus.draft);
      expect(DeliveryNoteStatus.fromCode(1), DeliveryNoteStatus.dispatched);
      expect(DeliveryNoteStatus.fromCode(2), DeliveryNoteStatus.delivered);
      expect(DeliveryNoteStatus.fromCode(3), DeliveryNoteStatus.cancelled);

      final note = DeliveryNote(
        id: 'dn-001',
        number: 'DN-2026-000001',
        customerName: 'Bakhresa Group',
        issueDate: DateTime(2026, 10, 31),
        status: DeliveryNoteStatus.dispatched,
        isSynced: false,
        items: const [
          DeliveryNoteItem(
            id: 'item-1',
            productName: 'Sunflower Oil 20L',
            quantityToDeliver: 10,
            unitOfMeasure: 'Jerrycan',
          ),
          DeliveryNoteItem(
            id: 'item-2',
            productName: 'Sugar 50kg',
            quantityToDeliver: 5,
            unitOfMeasure: 'Bag',
          ),
        ],
      );

      expect(note.totalQuantity, 15.0);
      expect(note.isSynced, isFalse);

      final summary = note.toSummary();
      expect(summary.isSynced, isFalse);
      expect(summary.itemCount, 2);
      expect(summary.totalQuantity, 15.0);

      final json = note.toJson();
      expect(json['isSynced'], isFalse);
      expect(json['status'], 1);

      final restored = DeliveryNote.fromJson(json);
      expect(restored.number, 'DN-2026-000001');
      expect(restored.items.length, 2);
      expect(restored.isSynced, isFalse);
    });
  });

  group('On-Device Native PDF Layout Compiler (LocalPdfDocumentGenerator)', () {
    late LocalPdfDocumentGenerator generator;
    late CustomerInvoice sampleInvoice;
    late DeliveryNote sampleDeliveryNote;
    late Organization sampleOrg;

    setUp(() {
      generator = LocalPdfDocumentGenerator();
      sampleOrg = const Organization(
        id: 'org-1',
        name: 'Dar es Salaam Enterprises',
        address: 'Kariakoo, Livingstone St, Plot 42',
        phone: '+255 754 112 233',
        currency: 'TZS',
        taxId: '100-200-300',
      );

      sampleInvoice = CustomerInvoice(
        id: 'inv-test',
        number: 'CINV-2026-9999',
        customerId: 'cust-1',
        customerName: 'Kilimanjaro Traders',
        customerPhone: '+255 655 443 322',
        customerAddress: 'Arusha Road, Moshi',
        customerTin: '999-888-777',
        currency: 'TZS',
        issueDate: DateTime(2026, 10, 31, 14, 30),
        dueDate: DateTime(2026, 11, 15),
        status: InvoiceStatus.unpaid,
        subtotal: 500000.0,
        discountAmount: 25000.0,
        taxAmount: 85500.0,
        totalAmount: 560500.0,
        amountPaid: 0.0,
        balanceDue: 560500.0,
        paymentMethod: 'Bank Transfer',
        paymentReference: null,
        paidAtUtc: null,
        notes: 'Strict payment deadline within 14 days.',
        paymentInstructions: 'NMB Bank, A/C: 20110022334, Branch: Clocktower',
        lines: const [
          InvoiceLine(
            id: 'line-1',
            description: 'Portland Cement 50kg Bags',
            quantity: 20,
            unitPrice: 20000.0,
            taxRatePercent: 18.0,
            lineTotal: 400000.0,
            taxAmount: 72000.0,
            unitOfMeasure: 'Bags',
          ),
          InvoiceLine(
            id: 'line-2',
            description: 'Steel Rebar 12mm x 12m',
            quantity: 5,
            unitPrice: 20000.0,
            taxRatePercent: 18.0,
            lineTotal: 100000.0,
            taxAmount: 13500.0,
            unitOfMeasure: 'Pcs',
          ),
        ],
        isSynced: false,
      );

      sampleDeliveryNote = DeliveryNote(
        id: 'dn-test',
        number: 'DN-2026-8888',
        customerName: 'Kilimanjaro Traders',
        customerPhone: '+255 655 443 322',
        customerAddress: 'Arusha Road, Moshi',
        deliveryAddress: 'Construction Site B, Moshi Urban',
        carrierName: 'FastLogistics Express',
        vehicleNumber: 'T 421 DKL',
        driverName: 'Juma Hassan',
        driverPhone: '+255 712 998 877',
        issueDate: DateTime(2026, 10, 31, 15, 00),
        status: DeliveryNoteStatus.dispatched,
        notes: 'Handle with care. Offload at Site B warehouse.',
        items: const [
          DeliveryNoteItem(
            id: 'dn-item-1',
            productName: 'Portland Cement 50kg Bags',
            quantityOrdered: 20,
            quantityToDeliver: 20,
            unitOfMeasure: 'Bags',
          ),
          DeliveryNoteItem(
            id: 'dn-item-2',
            productName: 'Steel Rebar 12mm x 12m',
            quantityOrdered: 5,
            quantityToDeliver: 5,
            unitOfMeasure: 'Pcs',
          ),
        ],
        isSynced: false,
      );
    });

    test('generates A4 corporate standard PDF bytes for invoice on-device', () async {
      final Uint8List bytes = await generator.generateInvoiceA4(
        invoice: sampleInvoice,
        organization: sampleOrg,
        primaryHex: '#0F172A',
        secondaryHex: '#0D9488',
        isSwahili: true,
      );

      expect(bytes, isNotEmpty);
      // Valid PDF files start with %PDF- (0x25, 0x50, 0x44, 0x46, 0x2D)
      expect(bytes[0], 0x25);
      expect(bytes[1], 0x50);
      expect(bytes[2], 0x44);
      expect(bytes[3], 0x46);
    });

    test('generates 80mm continuous thermal roll PDF bytes for invoice on-device', () async {
      final Uint8List bytes = await generator.generateInvoiceThermal80mm(
        invoice: sampleInvoice,
        organization: sampleOrg,
        isSwahili: false,
      );

      expect(bytes, isNotEmpty);
      expect(bytes[0], 0x25);
      expect(bytes[1], 0x50);
      expect(bytes[2], 0x44);
      expect(bytes[3], 0x46);
    });

    test('generates A4 corporate standard PDF bytes for delivery note on-device', () async {
      final Uint8List bytes = await generator.generateDeliveryNoteA4(
        note: sampleDeliveryNote,
        organization: sampleOrg,
        primaryHex: '#0F172A',
        secondaryHex: '#0D9488',
        isSwahili: false,
      );

      expect(bytes, isNotEmpty);
      expect(bytes[0], 0x25);
      expect(bytes[1], 0x50);
      expect(bytes[2], 0x44);
      expect(bytes[3], 0x46);
    });

    test('generates 80mm continuous thermal roll PDF bytes for delivery note on-device', () async {
      final Uint8List bytes = await generator.generateDeliveryNoteThermal80mm(
        note: sampleDeliveryNote,
        organization: sampleOrg,
        isSwahili: true,
      );

      expect(bytes, isNotEmpty);
      expect(bytes[0], 0x25);
      expect(bytes[1], 0x50);
      expect(bytes[2], 0x44);
      expect(bytes[3], 0x46);
    });
  });
}
