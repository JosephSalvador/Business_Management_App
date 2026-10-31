import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../settings/data/organization_repository.dart';
import '../../domain/delivery_note.dart';
import '../../domain/invoice.dart';

final localPdfDocumentGeneratorProvider =
    Provider<LocalPdfDocumentGenerator>((ref) {
  return LocalPdfDocumentGenerator();
});

/// High-performance on-device native PDF compiler running completely offline
/// on the client canvas/GPU without any WebView or external network dependency.
class LocalPdfDocumentGenerator {
  static const PdfColor _defaultPrimary = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor _defaultSecondary = PdfColor.fromInt(0xFF0D9488);
  static const PdfColor _slate700 = PdfColor.fromInt(0xFF334155);
  static const PdfColor _slate500 = PdfColor.fromInt(0xFF64748B);
  static const PdfColor _slate200 = PdfColor.fromInt(0xFFE2E8F0);
  static const PdfColor _slate100 = PdfColor.fromInt(0xFFF1F5F9);
  static const PdfColor _slate50 = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor _green700 = PdfColor.fromInt(0xFF15803D);
  static const PdfColor _amber700 = PdfColor.fromInt(0xFFB45309);
  static const PdfColor _red700 = PdfColor.fromInt(0xFFB91C1C);

  PdfColor _parseHex(String? hex, PdfColor fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final val = int.tryParse('FF$clean', radix: 16);
      if (val != null) return PdfColor.fromInt(val);
    }
    return fallback;
  }

  // =========================================================================
  // 1. INVOICE - A4 CORPORATE STANDARD PROFILE
  // =========================================================================

  Future<Uint8List> generateInvoiceA4({
    required CustomerInvoice invoice,
    Organization? organization,
    String? primaryHex,
    String? secondaryHex,
    bool isSwahili = false,
  }) async {
    final primaryColor = _parseHex(primaryHex, _defaultPrimary);
    final secondaryColor = _parseHex(secondaryHex, _defaultSecondary);
    final orgName = organization?.name.isNotEmpty == true
        ? organization!.name
        : 'Biashara Yetu';
    final currency = invoice.currency.isNotEmpty ? invoice.currency : 'TZS';

    final document = pw.Document(
      title: '${invoice.documentTitle} ${invoice.number}',
      author: orgName,
      creator: 'Jolinx Business OS',
    );

    final dateFmt = DateFormat('dd MMM yyyy');
    final numFmt = NumberFormat('#,##0.##');
    String fmtMoney(double amount) => '$currency ${numFmt.format(amount)}';

    final qrData = [
      invoice.documentTitle,
      'No: ${invoice.number}',
      'Org: $orgName',
      if (organization?.taxId != null && organization!.taxId!.trim().isNotEmpty)
        'TIN: ${organization.taxId!.trim()}',
      'Client: ${invoice.customerLabel}',
      'Total: ${fmtMoney(invoice.totalAmount)}',
      'Balance: ${fmtMoney(invoice.balanceDue)}',
      'Date: ${dateFmt.format(invoice.issueDate.toLocal())}',
    ].join(' | ');

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 16),
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _slate200, width: 0.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Jolinx Business OS  •  $orgName',
                style: const pw.TextStyle(color: _slate500, fontSize: 8),
              ),
              pw.Text(
                '${context.pageNumber} / ${context.pagesCount}',
                style: const pw.TextStyle(color: _slate500, fontSize: 8),
              ),
            ],
          ),
        ),
        build: (context) => [
          // Header Accent Ribbon
          pw.Container(
            height: 4,
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
            ),
          ),
          pw.SizedBox(height: 16),

          // Header Title and Organization Info
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    orgName,
                    style: pw.TextStyle(
                      color: primaryColor,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (organization?.address?.isNotEmpty == true)
                    pw.Text(
                      organization!.address!,
                      style: const pw.TextStyle(color: _slate500, fontSize: 9),
                    ),
                  if (organization?.phone?.isNotEmpty == true)
                    pw.Text(
                      'Tel: ${organization!.phone!}',
                      style: const pw.TextStyle(color: _slate500, fontSize: 9),
                    ),
                  if (organization?.taxId?.isNotEmpty == true)
                    pw.Text(
                      'TIN: ${organization!.taxId!}',
                      style: pw.TextStyle(
                        color: _slate700,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: primaryColor,
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text(
                      invoice.documentTitle.toUpperCase(),
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    invoice.number,
                    style: pw.TextStyle(
                      color: _slate700,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '${isSwahili ? "Tarehe" : "Date"}: ${dateFmt.format(invoice.issueDate.toLocal())}',
                    style: const pw.TextStyle(color: _slate500, fontSize: 9),
                  ),
                  if (invoice.dueDate != null)
                    pw.Text(
                      '${isSwahili ? "Mwisho" : "Due"}: ${dateFmt.format(invoice.dueDate!.toLocal())}',
                      style: pw.TextStyle(
                        color: invoice.isOverdue ? _red700 : _slate500,
                        fontSize: 9,
                        fontWeight: invoice.isOverdue
                            ? pw.FontWeight.bold
                            : pw.FontWeight.normal,
                      ),
                    ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          // Bill To & Terms Card
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: _slate50,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: _slate200, width: 0.5),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        isSwahili ? 'MTEJA / TO:' : 'BILLED TO:',
                        style: pw.TextStyle(
                          color: _slate500,
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        invoice.customerLabel,
                        style: pw.TextStyle(
                          color: primaryColor,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (invoice.customerPhone != null &&
                          invoice.customerPhone!.isNotEmpty)
                        pw.Text('Tel: ${invoice.customerPhone}',
                            style: const pw.TextStyle(
                                color: _slate700, fontSize: 9)),
                      if (invoice.customerAddress != null &&
                          invoice.customerAddress!.isNotEmpty)
                        pw.Text(invoice.customerAddress!,
                            style: const pw.TextStyle(
                                color: _slate500, fontSize: 9)),
                      if (invoice.customerTin != null &&
                          invoice.customerTin!.isNotEmpty)
                        pw.Text('TIN: ${invoice.customerTin}',
                            style: pw.TextStyle(
                                color: _slate700,
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    if (invoice.referenceNumber != null &&
                        invoice.referenceNumber!.isNotEmpty)
                      pw.Text(
                        'Ref: ${invoice.referenceNumber}',
                        style: const pw.TextStyle(
                            color: _slate700, fontSize: 9),
                      ),
                    if (invoice.paymentTerms != null &&
                        invoice.paymentTerms!.isNotEmpty)
                      pw.Text(
                        'Terms: ${invoice.paymentTerms}',
                        style: const pw.TextStyle(
                            color: _slate500, fontSize: 9),
                      ),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: pw.BoxDecoration(
                        color: invoice.status == InvoiceStatus.paid
                            ? const PdfColor.fromInt(0xFFDCFCE7)
                            : (invoice.status == InvoiceStatus.partiallyPaid
                                ? const PdfColor.fromInt(0xFFFEF3C7)
                                : const PdfColor.fromInt(0xFFFEE2E2)),
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(
                        invoice.status.name.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: invoice.status == InvoiceStatus.paid
                              ? _green700
                              : (invoice.status == InvoiceStatus.partiallyPaid
                                  ? _amber700
                                  : _red700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Items Table
          pw.TableHelper.fromTextArray(
            headers: [
              isSwahili ? 'Maelezo ya Bidhaa' : 'Item Description',
              isSwahili ? 'Kipimo' : 'UoM',
              isSwahili ? 'Idadi' : 'Qty',
              isSwahili ? 'Bei' : 'Unit Price',
              isSwahili ? 'Kodi' : 'Tax',
              isSwahili ? 'Jumla' : 'Total',
            ],
            data: [
              for (final line in invoice.lines)
                [
                  line.description,
                  line.unitOfMeasure,
                  numFmt.format(line.quantity),
                  numFmt.format(line.unitPrice),
                  line.taxAmount > 0 ? numFmt.format(line.taxAmount) : '—',
                  numFmt.format(line.lineTotal),
                ],
            ],
            border: null,
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration: pw.BoxDecoration(color: primaryColor),
            headerHeight: 22,
            cellHeight: 22,
            cellStyle: const pw.TextStyle(color: _slate700, fontSize: 8.5),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
            },
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(
                  bottom: pw.BorderSide(color: _slate200, width: 0.5)),
            ),
          ),
          pw.SizedBox(height: 16),

          // Financial Summary Block
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // QR Code and Verification
              pw.Expanded(
                flex: 5,
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 64,
                      height: 64,
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: qrData,
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            isSwahili
                                ? 'Uthibitisho wa Kidijitali'
                                : 'Digital Verification',
                            style: pw.TextStyle(
                              color: _slate700,
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            isSwahili
                                ? 'Hati hii imetengenezwa na mfumo wa Jolinx OS.'
                                : 'Generated securely by Jolinx Business OS.',
                            style: const pw.TextStyle(
                                color: _slate500, fontSize: 7.5),
                          ),
                          if (invoice.notes != null &&
                              invoice.notes!.isNotEmpty) ...[
                            pw.SizedBox(height: 4),
                            pw.Text('Notes: ${invoice.notes}',
                                style: const pw.TextStyle(
                                    color: _slate500, fontSize: 7.5)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Totals Table
              pw.Expanded(
                flex: 5,
                child: pw.Column(
                  children: [
                    _buildTotalRow('Subtotal:', fmtMoney(invoice.subtotal)),
                    if (invoice.discountAmount > 0)
                      _buildTotalRow('Discount:',
                          '-${fmtMoney(invoice.discountAmount)}',
                          valueColor: _red700),
                    if (invoice.taxAmount > 0)
                      _buildTotalRow(
                          'VAT / Tax:', fmtMoney(invoice.taxAmount)),
                    pw.Divider(color: _slate200, thickness: 0.5),
                    _buildTotalRow('TOTAL:', fmtMoney(invoice.totalAmount),
                        isBold: true,
                        fontSize: 12,
                        valueColor: primaryColor),
                    if (invoice.amountPaid > 0)
                      _buildTotalRow(
                          'Amount Paid:', fmtMoney(invoice.amountPaid),
                          valueColor: _green700),
                    _buildTotalRow('BALANCE DUE:', fmtMoney(invoice.balanceDue),
                        isBold: true,
                        fontSize: 11,
                        valueColor: invoice.balanceDue > 0
                            ? _red700
                            : _green700),
                  ],
                ),
              ),
            ],
          ),

          if (invoice.paymentInstructions != null &&
              invoice.paymentInstructions!.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: _slate100,
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    isSwahili ? 'Maelekezo ya Malipo:' : 'Payment Instructions:',
                    style: pw.TextStyle(
                      color: primaryColor,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(invoice.paymentInstructions!,
                      style:
                          const pw.TextStyle(color: _slate700, fontSize: 8)),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    return document.save();
  }

  // =========================================================================
  // 2. INVOICE - 80MM CONTINUOUS THERMAL ROLL PROFILE
  // =========================================================================

  Future<Uint8List> generateInvoiceThermal80mm({
    required CustomerInvoice invoice,
    Organization? organization,
    bool isSwahili = false,
  }) async {
    final orgName = organization?.name.isNotEmpty == true
        ? organization!.name
        : 'Biashara Yetu';
    final currency = invoice.currency.isNotEmpty ? invoice.currency : 'TZS';

    final document = pw.Document(
      title: '${invoice.documentTitle} ${invoice.number}',
      author: orgName,
      creator: 'Jolinx Business OS',
    );

    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    final numFmt = NumberFormat('#,##0.##');
    String fmtMoney(double amount) => '$currency ${numFmt.format(amount)}';

    final qrData =
        '${invoice.number}|${invoice.customerLabel}|${fmtMoney(invoice.totalAmount)}';

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Store Title
            pw.Text(
              orgName.toUpperCase(),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            if (organization?.address != null &&
                organization!.address!.isNotEmpty)
              pw.Text(organization.address!,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 8)),
            if (organization?.phone != null &&
                organization!.phone!.isNotEmpty)
              pw.Text('Tel: ${organization.phone!}',
                  style: const pw.TextStyle(fontSize: 8)),
            if (organization?.taxId != null &&
                organization!.taxId!.isNotEmpty)
              pw.Text('TIN: ${organization.taxId!}',
                  style: pw.TextStyle(
                      fontSize: 8, fontWeight: pw.FontWeight.bold)),

            pw.SizedBox(height: 4),
            _buildThermalDashedLine(),
            pw.SizedBox(height: 4),

            // Document Title & Number
            pw.Text(
              '${invoice.documentTitle} ${invoice.number}',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              dateFmt.format(invoice.issueDate.toLocal()),
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.Text(
              '${isSwahili ? "Mteja" : "Client"}: ${invoice.customerLabel}',
              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
            ),

            pw.SizedBox(height: 4),
            _buildThermalDashedLine(),
            pw.SizedBox(height: 4),

            // Line Items
            for (final line in invoice.lines) ...[
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      line.description,
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold),
                      maxLines: 2,
                    ),
                  ),
                  pw.Text(
                    numFmt.format(line.lineTotal),
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '${numFmt.format(line.quantity)} ${line.unitOfMeasure} @ ${numFmt.format(line.unitPrice)}',
                    style: const pw.TextStyle(fontSize: 7.5, color: _slate500),
                  ),
                  if (line.discountAmount > 0)
                    pw.Text(
                      'Punguzo: -${numFmt.format(line.discountAmount)}',
                      style: const pw.TextStyle(fontSize: 7, color: _red700),
                    ),
                ],
              ),
              pw.SizedBox(height: 3),
            ],

            pw.SizedBox(height: 4),
            _buildThermalDashedLine(),
            pw.SizedBox(height: 4),

            // Totals
            _buildThermalRow('Subtotal:', fmtMoney(invoice.subtotal)),
            if (invoice.discountAmount > 0)
              _buildThermalRow(
                  'Discount:', '-${fmtMoney(invoice.discountAmount)}'),
            if (invoice.taxAmount > 0)
              _buildThermalRow('Tax/VAT:', fmtMoney(invoice.taxAmount)),
            _buildThermalRow('TOTAL:', fmtMoney(invoice.totalAmount),
                isBold: true, fontSize: 10),
            if (invoice.amountPaid > 0)
              _buildThermalRow('Paid:', fmtMoney(invoice.amountPaid)),
            _buildThermalRow('BAL DUE:', fmtMoney(invoice.balanceDue),
                isBold: true, fontSize: 9.5),

            pw.SizedBox(height: 6),
            _buildThermalDashedLine(),
            pw.SizedBox(height: 6),

            // QR Code
            pw.Container(
              width: 50,
              height: 50,
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: qrData,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              isSwahili
                  ? 'Asante kwa Biashara Yako!'
                  : 'Thank you for your business!',
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.Text(
              'Powered by Jolinx OS',
              style: const pw.TextStyle(fontSize: 7, color: _slate500),
            ),
          ],
        ),
      ),
    );

    return document.save();
  }

  // =========================================================================
  // 3. DELIVERY NOTE - A4 CORPORATE STANDARD PROFILE
  // =========================================================================

  Future<Uint8List> generateDeliveryNoteA4({
    required DeliveryNote note,
    Organization? organization,
    String? primaryHex,
    String? secondaryHex,
    bool isSwahili = false,
  }) async {
    final primaryColor = _parseHex(primaryHex, _defaultPrimary);
    final orgName = organization?.name.isNotEmpty == true
        ? organization!.name
        : 'Biashara Yetu';

    final document = pw.Document(
      title: 'DELIVERY NOTE ${note.number}',
      author: orgName,
      creator: 'Jolinx Business OS',
    );

    final dateFmt = DateFormat('dd MMM yyyy');
    final numFmt = NumberFormat('#,##0.##');

    final qrData =
        'DN:${note.number}|Client:${note.customerName}|Items:${note.items.length}|Qty:${note.totalQuantity}';

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header Accent Bar
          pw.Container(
            height: 4,
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
            ),
          ),
          pw.SizedBox(height: 16),

          // Header
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    orgName,
                    style: pw.TextStyle(
                      color: primaryColor,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (organization?.address?.isNotEmpty == true)
                    pw.Text(organization!.address!,
                        style: const pw.TextStyle(
                            color: _slate500, fontSize: 9)),
                  if (organization?.phone?.isNotEmpty == true)
                    pw.Text('Tel: ${organization!.phone!}',
                        style: const pw.TextStyle(
                            color: _slate500, fontSize: 9)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: primaryColor,
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text(
                      isSwahili ? 'WARAKA WA MZIGO' : 'DELIVERY NOTE',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    note.number,
                    style: pw.TextStyle(
                      color: _slate700,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '${isSwahili ? "Tarehe" : "Date"}: ${dateFmt.format(note.issueDate.toLocal())}',
                    style: const pw.TextStyle(color: _slate500, fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          // Logistics & Recipient Card
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: _slate50,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: _slate200, width: 0.5),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        isSwahili ? 'MPOKEA MZIGO / CONSIGNEE:' : 'DELIVER TO:',
                        style: pw.TextStyle(
                          color: _slate500,
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        note.customerName,
                        style: pw.TextStyle(
                          color: primaryColor,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (note.customerPhone != null &&
                          note.customerPhone!.isNotEmpty)
                        pw.Text('Tel: ${note.customerPhone}',
                            style: const pw.TextStyle(
                                color: _slate700, fontSize: 9)),
                      if (note.deliveryAddress != null &&
                          note.deliveryAddress!.isNotEmpty)
                        pw.Text('Destination: ${note.deliveryAddress}',
                            style: const pw.TextStyle(
                                color: _slate500, fontSize: 9)),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    if (note.carrierName != null)
                      pw.Text('Carrier: ${note.carrierName}',
                          style: const pw.TextStyle(
                              color: _slate700, fontSize: 9)),
                    if (note.vehicleNumber != null)
                      pw.Text('Vehicle: ${note.vehicleNumber}',
                          style: const pw.TextStyle(
                              color: _slate700, fontSize: 9)),
                    if (note.driverName != null)
                      pw.Text('Driver: ${note.driverName}',
                          style: const pw.TextStyle(
                              color: _slate500, fontSize: 9)),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: const pw.BoxDecoration(
                        color: _slate100,
                        borderRadius:
                            pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(
                        note.status.name.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Items Table
          pw.TableHelper.fromTextArray(
            headers: [
              isSwahili ? 'Na.' : 'No.',
              isSwahili ? 'Maelezo ya Bidhaa' : 'Item Description',
              isSwahili ? 'SKU' : 'SKU',
              isSwahili ? 'Kipimo' : 'UoM',
              isSwahili ? 'Iliyoagizwa' : 'Ordered',
              isSwahili ? 'Inayosafirishwa' : 'Delivered',
            ],
            data: [
              for (var i = 0; i < note.items.length; i++)
                [
                  '${i + 1}',
                  note.items[i].productName,
                  note.items[i].sku ?? '—',
                  note.items[i].unitOfMeasure,
                  numFmt.format(note.items[i].quantityOrdered),
                  numFmt.format(note.items[i].quantityToDeliver),
                ],
            ],
            border: null,
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration: pw.BoxDecoration(color: primaryColor),
            headerHeight: 22,
            cellHeight: 22,
            cellStyle: const pw.TextStyle(color: _slate700, fontSize: 8.5),
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
            },
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(
                  bottom: pw.BorderSide(color: _slate200, width: 0.5)),
            ),
          ),
          pw.SizedBox(height: 24),

          // Signatures & Acknowledgement
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    isSwahili
                        ? 'Alieandaa (Jina na Sahihi):'
                        : 'Dispatched By (Sign & Date):',
                    style: const pw.TextStyle(color: _slate500, fontSize: 8),
                  ),
                  pw.SizedBox(height: 24),
                  pw.Container(
                    width: 160,
                    height: 1,
                    color: _slate700,
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    isSwahili
                        ? 'Mpokeaji (Jina na Sahihi):'
                        : 'Received By (Sign & Date):',
                    style: const pw.TextStyle(color: _slate500, fontSize: 8),
                  ),
                  pw.SizedBox(height: 24),
                  pw.Container(
                    width: 160,
                    height: 1,
                    color: _slate700,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return document.save();
  }

  // =========================================================================
  // 4. DELIVERY NOTE - 80MM THERMAL PROFILE
  // =========================================================================

  Future<Uint8List> generateDeliveryNoteThermal80mm({
    required DeliveryNote note,
    Organization? organization,
    bool isSwahili = false,
  }) async {
    final orgName = organization?.name.isNotEmpty == true
        ? organization!.name
        : 'Biashara Yetu';

    final document = pw.Document(
      title: 'DELIVERY NOTE ${note.number}',
      author: orgName,
      creator: 'Jolinx Business OS',
    );

    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    final numFmt = NumberFormat('#,##0.##');

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              orgName.toUpperCase(),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            _buildThermalDashedLine(),
            pw.SizedBox(height: 4),

            pw.Text(
              '${isSwahili ? "WARAKA WA MZIGO" : "DELIVERY NOTE"} ${note.number}',
              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              dateFmt.format(note.issueDate.toLocal()),
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.Text(
              '${isSwahili ? "Mteja" : "Client"}: ${note.customerName}',
              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
            ),

            pw.SizedBox(height: 4),
            _buildThermalDashedLine(),
            pw.SizedBox(height: 4),

            for (final item in note.items) ...[
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      item.productName,
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Text(
                    '${numFmt.format(item.quantityToDeliver)} ${item.unitOfMeasure}',
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
            ],

            pw.SizedBox(height: 4),
            _buildThermalDashedLine(),
            pw.SizedBox(height: 4),

            _buildThermalRow('Total Qty:', numFmt.format(note.totalQuantity),
                isBold: true),

            pw.SizedBox(height: 12),
            pw.Text(
              isSwahili
                  ? 'Sahihi ya Mpokeaji: ________________'
                  : 'Recipient Signature: ________________',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
      ),
    );

    return document.save();
  }

  // =========================================================================
  // HELPER METHODS
  // =========================================================================

  static pw.Widget _buildTotalRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 9,
    PdfColor? valueColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              color: _slate500,
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: valueColor ?? _slate700,
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildThermalRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 8.5,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildThermalDashedLine() {
    return pw.Text(
      '------------------------------------------------',
      maxLines: 1,
      style: const pw.TextStyle(fontSize: 7, color: _slate500),
    );
  }
}
