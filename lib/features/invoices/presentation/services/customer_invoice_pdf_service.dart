import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../settings/data/organization_repository.dart';
import '../../domain/invoice.dart';

final customerInvoicePdfServiceProvider =
    Provider<CustomerInvoicePdfService>((ref) {
  return CustomerInvoicePdfService();
});

class CustomerInvoicePdfService {
  static const PdfColor _navy = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor _teal = PdfColor.fromInt(0xFF0D9488);
  static const PdfColor _slate700 = PdfColor.fromInt(0xFF334155);
  static const PdfColor _slate500 = PdfColor.fromInt(0xFF64748B);
  static const PdfColor _slate200 = PdfColor.fromInt(0xFFE2E8F0);
  static const PdfColor _slate100 = PdfColor.fromInt(0xFFF1F5F9);
  static const PdfColor _slate50 = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor _green700 = PdfColor.fromInt(0xFF15803D);
  static const PdfColor _amber700 = PdfColor.fromInt(0xFFB45309);
  static const PdfColor _red700 = PdfColor.fromInt(0xFFB91C1C);

  Future<Uint8List> buildA4Pdf({
    required CustomerInvoice invoice,
    required Organization organization,
    bool isSwahili = false,
  }) async {
    final document = pw.Document(
      title: '${invoice.documentTitle} ${invoice.invoiceNumber}',
      author: organization.name,
      creator: 'Jolinx Business OS',
    );

    final dateFormat = DateFormat('dd MMM yyyy');
    final numberFormat = NumberFormat('#,##0.##');
    final currency =
        organization.currency.isNotEmpty ? organization.currency : 'TZS';

    String fmtMoney(double amount) => '$currency ${numberFormat.format(amount)}';

    final logoImage = _decodeLogo(organization.logoBase64);
    final hasLineDiscounts =
        invoice.lines.any((line) => line.discountAmount > 0);
    final paymentInstructionsText =
        _resolvePaymentInstructions(invoice, organization, isSwahili);
    final notesAndTermsText = _resolveNotesAndTerms(invoice, organization);
    final signatoryName =
        (invoice.authorizedSignatoryName?.trim().isNotEmpty ?? false)
            ? invoice.authorizedSignatoryName!.trim()
            : (organization.authorizedSignatoryName?.trim().isNotEmpty ?? false)
                ? organization.authorizedSignatoryName!.trim()
                : '';
    final signatoryTitle =
        (invoice.authorizedSignatoryTitle?.trim().isNotEmpty ?? false)
            ? invoice.authorizedSignatoryTitle!.trim()
            : (organization.authorizedSignatoryTitle?.trim().isNotEmpty ??
                    false)
                ? organization.authorizedSignatoryTitle!.trim()
                : (isSwahili ? 'Sahihi Iliyoidhinishwa' : 'Authorized Signatory');

    final qrData = [
      invoice.documentTitle,
      'No: ${invoice.invoiceNumber}',
      'Seller: ${organization.name}',
      if (organization.taxId != null && organization.taxId!.trim().isNotEmpty)
        'TIN: ${organization.taxId!.trim()}',
      'Client: ${invoice.customerName}',
      'Total: ${fmtMoney(invoice.totalAmount)}',
      'Balance: ${fmtMoney(invoice.balanceDue)}',
      'Date: ${dateFormat.format(invoice.issueDate.toLocal())}',
    ].join(' | ');

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 32),
        footer: (context) => _buildPageFooter(
          context: context,
          organization: organization,
          invoice: invoice,
          isSwahili: isSwahili,
        ),
        build: (context) => [
          // Top Accent Bar
          pw.Container(
            height: 5,
            decoration: const pw.BoxDecoration(
              color: _navy,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
            ),
          ),
          pw.SizedBox(height: 16),

          // 1 & 2. Header: Seller Identity + Logo (Left) | Document Metadata (Right)
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                flex: 6,
                child: _buildSellerBlock(
                  organization: organization,
                  logoImage: logoImage,
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                flex: 5,
                child: _buildDocumentMetaBlock(
                  invoice: invoice,
                  dateFormat: dateFormat,
                  isSwahili: isSwahili,
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          // 3. Client ("Bill To") Block
          _buildClientBlock(invoice: invoice, isSwahili: isSwahili),

          pw.SizedBox(height: 20),

          // 4. Itemised Table
          _buildLineItemsTable(
            invoice: invoice,
            numberFormat: numberFormat,
            hasLineDiscounts: hasLineDiscounts,
            isSwahili: isSwahili,
          ),

          pw.SizedBox(height: 18),

          // 5 & 6. Payment Instructions (Left) + Financial Summary Totals (Right)
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 6,
                child: _buildPaymentInstructionsBox(
                  paymentInstructionsText: paymentInstructionsText,
                  invoiceNumber: invoice.invoiceNumber,
                  isSwahili: isSwahili,
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                flex: 5,
                child: _buildTotalsBox(
                  invoice: invoice,
                  fmtMoney: fmtMoney,
                  isSwahili: isSwahili,
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 18),

          // 7. Payment History (if any payments recorded)
          if (invoice.payments.isNotEmpty) ...[
            _buildPaymentsTable(
              invoice: invoice,
              dateFormat: dateFormat,
              fmtMoney: fmtMoney,
              isSwahili: isSwahili,
            ),
            pw.SizedBox(height: 18),
          ],

          // 8. Terms & Notes + QR Code + Official Signature & Stamp Area
          _buildBottomTermsAndSignature(
            notesAndTermsText: notesAndTermsText,
            qrData: qrData,
            signatoryName: signatoryName,
            signatoryTitle: signatoryTitle,
            organizationName: organization.name,
            isSwahili: isSwahili,
          ),
        ],
      ),
    );

    return document.save();
  }

