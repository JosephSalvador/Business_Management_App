import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/features/invoices/domain/delivery_note.dart';
import 'package:jolinx_app/features/invoices/domain/document_template.dart';
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

  group('Multiple Payment Accounts & Split Invoice Payments', () {
    test('PaymentAccount round-trip serialization and legacy synthesis in Organization', () {
      final accounts = [
        const PaymentAccount(
          id: 'acc-1',
          type: PaymentAccountType.bank,
          providerName: 'CRDB Bank',
          accountName: 'Dar Enterprises TZS',
          accountNumber: '01502233445500',
          branchOrSwift: 'Tower Branch / CORUTZTZ',
          currency: 'TZS',
          isDefault: true,
        ),
        const PaymentAccount(
          id: 'acc-2',
          type: PaymentAccountType.mobileMoney,
          providerName: 'M-Pesa (Vodacom)',
          accountName: 'Dar Enterprises Lipa',
          accountNumber: '556677',
          isDefault: false,
        ),
      ];

      final org = Organization(
        name: 'Dar Enterprises',
        paymentAccounts: accounts,
      );

      final orgJson = org.toJson();
      expect(orgJson['paymentAccounts'], isList);
      expect((orgJson['paymentAccounts'] as List).length, 2);

      final restoredOrg = Organization.fromJson(orgJson);
      expect(restoredOrg.paymentAccounts.length, 2);
      expect(restoredOrg.paymentAccounts[0].providerName, 'CRDB Bank');
      expect(restoredOrg.paymentAccounts[0].isBank, isTrue);
      expect(restoredOrg.paymentAccounts[1].providerName, 'M-Pesa (Vodacom)');
      expect(restoredOrg.paymentAccounts[1].isMobileMoney, isTrue);
      expect(restoredOrg.formattedPaymentInstructions, contains('CRDB Bank'));
      expect(restoredOrg.formattedPaymentInstructions, contains('M-Pesa (Vodacom)'));

      // Test legacy single fields synthesis when paymentAccounts is empty
      final legacyOrgJson = {
        'name': 'Legacy Business',
        'bankName': 'NMB Bank',
        'bankAccountName': 'Legacy Acc',
        'bankAccountNumber': '12345678',
        'mobileMoneyDetails': 'M-Pesa Till: 998877',
      };
      final synthesizedOrg = Organization.fromJson(legacyOrgJson);
      expect(synthesizedOrg.paymentAccounts.length, 2);
      expect(synthesizedOrg.paymentAccounts.any((a) => a.providerName == 'NMB Bank'), isTrue);
      expect(synthesizedOrg.paymentAccounts.any((a) => a.accountNumber.contains('998877')), isTrue);
    });

    test('CustomerInvoicePayment serialization and invoice payment history tracking', () {
      final payment1 = CustomerInvoicePayment(
        id: 'pmt-1',
        amount: 200000.0,
        method: 'Bank Transfer',
        reference: 'CRDB-TX-998811',
        paidAtUtc: DateTime.utc(2026, 11, 1, 10, 0),
      );
      final payment2 = CustomerInvoicePayment(
        id: 'pmt-2',
        amount: 150000.0,
        method: 'M-Pesa',
        reference: 'MPESA-QK8829',
        paidAtUtc: DateTime.utc(2026, 11, 2, 14, 30),
      );

      final pmtJson = payment1.toJson();
      final restoredPayment = CustomerInvoicePayment.fromJson(pmtJson);
      expect(restoredPayment.id, 'pmt-1');
      expect(restoredPayment.amount, 200000.0);
      expect(restoredPayment.method, 'Bank Transfer');
      expect(restoredPayment.reference, 'CRDB-TX-998811');

      final invoiceJson = {
        'id': 'inv-split',
        'number': 'CINV-2026-7777',
        'customerName': 'Split Payer Ltd',
        'currency': 'TZS',
        'issueDate': '2026-11-01T08:00:00.000Z',
        'status': 1,
        'subtotal': 500000.0,
        'totalAmount': 500000.0,
        'amountPaid': 350000.0,
        'balanceDue': 150000.0,
        'payments': [payment1.toJson(), payment2.toJson()],
        'lines': [
          {
            'id': 'line-1',
            'description': 'Product A',
            'quantity': 10.0,
            'unitPrice': 50000.0,
            'lineTotal': 500000.0,
          }
        ],
      };

      final invoice = CustomerInvoice.fromJson(invoiceJson);
      expect(invoice.payments.length, 2);
      expect(invoice.payments[0].amount, 200000.0);
      expect(invoice.payments[1].amount, 150000.0);
      expect(invoice.amountPaid, 350000.0);

      // Verify legacy invoice with amountPaid > 0 but empty payments synthesizes payment
      final legacyInvoiceJson = {
        'id': 'inv-legacy',
        'number': 'CINV-2026-8888',
        'customerName': 'Legacy Payer',
        'currency': 'TZS',
        'issueDate': '2026-11-01T08:00:00.000Z',
        'paidAtUtc': '2026-11-01T09:00:00.000Z',
        'paymentMethod': 'Cash',
        'paymentReference': 'REC-001',
        'status': 1,
        'subtotal': 100000.0,
        'totalAmount': 100000.0,
        'amountPaid': 50000.0,
        'balanceDue': 50000.0,
        'lines': [],
      };
      final legacyInvoice = CustomerInvoice.fromJson(legacyInvoiceJson);
      expect(legacyInvoice.payments.length, 1);
      expect(legacyInvoice.payments.first.amount, 50000.0);
      expect(legacyInvoice.payments.first.method, 'Cash');
      expect(legacyInvoice.payments.first.reference, 'REC-001');
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

    test('generates A4 PDF bytes across all 4 InvoiceLayoutStyle archetypes (modernRibbon, executiveCorporate, classicGrid, customLetterhead)', () async {
      for (final style in InvoiceLayoutStyle.values) {
        final cfg = TenantDocumentConfiguration(
          documentType: DocumentType.invoice,
          activeTemplateId: style.templateId,
          activeTemplateName: style.titleEn,
          themePrimaryHex: style.defaultPrimaryHex,
          themeSecondaryHex: style.defaultSecondaryHex,
          showLogo: true,
          footerNotes: 'Custom template footer note for ${style.name}',
        );
        final orgWithBranding = Organization(
          name: sampleOrg.name,
          address: sampleOrg.address,
          phone: sampleOrg.phone,
          currency: sampleOrg.currency,
          taxId: sampleOrg.taxId,
          website: 'www.darent.co.tz',
          hideHeaderForPrePrinted: style == InvoiceLayoutStyle.customLetterhead,
          prePrintedTopMarginMm: 50.0,
        );
        final Uint8List bytes = await generator.generateInvoiceA4(
          invoice: sampleInvoice,
          organization: orgWithBranding,
          templateConfig: cfg,
          isSwahili: false,
        );

        expect(bytes, isNotEmpty, reason: 'Failed for layout style ${style.name}');
        expect(bytes[0], 0x25);
        expect(bytes[1], 0x50);
        expect(bytes[2], 0x44);
        expect(bytes[3], 0x46);
      }
    });

    test('generates A4 and 80mm thermal receipts with multiple payment accounts and payments list', () async {
      final multiPayInvoice = sampleInvoice.copyWith(
        amountPaid: 350000.0,
        balanceDue: 210500.0,
        status: InvoiceStatus.partiallyPaid,
        payments: [
          CustomerInvoicePayment(
            id: 'p1',
            amount: 200000.0,
            method: 'CRDB Bank',
            reference: 'CRDB-TX-101',
            paidAtUtc: DateTime.utc(2026, 11, 1, 10, 0),
          ),
          CustomerInvoicePayment(
            id: 'p2',
            amount: 150000.0,
            method: 'M-Pesa',
            reference: 'MPESA-REF-202',
            paidAtUtc: DateTime.utc(2026, 11, 2, 11, 30),
          ),
        ],
      );

      final multiAccountOrg = sampleOrg.copyWith(
        paymentAccounts: const [
          PaymentAccount(
            id: 'acc-1',
            type: PaymentAccountType.bank,
            providerName: 'CRDB Bank',
            accountName: 'Dar Enterprises TZS',
            accountNumber: '01502233445500',
            currency: 'TZS',
            isDefault: true,
          ),
          PaymentAccount(
            id: 'acc-2',
            type: PaymentAccountType.mobileMoney,
            providerName: 'M-Pesa',
            accountNumber: '556677',
            isDefault: false,
          ),
        ],
      );

      final a4Bytes = await generator.generateInvoiceA4(
        invoice: multiPayInvoice,
        organization: multiAccountOrg,
        isSwahili: true,
      );
      expect(a4Bytes, isNotEmpty);
      expect(a4Bytes[0], 0x25); // %PDF-

      final thermalBytes = await generator.generateInvoiceThermal80mm(
        invoice: multiPayInvoice,
        organization: multiAccountOrg,
        isSwahili: true,
      );
      expect(thermalBytes, isNotEmpty);
      expect(thermalBytes[0], 0x25); // %PDF-
    });

    test('generates Delivery Note A4 with official organization branding and items list', () async {
      final note = DeliveryNote(
        id: 'dn-001',
        number: 'DN-202611-0001',
        customerName: 'Azam Bakeries Ltd',
        customerPhone: '+255 754 112 233',
        customerAddress: 'Kariakoo Market, St. 4',
        deliveryAddress: 'Warehouse B, Nyerere Rd',
        driverName: 'John Mwita',
        vehicleNumber: 'T 123 ABC',
        issueDate: DateTime.utc(2026, 11, 19, 10, 0),
        status: DeliveryNoteStatus.dispatched,
        notes: 'Handle with care',
        items: const [
          DeliveryNoteItem(
            id: 'item-1',
            productName: 'Wheat Flour 50kg',
            quantityOrdered: 5.0,
            quantityToDeliver: 3.0,
            unitOfMeasure: 'Bags',
          ),
          DeliveryNoteItem(
            id: 'item-2',
            productName: 'Refined Sugar 25kg',
            quantityOrdered: 2.0,
            quantityToDeliver: 2.0,
            unitOfMeasure: 'Bags',
          ),
        ],
      );

      final dnA4Bytes = await generator.generateDeliveryNoteA4(
        note: note,
        organization: sampleOrg,
        isSwahili: true,
      );
      expect(dnA4Bytes, isNotEmpty);
      expect(dnA4Bytes[0], 0x25); // %PDF-
      expect(dnA4Bytes[1], 0x50);
      expect(dnA4Bytes[2], 0x44);
      expect(dnA4Bytes[3], 0x46);

      final dnThermalBytes = await generator.generateDeliveryNoteThermal80mm(
        note: note,
        organization: sampleOrg,
        isSwahili: true,
      );
      expect(dnThermalBytes, isNotEmpty);
      expect(dnThermalBytes[0], 0x25);
    });
  });

  group('Configurable Invoice Prefix & Retroactive Past Invoices Display', () {
    test('displayNumber formats past invoices dynamically based on merchant prefix', () {
      final pastInvoice = CustomerInvoice(
        id: 'inv-past-1',
        number: 'CINV-2026-000042',
        issueDate: DateTime.utc(2026, 11, 1),
        status: InvoiceStatus.paid,
        subtotal: 50000,
        totalAmount: 50000,
      );

      // When no prefix configured, returns original CINV number
      expect(pastInvoice.displayNumber(null), 'CINV-2026-000042');
      expect(pastInvoice.displayNumber(''), 'CINV-2026-000042');

      // Standard INV prefix replaces CINV
      expect(pastInvoice.displayNumber('INV'), 'INV-2026-000042');

      // Custom business initial prefix replaces CINV retroactively
      expect(pastInvoice.displayNumber('ABC'), 'ABC-2026-000042');
      expect(pastInvoice.displayNumber('KTL'), 'KTL-2026-000042');
      expect(pastInvoice.displayNumber('ktl'), 'KTL-2026-000042');

      // Works identically on summary model
      final summary = pastInvoice.toSummary();
      expect(summary.displayNumber('INV'), 'INV-2026-000042');
      expect(summary.displayNumber('ABC'), 'ABC-2026-000042');

      // Works if original number started with INV-
      final invInvoice = pastInvoice.copyWith(number: 'INV-202611-0005');
      expect(invInvoice.displayNumber('KTL'), 'KTL-202611-0005');
      expect(invInvoice.displayNumber('CINV'), 'CINV-202611-0005');
    });

    test('Organization serializes and deserializes invoicePrefix correctly', () {
      const defaultOrg = Organization(name: 'Default Org');
      expect(defaultOrg.invoicePrefix, isNull);
      expect(defaultOrg.effectiveInvoicePrefix, 'INV');

      const customOrg = Organization(
        name: 'Custom Prefix Org',
        invoicePrefix: 'KTL',
      );
      expect(customOrg.invoicePrefix, 'KTL');
      expect(customOrg.effectiveInvoicePrefix, 'KTL');

      final json = customOrg.toJson();
      expect(json['invoicePrefix'], 'KTL');

      final restored = Organization.fromJson(json);
      expect(restored.invoicePrefix, 'KTL');
      expect(restored.effectiveInvoicePrefix, 'KTL');

      final updated = restored.copyWith(invoicePrefix: 'BIZ');
      expect(updated.invoicePrefix, 'BIZ');
      expect(updated.effectiveInvoicePrefix, 'BIZ');
    });

    test('LocalPdfDocumentGenerator renders with custom invoicePrefix in A4 and 80mm', () async {
      final generator = LocalPdfDocumentGenerator();
      final invoice = CustomerInvoice(
        id: 'inv-pdf-1',
        number: 'CINV-2026-000099',
        issueDate: DateTime.utc(2026, 11, 19, 12, 0),
        status: InvoiceStatus.unpaid,
        subtotal: 100000,
        totalAmount: 100000,
        customerName: 'Mega Wholesaler Ltd',
        lines: const [
          InvoiceLine(
            id: 'line-1',
            description: 'Printing Paper A4 Ream',
            quantity: 10,
            unitPrice: 10000,
            lineTotal: 100000,
            taxAmount: 0,
          ),
        ],
      );

      const customOrg = Organization(
        name: 'Kilimanjaro Traders',
        invoicePrefix: 'KTL',
      );

      final a4Bytes = await generator.generateInvoiceA4(
        invoice: invoice,
        organization: customOrg,
        isSwahili: true,
      );
      expect(a4Bytes, isNotEmpty);
      expect(a4Bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]); // %PDF

      final thermalBytes = await generator.generateInvoiceThermal80mm(
        invoice: invoice,
        organization: customOrg,
        isSwahili: false,
      );
      expect(thermalBytes, isNotEmpty);
      expect(thermalBytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
    });

    test('DeliveryNoteSummary and DeliveryNote round-trip serialization with vehicle and invoiceId', () {
      final note = DeliveryNote(
        id: 'dn-uuid-999',
        number: 'DN-202611-0099',
        customerName: 'Tanzania Breweries Ltd',
        status: DeliveryNoteStatus.dispatched,
        issueDate: DateTime.utc(2026, 11, 19, 10, 0),
        invoiceId: 'inv-uuid-123',
        vehicleNumber: 'T 123 ABC',
        carrierName: 'FastHaul Logistics',
        items: const [
          DeliveryNoteItem(
            id: 'item-1',
            productName: 'Barley Malt 25kg',
            quantityOrdered: 50,
            quantityToDeliver: 50,
            unitOfMeasure: 'Bags',
          ),
        ],
        isSynced: true,
      );

      final summary = note.toSummary();
      expect(summary.id, 'dn-uuid-999');
      expect(summary.number, 'DN-202611-0099');
      expect(summary.invoiceId, 'inv-uuid-123');
      expect(summary.vehicleNumber, 'T 123 ABC');
      expect(summary.carrierName, 'FastHaul Logistics');
      expect(summary.itemCount, 1);
      expect(summary.totalQuantity, 50);

      final summaryJson = summary.toJson();
      expect(summaryJson['vehicleNumber'], 'T 123 ABC');
      expect(summaryJson['invoiceId'], 'inv-uuid-123');

      final restored = DeliveryNoteSummary.fromJson(summaryJson);
      expect(restored.id, 'dn-uuid-999');
      expect(restored.invoiceId, 'inv-uuid-123');
      expect(restored.vehicleNumber, 'T 123 ABC');
      expect(restored.carrierName, 'FastHaul Logistics');
    });

    test('LocalPdfDocumentGenerator generates valid PDF bytes for Delivery Note A4 and Thermal', () async {
      final generator = LocalPdfDocumentGenerator();
      final note = DeliveryNote(
        id: 'dn-pdf-test',
        number: 'DN-202611-0055',
        customerName: 'Bakhresa Group',
        status: DeliveryNoteStatus.draft,
        issueDate: DateTime.utc(2026, 11, 19, 14, 0),
        vehicleNumber: 'T 999 ZZZ',
        driverName: 'Juma Hamisi',
        items: const [
          DeliveryNoteItem(
            id: 'item-1',
            productName: 'Industrial Sugar 50kg',
            quantityOrdered: 20,
            quantityToDeliver: 20,
            unitOfMeasure: 'Bags',
          ),
        ],
      );

      final a4Bytes = await generator.generateDeliveryNoteA4(
        note: note,
        isSwahili: true,
      );
      expect(a4Bytes, isNotEmpty);
      expect(a4Bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]); // %PDF

      final thermalBytes = await generator.generateDeliveryNoteThermal80mm(
        note: note,
        isSwahili: false,
      );
      expect(thermalBytes, isNotEmpty);
      expect(thermalBytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
    });

    test('DeliveryNote and DeliveryNoteItem serialize and restore SKU, invoiceNumber and compliant item fields', () {
      const itemWithSku = DeliveryNoteItem(
        id: 'dn-item-sku-1',
        productId: '00000000-0000-0000-0000-000000000001',
        productName: 'Cement 50kg',
        sku: 'SKU-CEM-50',
        quantityOrdered: 50,
        quantityToDeliver: 45,
        unitOfMeasure: 'Bags',
      );

      final itemJson = itemWithSku.toJson();
      expect(itemJson['sku'], 'SKU-CEM-50');
      expect(itemJson['description'], 'Cement 50kg');
      expect(itemJson['quantityDelivered'], 45.0);
      expect(itemJson['quantityToDeliver'], 45.0);

      final note = DeliveryNote(
        id: 'dn-101',
        number: 'DN-2026-101',
        customerName: 'Mega Hardware',
        invoiceId: 'inv-404',
        invoiceNumber: 'INV-2026-0042',
        issueDate: DateTime(2026, 11, 19),
        status: DeliveryNoteStatus.dispatched,
        items: [itemWithSku],
      );

      final noteJson = note.toJson();
      expect(noteJson['invoiceNumber'], 'INV-2026-0042');

      final restored = DeliveryNote.fromJson(noteJson);
      expect(restored.invoiceNumber, 'INV-2026-0042');
      expect(restored.items.first.sku, 'SKU-CEM-50');
      expect(restored.items.first.productName, 'Cement 50kg');
      expect(restored.items.first.quantityToDeliver, 45.0);
    });

    test('DeliveryNoteStatus transitions correctly from draft to dispatched to delivered', () {
      final draft = DeliveryNote(
        id: 'dn-seq-1',
        number: 'DN-202611-0001',
        customerName: 'Bakhresa Group',
        issueDate: DateTime(2026, 11, 19),
        status: DeliveryNoteStatus.draft,
        items: const [
          DeliveryNoteItem(
            id: 'item-1',
            productName: 'Wheat Flour 50kg',
            sku: 'SKU-FLOUR-50',
            quantityOrdered: 10,
            quantityToDeliver: 10,
            unitOfMeasure: 'Bags',
          ),
        ],
      );
      expect(draft.status, DeliveryNoteStatus.draft);
      expect(draft.number, matches(r'^DN-\d{6}-\d{4}$'));

      final dispatched = draft.copyWith(
        status: DeliveryNoteStatus.dispatched,
        dispatchedAt: DateTime(2026, 11, 19, 14, 30),
        driverName: 'John Mwangi',
        driverPhone: '+255 712 345 678',
        vehicleNumber: 'T 123 ABC',
      );
      expect(dispatched.status, DeliveryNoteStatus.dispatched);
      expect(dispatched.driverName, 'John Mwangi');
      expect(dispatched.vehicleNumber, 'T 123 ABC');

      final delivered = dispatched.copyWith(
        status: DeliveryNoteStatus.delivered,
        deliveredAt: DateTime(2026, 11, 19, 16, 45),
        recipientName: 'Ali Hassan - Store Manager',
      );
      expect(delivered.status, DeliveryNoteStatus.delivered);
      expect(delivered.recipientName, 'Ali Hassan - Store Manager');

      final cancelled = draft.copyWith(
        status: DeliveryNoteStatus.cancelled,
      );
      expect(cancelled.status, DeliveryNoteStatus.cancelled);
    });
  });

  group('Tax Invoice System, VRN & Proforma Conversion', () {
    test('Organization VRN and VAT properties round-trip serialization', () {
      const org = Organization(
        name: 'Dar Industrial Supplies',
        taxId: '100-200-300',
        vrn: '40012345Z',
        isVatRegistered: true,
        defaultVatRate: 18.0,
        isTaxInclusive: true,
      );

      final json = org.toJson();
      expect(json['vrn'], '40012345Z');
      expect(json['isVatRegistered'], isTrue);
      expect(json['defaultVatRate'], 18.0);
      expect(json['isTaxInclusive'], isTrue);

      final restored = Organization.fromJson(json);
      expect(restored.vrn, '40012345Z');
      expect(restored.isVatRegistered, isTrue);
      expect(restored.defaultVatRate, 18.0);
      expect(restored.isTaxInclusive, isTrue);

      final updated = restored.copyWith(isTaxInclusive: false);
      expect(updated.isTaxInclusive, isFalse);
    });

    test('CustomerInvoice customerVrn, isTaxInvoice, and isProforma getters and serialization', () {
      final invoice = CustomerInvoice(
        id: 'inv-tax-01',
        number: 'CINV-2026-9001',
        documentTitle: 'PROFORMA INVOICE',
        customerName: 'Kilimanjaro Traders',
        customerTin: '999-888-777',
        customerVrn: 'VRN-KILI-001',
        currency: 'TZS',
        issueDate: DateTime(2026, 11, 19),
        status: InvoiceStatus.unpaid,
        subtotal: 100000.0,
        taxAmount: 0.0,
        totalAmount: 100000.0,
        balanceDue: 100000.0,
        lines: const [
          InvoiceLine(
            id: 'line-1',
            description: 'Item 1',
            quantity: 1,
            unitPrice: 100000.0,
            lineTotal: 100000.0,
            taxAmount: 0.0,
          ),
        ],
      );

      expect(invoice.isProforma, isTrue);
      expect(invoice.isTaxInvoice, isFalse);
      expect(invoice.customerVrn, 'VRN-KILI-001');

      final json = invoice.toJson();
      expect(json['customerVrn'], 'VRN-KILI-001');
      expect(json['documentTitle'], 'PROFORMA INVOICE');

      final restored = CustomerInvoice.fromJson(json);
      expect(restored.isProforma, isTrue);
      expect(restored.isTaxInvoice, isFalse);
      expect(restored.customerVrn, 'VRN-KILI-001');

      final taxInvoice = restored.copyWith(
        documentTitle: 'TAX INVOICE',
      );
      expect(taxInvoice.isTaxInvoice, isTrue);
      expect(taxInvoice.isProforma, isFalse);

      final summary = taxInvoice.toSummary();
      expect(summary.customerVrn, 'VRN-KILI-001');
      expect(summary.isTaxInvoice, isTrue);
      expect(summary.isProforma, isFalse);
    });

    test('Tax Invoice conversion calculation logic for tax-exclusive and tax-inclusive modes', () {
      // 1. Tax-Exclusive: Subtotal 100,000 => 18% VAT added => Subtotal 100,000, Tax 18,000, Total 118,000
      const exclusiveOriginalSubtotal = 100000.0;
      const vatRate = 18.0;
      final exclusiveCalculatedTax = (exclusiveOriginalSubtotal * (vatRate / 100.0) * 100).round() / 100.0;
      final exclusiveCalculatedTotal = exclusiveOriginalSubtotal + exclusiveCalculatedTax;

      expect(exclusiveCalculatedTax, 18000.0);
      expect(exclusiveCalculatedTotal, 118000.0);

      // 2. Tax-Inclusive: Gross 118,000 => 18% VAT extracted => Subtotal 100,000, Tax 18,000, Total 118,000
      const inclusiveGrossAmount = 118000.0;
      final inclusiveSubtotal = (inclusiveGrossAmount / (1.0 + (vatRate / 100.0)) * 100).round() / 100.0;
      final inclusiveTax = ((inclusiveGrossAmount - inclusiveSubtotal) * 100).round() / 100.0;

      expect(inclusiveSubtotal, 100000.0);
      expect(inclusiveTax, 18000.0);
      expect(inclusiveSubtotal + inclusiveTax, inclusiveGrossAmount);
    });

    test('Document lineage: Proforma to Tax Invoice creates a distinct Tax Invoice preserving source intact', () {
      final proforma = CustomerInvoice(
        id: 'pro-uuid-101',
        number: 'PRO-202611-0001',
        documentTitle: 'PROFORMA INVOICE',
        issueDate: DateTime.utc(2026, 11, 20, 10, 0),
        customerName: 'Mega Wholesalers Ltd',
        customerPhone: '+255 777 000 111',
        customerTin: '123-456-789',
        customerVrn: '40-123456-X',
        status: InvoiceStatus.unpaid,
        subtotal: 100000.0,
        taxAmount: 0.0,
        totalAmount: 100000.0,
        balanceDue: 100000.0,
        lines: const [
          InvoiceLine(
            id: 'line-1',
            productId: 'prod-item-1',
            sku: 'SKU-WHEAT-50',
            description: 'Wheat Flour 50kg',
            unitOfMeasure: 'Bags',
            quantity: 1,
            unitPrice: 100000.0,
            lineTotal: 100000.0,
            taxAmount: 0.0,
          ),
        ],
      );

      // Verify source is a Proforma
      expect(proforma.isProforma, isTrue);
      expect(proforma.isTaxInvoice, isFalse);

      // Simulate lineage creation: New Tax Invoice is generated referencing proforma
      final newTaxInvoice = CustomerInvoice(
        id: 'tax-uuid-202',
        number: 'INV-202611-0042',
        documentTitle: 'TAX INVOICE',
        referenceNumber: 'Proforma #${proforma.displayNumber()}',
        issueDate: DateTime.utc(2026, 11, 20, 12, 0),
        customerName: proforma.customerName,
        customerPhone: proforma.customerPhone,
        customerTin: proforma.customerTin,
        customerVrn: proforma.customerVrn,
        status: InvoiceStatus.unpaid,
        subtotal: 100000.0,
        taxAmount: 18000.0,
        totalAmount: 118000.0,
        balanceDue: 118000.0,
        notes: 'Converted from Proforma #${proforma.displayNumber()}',
        lines: const [
          InvoiceLine(
            id: 'line-tax-1',
            productId: 'prod-item-1',
            sku: 'SKU-WHEAT-50',
            description: 'Wheat Flour 50kg',
            unitOfMeasure: 'Bags',
            quantity: 1,
            unitPrice: 100000.0,
            taxRatePercent: 18.0,
            lineTotal: 100000.0,
            taxAmount: 18000.0,
          ),
        ],
      );

      // Verify that the original proforma is intact and untouched
      expect(proforma.id, 'pro-uuid-101');
      expect(proforma.documentTitle, 'PROFORMA INVOICE');
      expect(proforma.totalAmount, 100000.0);
      expect(proforma.isProforma, isTrue);

      // Verify the new tax invoice has distinct identity and proper lineage
      expect(newTaxInvoice.id, 'tax-uuid-202');
      expect(newTaxInvoice.documentTitle, 'TAX INVOICE');
      expect(newTaxInvoice.isTaxInvoice, isTrue);
      expect(newTaxInvoice.referenceNumber, contains('PRO-202611-0001'));
      expect(newTaxInvoice.totalAmount, 118000.0);
      expect(newTaxInvoice.taxAmount, 18000.0);
      expect(newTaxInvoice.lines.first.productId, 'prod-item-1');
      expect(newTaxInvoice.lines.first.sku, 'SKU-WHEAT-50');
    });

    test('Direct Dispatch: Delivery Note initialized with status dispatched and dispatchedAt', () {
      final dispatchTime = DateTime.utc(2026, 11, 20, 14, 30);
      final note = DeliveryNote(
        id: 'dn-direct-001',
        number: 'DN-202611-0099',
        customerName: 'Safari Logistics Co',
        issueDate: dispatchTime,
        status: DeliveryNoteStatus.dispatched,
        dispatchedAt: dispatchTime,
        driverName: 'Bakari Mwamba',
        driverPhone: '0755123456',
        vehicleNumber: 'T 555 XYZ',
        items: const [
          DeliveryNoteItem(
            id: 'item-1',
            productName: 'Cement Bags',
            quantityOrdered: 50,
            quantityToDeliver: 50,
            unitOfMeasure: 'Bags',
          ),
        ],
      );

      expect(note.status, DeliveryNoteStatus.dispatched);
      expect(note.dispatchedAt, dispatchTime);
      expect(note.driverName, 'Bakari Mwamba');
      expect(note.driverPhone, '0755123456');
      expect(note.vehicleNumber, 'T 555 XYZ');

      final json = note.toJson();
      expect(json['status'], DeliveryNoteStatus.dispatched.code);
      expect(json['dispatchedAt'], dispatchTime.toIso8601String());

      final restored = DeliveryNote.fromJson(json);
      expect(restored.status, DeliveryNoteStatus.dispatched);
      expect(restored.dispatchedAt, isNotNull);
      expect(restored.driverName, 'Bakari Mwamba');
    });
  });
}