  Future<void> shareA4Pdf({
    required CustomerInvoice invoice,
    required Organization organization,
    bool isSwahili = false,
  }) async {
    final bytes = await buildA4Pdf(
      invoice: invoice,
      organization: organization,
      isSwahili: isSwahili,
    );
    final safeNumber =
        invoice.invoiceNumber.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final docPrefix = invoice.documentTitle
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    await SharePlus.instance.share(
      ShareParams(
        text:
            '${invoice.documentTitle} ${invoice.invoiceNumber} - ${organization.name}',
        subject: '${invoice.documentTitle} ${invoice.invoiceNumber}',
        files: [
          XFile.fromData(
            bytes,
            mimeType: 'application/pdf',
            name: '$docPrefix-$safeNumber.pdf',
          ),
        ],
      ),
    );
  }

  pw.MemoryImage? _decodeLogo(String? logoBase64) {
    if (logoBase64 == null || logoBase64.trim().isEmpty) return null;
    try {
      var raw = logoBase64.trim();
      final commaIndex = raw.indexOf(',');
      if (raw.startsWith('data:') && commaIndex != -1) {
        raw = raw.substring(commaIndex + 1);
      }
      final bytes = base64Decode(raw);
      if (bytes.isEmpty) return null;
      return pw.MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  pw.Widget _buildSellerBlock({
    required Organization organization,
    required pw.MemoryImage? logoImage,
  }) {
    final initials = _extractInitials(organization.name);
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (logoImage != null)
          pw.Container(
            width: 58,
            height: 58,
            margin: const pw.EdgeInsets.only(right: 12),
            decoration: pw.BoxDecoration(
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: _slate200, width: 0.8),
            ),
            child: pw.ClipRRect(
              horizontalRadius: 7,
              verticalRadius: 7,
              child: pw.Image(logoImage, fit: pw.BoxFit.contain),
            ),
          )
        else
          pw.Container(
            width: 52,
            height: 52,
            margin: const pw.EdgeInsets.only(right: 12),
            alignment: pw.Alignment.center,
            decoration: const pw.BoxDecoration(
              color: _navy,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Text(
              initials,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                organization.name.isNotEmpty
                    ? organization.name.toUpperCase()
                    : 'BUSINESS NAME',
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                  color: _navy,
                ),
              ),
              if (organization.taxId != null &&
                  organization.taxId!.trim().isNotEmpty) ...[
                pw.SizedBox(height: 3),
                pw.Text(
                  'TIN: ${organization.taxId!.trim()}',
                  style: pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _teal,
                  ),
                ),
              ],
              if (organization.address != null &&
                  organization.address!.trim().isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  organization.address!.trim(),
                  style: const pw.TextStyle(fontSize: 9, color: _slate700),
                ),
              ],
              if (organization.phone != null &&
                  organization.phone!.trim().isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  'Tel: ${organization.phone!.trim()}',
                  style: const pw.TextStyle(fontSize: 9, color: _slate700),
                ),
              ],
              if (organization.email != null &&
                  organization.email!.trim().isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  organization.email!.trim(),
                  style: const pw.TextStyle(fontSize: 9, color: _slate700),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildDocumentMetaBlock({
    required CustomerInvoice invoice,
    required DateFormat dateFormat,
    required bool isSwahili,
  }) {
    final statusColor = _statusColor(invoice);
    final statusLabel = _statusLabel(invoice, isSwahili);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          invoice.documentTitle.toUpperCase(),
          textAlign: pw.TextAlign.right,
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: _navy,
            letterSpacing: 0.6,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(
              '#${invoice.invoiceNumber}',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _slate700,
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: pw.BoxDecoration(
                color: statusColor,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(
                statusLabel,
                style: pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: _slate50,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            border: pw.Border.all(color: _slate200, width: 0.8),
          ),
          child: pw.Column(
            children: [
              _metaRow(
                isSwahili ? 'Tarehe ya Kutolewa:' : 'Issue Date:',
                dateFormat.format(invoice.issueDate.toLocal()),
              ),
              pw.SizedBox(height: 3),
              _metaRow(
                isSwahili ? 'Tarehe ya Mwisho:' : 'Due Date:',
                dateFormat.format(invoice.dueDate.toLocal()),
              ),
              if (invoice.paymentTerms != null &&
                  invoice.paymentTerms!.trim().isNotEmpty) ...[
                pw.SizedBox(height: 3),
                _metaRow(
                  isSwahili ? 'Masharti:' : 'Terms:',
                  invoice.paymentTerms!.trim(),
                ),
              ],
              if (invoice.referenceNumber != null &&
                  invoice.referenceNumber!.trim().isNotEmpty) ...[
                pw.SizedBox(height: 3),
                _metaRow(
                  isSwahili ? 'Kumbukumbu / PO:' : 'Ref / PO No:',
                  invoice.referenceNumber!.trim(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _metaRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8.5, color: _slate500),
        ),
        pw.SizedBox(width: 8),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
            color: _navy,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildClientBlock({
    required CustomerInvoice invoice,
    required bool isSwahili,
  }) {
    final hasContactDetails =
        (invoice.customerAttention?.trim().isNotEmpty ?? false) ||
            (invoice.customerTin?.trim().isNotEmpty ?? false) ||
            (invoice.customerPhone?.trim().isNotEmpty ?? false) ||
            (invoice.customerEmail?.trim().isNotEmpty ?? false) ||
            (invoice.customerAddress?.trim().isNotEmpty ?? false);

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _slate50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: const pw.Border(
          left: pw.BorderSide(color: _navy, width: 3.5),
          top: pw.BorderSide(color: _slate200, width: 0.6),
          right: pw.BorderSide(color: _slate200, width: 0.6),
          bottom: pw.BorderSide(color: _slate200, width: 0.6),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            isSwahili ? 'KWA MTEJA (BILL TO)' : 'BILL TO',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _slate500,
              letterSpacing: 0.8,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            invoice.customerName,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: _navy,
            ),
          ),
          if (hasContactDetails) ...[
            pw.SizedBox(height: 4),
            pw.Wrap(
              spacing: 16,
              runSpacing: 3,
              children: [
                if (invoice.customerAttention != null &&
                    invoice.customerAttention!.trim().isNotEmpty)
                  pw.Text(
                    'Attn: ${invoice.customerAttention!.trim()}',
                    style: const pw.TextStyle(fontSize: 9, color: _slate700),
                  ),
                if (invoice.customerTin != null &&
                    invoice.customerTin!.trim().isNotEmpty)
                  pw.Text(
                    'TIN: ${invoice.customerTin!.trim()}',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _slate700,
                    ),
                  ),
                if (invoice.customerPhone != null &&
                    invoice.customerPhone!.trim().isNotEmpty)
                  pw.Text(
                    'Tel: ${invoice.customerPhone!.trim()}',
                    style: const pw.TextStyle(fontSize: 9, color: _slate700),
                  ),
                if (invoice.customerEmail != null &&
                    invoice.customerEmail!.trim().isNotEmpty)
                  pw.Text(
                    invoice.customerEmail!.trim(),
                    style: const pw.TextStyle(fontSize: 9, color: _slate700),
                  ),
              ],
            ),
            if (invoice.customerAddress != null &&
                invoice.customerAddress!.trim().isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                invoice.customerAddress!.trim(),
                style: const pw.TextStyle(fontSize: 9, color: _slate700),
              ),
            ],
          ],
        ],
      ),
    );
  }

  pw.Widget _buildLineItemsTable({
    required CustomerInvoice invoice,
    required NumberFormat numberFormat,
    required bool hasLineDiscounts,
    required bool isSwahili,
  }) {
    final headers = <String>[
      '#',
      isSwahili ? 'Maelezo ya Bidhaa / Huduma' : 'Item Description',
      isSwahili ? 'Kipimo' : 'Unit',
      isSwahili ? 'Idadi' : 'Qty',
      isSwahili ? 'Bei' : 'Unit Price',
      if (hasLineDiscounts) isSwahili ? 'Punguzo' : 'Discount',
      isSwahili ? 'Jumla' : 'Line Total',
    ];

    return pw.Table(
      border: pw.TableBorder(
        horizontalInside: const pw.BorderSide(color: _slate200, width: 0.6),
        bottom: const pw.BorderSide(color: _navy, width: 1.2),
      ),
      columnWidths: hasLineDiscounts
          ? {
              0: const pw.FixedColumnWidth(24),
              1: const pw.FlexColumnWidth(4.2),
              2: const pw.FixedColumnWidth(46),
              3: const pw.FixedColumnWidth(42),
              4: const pw.FixedColumnWidth(72),
              5: const pw.FixedColumnWidth(62),
              6: const pw.FixedColumnWidth(80),
            }
          : {
              0: const pw.FixedColumnWidth(26),
              1: const pw.FlexColumnWidth(4.6),
              2: const pw.FixedColumnWidth(52),
              3: const pw.FixedColumnWidth(46),
              4: const pw.FixedColumnWidth(82),
              5: const pw.FixedColumnWidth(88),
            },
      children: [
        // Table Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _navy),
          children: List.generate(headers.length, (index) {
            final isRight = index >= 3;
            return pw.Padding(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
              child: pw.Text(
                headers[index],
                textAlign: isRight ? pw.TextAlign.right : pw.TextAlign.left,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
          }),
        ),
        // Table Rows
        ...List.generate(invoice.lines.length, (i) {
          final line = invoice.lines[i];
          final bgColor = i.isEven ? PdfColors.white : _slate50;
          final cells = <String>[
            '${i + 1}',
            line.description,
            line.unitOfMeasure.isNotEmpty ? line.unitOfMeasure : 'Pcs',
            numberFormat.format(line.quantity),
            numberFormat.format(line.unitPrice),
            if (hasLineDiscounts)
              line.discountAmount > 0
                  ? '-${numberFormat.format(line.discountAmount)}'
                  : '-',
            numberFormat.format(line.lineTotal),
          ];

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bgColor),
            children: List.generate(cells.length, (cellIndex) {
              final isRight = cellIndex >= 3;
              final isBold = cellIndex == cells.length - 1;
              return pw.Padding(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                child: pw.Text(
                  cells[cellIndex],
                  textAlign: isRight ? pw.TextAlign.right : pw.TextAlign.left,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight:
                        isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: _navy,
                  ),
                ),
              );
            }),
          );
        }),
      ],
    );
  }

  pw.Widget _buildPaymentInstructionsBox({
    required String paymentInstructionsText,
    required String invoiceNumber,
    required bool isSwahili,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _slate50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: _slate200, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            isSwahili
                ? 'MAELEKEZO YA MALIPO (PAYMENT DETAILS)'
                : 'PAYMENT INSTRUCTIONS',
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: _navy,
              letterSpacing: 0.5,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            paymentInstructionsText,
            style: const pw.TextStyle(
              fontSize: 8.5,
              color: _slate700,
              lineSpacing: 2,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            isSwahili
                ? 'Tafadhali taja namba ya ankara #$invoiceNumber unapofanya malipo.'
                : 'Please quote Invoice #$invoiceNumber as payment reference.',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _teal,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTotalsBox({
    required CustomerInvoice invoice,
    required String Function(double) fmtMoney,
    required bool isSwahili,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _totalRow(
          label: isSwahili ? 'Jumla Ndogo (Subtotal)' : 'Subtotal',
          value: fmtMoney(invoice.subtotal),
        ),
        if (invoice.discountAmount > 0) ...[
          pw.SizedBox(height: 4),
          _totalRow(
            label: isSwahili ? 'Punguzo (Discount)' : 'Discount',
            value: '- ${fmtMoney(invoice.discountAmount)}',
            valueColor: _amber700,
          ),
        ],
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          child: pw.Divider(color: _slate200, height: 1),
        ),
        _totalRow(
          label: isSwahili ? 'Jumla Kuu (Total)' : 'Total Amount',
          value: fmtMoney(invoice.totalAmount),
          isBold: true,
        ),
        if (invoice.amountPaid > 0) ...[
          pw.SizedBox(height: 4),
          _totalRow(
            label: isSwahili ? 'Kiasi Kilicholipwa (Paid)' : 'Amount Paid',
            value: '- ${fmtMoney(invoice.amountPaid)}',
            valueColor: _green700,
            isBold: true,
          ),
        ],
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: const pw.BoxDecoration(
            color: _navy,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                isSwahili ? 'SALIO LA KULIPWA' : 'BALANCE DUE',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                fmtMoney(invoice.balanceDue),
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _totalRow({
    required String label,
    required String value,
    bool isBold = false,
    PdfColor valueColor = _navy,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: _slate700,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: isBold ? 10 : 9,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPaymentsTable({
    required CustomerInvoice invoice,
    required DateFormat dateFormat,
    required String Function(double) fmtMoney,
    required bool isSwahili,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _slate50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: _slate200, width: 0.7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            isSwahili ? 'HISTORIA YA MALIPO' : 'RECORDED PAYMENTS',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _slate500,
              letterSpacing: 0.5,
            ),
          ),
          pw.SizedBox(height: 5),
          ...invoice.payments.map(
            (p) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '${dateFormat.format(p.paidAt.toLocal())}  •  ${p.paymentMethod}'
                    '${p.reference != null && p.reference!.trim().isNotEmpty ? " (${p.reference!.trim()})" : ""}',
                    style: const pw.TextStyle(fontSize: 8.5, color: _slate700),
                  ),
                  pw.Text(
                    fmtMoney(p.amount),
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: _green700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildBottomTermsAndSignature({
    required String notesAndTermsText,
    required String qrData,
    required String signatoryName,
    required String signatoryTitle,
    required String organizationName,
    required bool isSwahili,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        // Terms & Notes + QR Code
        pw.Expanded(
          flex: 6,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (notesAndTermsText.isNotEmpty) ...[
                pw.Text(
                  isSwahili
                      ? 'MASHARTI NA MAELEZO (TERMS & NOTES)'
                      : 'TERMS & CONDITIONS / NOTES',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _slate500,
                    letterSpacing: 0.5,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  notesAndTermsText,
                  style: const pw.TextStyle(
                    fontSize: 8.5,
                    color: _slate700,
                    lineSpacing: 1.8,
                  ),
                ),
                pw.SizedBox(height: 12),
              ],
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(color: _slate200, width: 0.8),
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: qrData,
                      width: 48,
                      height: 48,
                      color: _navy,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: pw.Text(
                      isSwahili
                          ? 'Changanua QR kuthibitisha uhalali wa ankara hii.'
                          : 'Scan QR code to verify document details.',
                      style:
                          const pw.TextStyle(fontSize: 7.5, color: _slate500),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 24),
        // Official Stamp & Signature Block
        pw.Expanded(
          flex: 5,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _slate200, width: 0.8),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  isSwahili
                      ? 'KWA AJILI YA: ${organizationName.toUpperCase()}'
                      : 'FOR: ${organizationName.toUpperCase()}',
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _slate500,
                  ),
                ),
                pw.SizedBox(height: 28),
                pw.Divider(color: _slate700, height: 1, thickness: 0.7),
                pw.SizedBox(height: 4),
                if (signatoryName.isNotEmpty)
                  pw.Text(
                    signatoryName,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _navy,
                    ),
                  ),
                pw.Text(
                  '$signatoryTitle  •  ${isSwahili ? "Sahihi & Muhuri" : "Signature & Official Stamp"}',
                  style: const pw.TextStyle(fontSize: 7.5, color: _slate500),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPageFooter({
    required pw.Context context,
    required Organization organization,
    required CustomerInvoice invoice,
    required bool isSwahili,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _slate200, width: 0.6)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            isSwahili
                ? 'Asante kwa kufanya biashara na ${organization.name}!'
                : 'Thank you for doing business with ${organization.name}!',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _slate500,
            ),
          ),
          pw.Text(
            '${invoice.documentTitle} #${invoice.invoiceNumber}  •  '
            '${isSwahili ? "Ukurasa" : "Page"} ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: _slate500),
          ),
        ],
      ),
    );
  }

  String _resolvePaymentInstructions(
    CustomerInvoice invoice,
    Organization organization,
    bool isSwahili,
  ) {
    if (invoice.paymentInstructions != null &&
        invoice.paymentInstructions!.trim().isNotEmpty) {
      return invoice.paymentInstructions!.trim();
    }

    final lines = <String>[];
    if (organization.bankName != null &&
        organization.bankName!.trim().isNotEmpty) {
      lines.add('Bank: ${organization.bankName!.trim()}');
    }
    if (organization.bankAccountName != null &&
        organization.bankAccountName!.trim().isNotEmpty) {
      lines.add('Account Name: ${organization.bankAccountName!.trim()}');
    }
    if (organization.bankAccountNumber != null &&
        organization.bankAccountNumber!.trim().isNotEmpty) {
      lines.add('Account No: ${organization.bankAccountNumber!.trim()}');
    }
    if (organization.bankBranchOrSwift != null &&
        organization.bankBranchOrSwift!.trim().isNotEmpty) {
      lines.add('Branch / SWIFT: ${organization.bankBranchOrSwift!.trim()}');
    }
    if (organization.mobileMoneyDetails != null &&
        organization.mobileMoneyDetails!.trim().isNotEmpty) {
      lines.add('Mobile Money: ${organization.mobileMoneyDetails!.trim()}');
    }

    if (lines.isNotEmpty) {
      return lines.join('\n');
    }

    return isSwahili
        ? 'Malipo yanaweza kufanyika kwa Benki, Simu (M-Pesa / Tigo Pesa / Airtel Money) au Fedha Taslimu.'
        : 'Payable via Bank Transfer, Mobile Money, or Cash.';
  }

  String _resolveNotesAndTerms(
    CustomerInvoice invoice,
    Organization organization,
  ) {
    final parts = <String>[];
    if (invoice.notes != null && invoice.notes!.trim().isNotEmpty) {
      parts.add(invoice.notes!.trim());
    } else if (organization.invoiceTerms != null &&
        organization.invoiceTerms!.trim().isNotEmpty) {
      parts.add(organization.invoiceTerms!.trim());
    }
    return parts.join('\n');
  }

  String _extractInitials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'JB';
    if (words.length == 1) {
      final w = words.first.toUpperCase();
      return w.length >= 2 ? w.substring(0, 2) : w;
    }
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  PdfColor _statusColor(CustomerInvoice invoice) {
    if (invoice.status == InvoiceStatus.paid) return _green700;
    if (invoice.status == InvoiceStatus.partiallyPaid) return _teal;
    if (invoice.status == InvoiceStatus.voided) return _slate500;
    if (invoice.isOverdue) return _red700;
    return _amber700;
  }

  String _statusLabel(CustomerInvoice invoice, bool isSwahili) {
    if (invoice.status == InvoiceStatus.paid) {
      return isSwahili ? 'IMELIPWA' : 'PAID';
    }
    if (invoice.status == InvoiceStatus.partiallyPaid) {
      return isSwahili ? 'IMELIPWA NUSU' : 'PARTIAL';
    }
    if (invoice.status == InvoiceStatus.voided) {
      return isSwahili ? 'IMEFUTWA' : 'VOID';
    }
    if (invoice.isOverdue) {
      return isSwahili ? 'IMECHELEWA' : 'OVERDUE';
    }
    return isSwahili ? 'INASUBIRI MALIPO' : 'UNPAID';
  }
}
