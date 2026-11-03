import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../settings/data/organization_repository.dart';
import '../../domain/delivery_note.dart';
import '../../domain/document_template.dart';
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

  String _resolvePaymentInstructions(
    CustomerInvoice invoice,
    Organization? organization,
    bool isSwahili,
  ) {
    if (invoice.paymentInstructions != null &&
        invoice.paymentInstructions!.trim().isNotEmpty) {
      return invoice.paymentInstructions!.trim();
    }
    if (organization != null && organization.paymentAccounts.isNotEmpty) {
      return organization.formattedPaymentInstructions;
    }
    final lines = <String>[];
    if (organization?.bankName != null &&
        organization!.bankName!.trim().isNotEmpty) {
      lines.add('Bank: ${organization.bankName!.trim()}');
    }
    if (organization?.bankAccountName != null &&
        organization!.bankAccountName!.trim().isNotEmpty) {
      lines.add('Account Name: ${organization.bankAccountName!.trim()}');
    }
    if (organization?.bankAccountNumber != null &&
        organization!.bankAccountNumber!.trim().isNotEmpty) {
      lines.add('Account No: ${organization.bankAccountNumber!.trim()}');
    }
    if (organization?.bankBranchOrSwift != null &&
        organization!.bankBranchOrSwift!.trim().isNotEmpty) {
      lines.add('Branch / SWIFT: ${organization.bankBranchOrSwift!.trim()}');
    }
    if (organization?.mobileMoneyDetails != null &&
        organization!.mobileMoneyDetails!.trim().isNotEmpty) {
      lines.add('Mobile Money: ${organization.mobileMoneyDetails!.trim()}');
    }
    if (lines.isNotEmpty) return lines.join('\n');
    return isSwahili
        ? 'Lipa kupitia Benki, Simu (M-Pesa / Tigo Pesa / Airtel Money), au Fedha Taslimu.'
        : 'Payable via Bank Transfer, Mobile Money, or Cash.';
  }

  String _resolveNotes(
    CustomerInvoice invoice,
    Organization? organization, [
    String? templateFooterNotes,
  ]) {
    if (invoice.notes != null && invoice.notes!.trim().isNotEmpty) {
      return invoice.notes!.trim();
    }
    if (templateFooterNotes != null && templateFooterNotes.trim().isNotEmpty) {
      return templateFooterNotes.trim();
    }
    if (organization?.invoiceTerms != null &&
        organization!.invoiceTerms!.trim().isNotEmpty) {
      return organization.invoiceTerms!.trim();
    }
    return '';
  }

  // =========================================================================
  // 1. INVOICE - A4 CORPORATE STANDARD PROFILE (MULTI-LAYOUT ENGINE)
  // =========================================================================

  Future<Uint8List> generateInvoiceA4({
    required CustomerInvoice invoice,
    Organization? organization,
    TenantDocumentConfiguration? templateConfig,
    String? primaryHex,
    String? secondaryHex,
    bool isSwahili = false,
  }) async {
    final style = templateConfig?.layoutStyle ??
        InvoiceLayoutStyle.executiveCorporate;
    final effectivePrimaryHex =
        primaryHex ?? templateConfig?.themePrimaryHex ?? style.defaultPrimaryHex;
    final effectiveSecondaryHex = secondaryHex ??
        templateConfig?.themeSecondaryHex ??
        style.defaultSecondaryHex;

    final primaryColor = _parseHex(effectivePrimaryHex, _defaultPrimary);
    final secondaryColor = _parseHex(effectiveSecondaryHex, _defaultSecondary);
    final showLogo = templateConfig?.showLogo ?? true;

    final String orgName =
        (organization?.name != null && organization!.name!.trim().isNotEmpty)
            ? organization.name!.trim()
            : 'Biashara Yetu';
    final currency = invoice.currency.isNotEmpty
        ? invoice.currency
        : (organization?.currency != null &&
                organization!.currency!.trim().isNotEmpty
            ? organization.currency!.trim()
            : 'TZS');

    final document = pw.Document(
      title: '${invoice.documentTitle} ${invoice.number}',
      author: orgName,
      creator: 'Jolinx Business OS',
    );

    final dateFmt = DateFormat('dd MMM yyyy');
    final slashDateFmt = DateFormat('dd/MM/yyyy');
    final numFmt = NumberFormat('#,##0.##');
    String fmtMoney(double amount) => '$currency ${numFmt.format(amount)}';

    final logoImage =
        showLogo ? _decodeLogo(organization?.logoBase64) : null;
    final signatureImage = _decodeLogo(organization?.signatureBase64);
    final letterheadImage = _decodeLogo(organization?.letterheadHeaderBase64);
    final paymentInstructions =
        _resolvePaymentInstructions(invoice, organization, isSwahili);
    final notesAndTerms =
        _resolveNotes(invoice, organization, templateConfig?.footerNotes);
    final signatoryName =
        (invoice.authorizedSignatoryName?.trim().isNotEmpty ?? false)
            ? invoice.authorizedSignatoryName!.trim()
            : ((organization?.authorizedSignatoryName?.trim().isNotEmpty ??
                    false)
                ? organization!.authorizedSignatoryName!.trim()
                : '');
    final signatoryTitle =
        (invoice.authorizedSignatoryTitle?.trim().isNotEmpty ?? false)
            ? invoice.authorizedSignatoryTitle!.trim()
            : ((organization?.authorizedSignatoryTitle?.trim().isNotEmpty ??
                    false)
                ? organization!.authorizedSignatoryTitle!.trim()
                : (isSwahili
                    ? 'Sahihi Iliyoidhinishwa'
                    : 'Authorized Signatory'));

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

    final words = orgName
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final initials = words.isEmpty
        ? 'JB'
        : words.length == 1
            ? (words.first.length >= 2
                ? words.first.substring(0, 2).toUpperCase()
                : words.first.toUpperCase())
            : '${words[0][0]}${words[1][0]}'.toUpperCase();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) => style == InvoiceLayoutStyle.modernRibbon
            ? _buildModernRibbonFooter(
                context: context,
                organization: organization,
                orgName: orgName,
                invoice: invoice,
                isSwahili: isSwahili,
              )
            : pw.Container(
                margin: const pw.EdgeInsets.only(top: 14),
                padding: const pw.EdgeInsets.only(top: 8),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: _slate200, width: 0.5),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '$orgName  |  ${invoice.documentTitle} #${invoice.number}',
                      style: const pw.TextStyle(color: _slate500, fontSize: 8),
                    ),
                    pw.Text(
                      '${isSwahili ? "Ukurasa" : "Page"} ${context.pageNumber} / ${context.pagesCount}',
                      style: const pw.TextStyle(color: _slate500, fontSize: 8),
                    ),
                  ],
                ),
              ),
        build: (context) {
          switch (style) {
            case InvoiceLayoutStyle.modernRibbon:
              return _buildModernRibbonPdfBody(
                invoice: invoice,
                organization: organization,
                orgName: orgName,
                initials: initials,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                showLogo: showLogo,
                logoImage: logoImage,
                signatureImage: signatureImage,
                slashDateFmt: slashDateFmt,
                numFmt: numFmt,
                currency: currency,
                fmtMoney: fmtMoney,
                paymentInstructions: paymentInstructions,
                notesAndTerms: notesAndTerms,
                signatoryName: signatoryName,
                signatoryTitle: signatoryTitle,
                isSwahili: isSwahili,
              );
            case InvoiceLayoutStyle.classicGrid:
              return _buildClassicGridPdfBody(
                invoice: invoice,
                organization: organization,
                orgName: orgName,
                initials: initials,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                showLogo: showLogo,
                logoImage: logoImage,
                signatureImage: signatureImage,
                slashDateFmt: slashDateFmt,
                numFmt: numFmt,
                currency: currency,
                fmtMoney: fmtMoney,
                paymentInstructions: paymentInstructions,
                notesAndTerms: notesAndTerms,
                signatoryName: signatoryName,
                signatoryTitle: signatoryTitle,
                isSwahili: isSwahili,
              );
            case InvoiceLayoutStyle.customLetterhead:
              return _buildCustomLetterheadPdfBody(
                invoice: invoice,
                organization: organization,
                orgName: orgName,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                letterheadImage: letterheadImage,
                signatureImage: signatureImage,
                dateFmt: dateFmt,
                numFmt: numFmt,
                currency: currency,
                fmtMoney: fmtMoney,
                paymentInstructions: paymentInstructions,
                notesAndTerms: notesAndTerms,
                signatoryName: signatoryName,
                signatoryTitle: signatoryTitle,
                qrData: qrData,
                isSwahili: isSwahili,
              );
            case InvoiceLayoutStyle.executiveCorporate:
              return _buildExecutiveCorporatePdfBody(
                invoice: invoice,
                organization: organization,
                orgName: orgName,
                initials: initials,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                showLogo: showLogo,
                logoImage: logoImage,
                signatureImage: signatureImage,
                dateFmt: dateFmt,
                numFmt: numFmt,
                currency: currency,
                fmtMoney: fmtMoney,
                paymentInstructions: paymentInstructions,
                notesAndTerms: notesAndTerms,
                signatoryName: signatoryName,
                signatoryTitle: signatoryTitle,
                qrData: qrData,
                isSwahili: isSwahili,
              );
          }
        },
      ),
    );

    return document.save();
  }

  // ── 1A. MODERN RIBBON PDF BODY (Matches the uploaded Gold & Charcoal sample) ──
  List<pw.Widget> _buildModernRibbonPdfBody({
    required CustomerInvoice invoice,
    required Organization? organization,
    required String orgName,
    required String initials,
    required PdfColor primaryColor,
    required PdfColor secondaryColor,
    required bool showLogo,
    required pw.MemoryImage? logoImage,
    required pw.MemoryImage? signatureImage,
    required DateFormat slashDateFmt,
    required NumberFormat numFmt,
    required String currency,
    required String Function(double) fmtMoney,
    required String paymentInstructions,
    required String notesAndTerms,
    required String signatoryName,
    required String signatoryTitle,
    required bool isSwahili,
  }) {
    final isPrimaryLight = primaryColor.luminance > 0.55;
    final ribbonFg = isPrimaryLight ? _defaultPrimary : PdfColors.white;

    return [
      // Top Row: Stacked Logo + Business Name (Left) | "Invoice #2022435" (Right)
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            flex: 6,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (showLogo) ...[
                  if (logoImage != null)
                    pw.Container(
                      width: 60,
                      height: 60,
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    )
                  else
                    pw.Container(
                      width: 48,
                      height: 48,
                      alignment: pw.Alignment.center,
                      decoration: pw.BoxDecoration(
                        color: primaryColor,
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Text(
                        initials,
                        style: pw.TextStyle(
                          color: ribbonFg,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  pw.SizedBox(height: 8),
                ],
                pw.Text(
                  orgName,
                  style: pw.TextStyle(
                    color: _defaultPrimary,
                    fontSize: 17,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (organization?.taxId != null &&
                    organization!.taxId!.trim().isNotEmpty)
                  pw.Text(
                    'TIN: ${organization.taxId!.trim()}',
                    style: const pw.TextStyle(color: _slate500, fontSize: 9),
                  ),
              ],
            ),
          ),
          pw.SizedBox(width: 14),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Invoice ${invoice.number}',
                style: const pw.TextStyle(
                  color: _defaultPrimary,
                  fontSize: 16,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                invoice.documentTitle,
                style: const pw.TextStyle(color: _slate500, fontSize: 9.5),
              ),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 18),

      // Second Row: BILL TO (Left) | Issue date / Due date / Reference (Right)
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 6,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  isSwahili ? 'KWA MTEJA (BILL TO)' : 'BILL TO',
                  style: pw.TextStyle(
                    color: _defaultPrimary,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  invoice.customerLabel,
                  style: pw.TextStyle(
                    color: _defaultPrimary,
                    fontSize: 11.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (invoice.customerAttention != null &&
                    invoice.customerAttention!.trim().isNotEmpty)
                  pw.Text(
                    'Attn: ${invoice.customerAttention!.trim()}',
                    style: const pw.TextStyle(color: _slate700, fontSize: 9),
                  ),
                if (invoice.customerAddress != null &&
                    invoice.customerAddress!.trim().isNotEmpty)
                  pw.Text(
                    invoice.customerAddress!.trim(),
                    style: const pw.TextStyle(color: _slate700, fontSize: 9),
                  ),
                if (invoice.customerPhone != null &&
                    invoice.customerPhone!.trim().isNotEmpty)
                  pw.Text(
                    invoice.customerPhone!.trim(),
                    style: const pw.TextStyle(color: _slate700, fontSize: 9),
                  ),
                if (invoice.customerEmail != null &&
                    invoice.customerEmail!.trim().isNotEmpty)
                  pw.Text(
                    invoice.customerEmail!.trim(),
                    style: const pw.TextStyle(color: _slate700, fontSize: 9),
                  ),
                if (invoice.customerTin != null &&
                    invoice.customerTin!.trim().isNotEmpty)
                  pw.Text(
                    'TIN: ${invoice.customerTin!.trim()}',
                    style: pw.TextStyle(
                      color: _slate700,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            flex: 4,
            child: pw.Column(
              children: [
                _buildTotalRow(
                  isSwahili ? 'Tarehe:' : 'Issue date:',
                  slashDateFmt.format(invoice.issueDate.toLocal()),
                  isBold: true,
                ),
                _buildTotalRow(
                  isSwahili ? 'Mwisho:' : 'Due date:',
                  invoice.dueDate != null
                      ? slashDateFmt.format(invoice.dueDate!.toLocal())
                      : slashDateFmt.format(invoice.issueDate.toLocal()),
                  isBold: true,
                ),
                pw.SizedBox(height: 6),
                _buildTotalRow(
                  isSwahili ? 'Kumbukumbu:' : 'Reference:',
                  (invoice.referenceNumber != null &&
                          invoice.referenceNumber!.trim().isNotEmpty)
                      ? invoice.referenceNumber!.trim()
                      : invoice.number,
                  isBold: true,
                ),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 16),

      // Third Row: 4-Column Colored Highlight Ribbon
      pw.Row(
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: primaryColor,
                border: const pw.Border(
                  right: pw.BorderSide(color: PdfColors.white, width: 1),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    isSwahili ? 'Na. ya Ankara' : 'Invoice No.',
                    style: pw.TextStyle(color: ribbonFg, fontSize: 8.5),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    invoice.number,
                    style: pw.TextStyle(
                      color: ribbonFg,
                      fontSize: 11.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: primaryColor,
                border: const pw.Border(
                  right: pw.BorderSide(color: PdfColors.white, width: 1),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    isSwahili ? 'Tarehe' : 'Issue date',
                    style: pw.TextStyle(color: ribbonFg, fontSize: 8.5),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    slashDateFmt.format(invoice.issueDate.toLocal()),
                    style: pw.TextStyle(
                      color: ribbonFg,
                      fontSize: 11.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: primaryColor,
                border: const pw.Border(
                  right: pw.BorderSide(color: PdfColors.white, width: 1),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    isSwahili ? 'Mwisho' : 'Due date',
                    style: pw.TextStyle(color: ribbonFg, fontSize: 8.5),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    invoice.dueDate != null
                        ? slashDateFmt.format(invoice.dueDate!.toLocal())
                        : '-',
                    style: pw.TextStyle(
                      color: ribbonFg,
                      fontSize: 11.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          pw.Expanded(
            flex: 4,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(10),
              color: secondaryColor,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    isSwahili
                        ? 'Jumla ($currency)'
                        : 'Total due ($currency)',
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 8.5,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    numFmt.format(
                      invoice.balanceDue > 0
                          ? invoice.balanceDue
                          : invoice.totalAmount,
                    ),
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 12.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 16),

      // Fourth Row: Minimalist Horizontal-Rule Item Table
      pw.TableHelper.fromTextArray(
        headers: [
          isSwahili ? 'Maelezo' : 'Description',
          isSwahili ? 'Idadi' : 'Quantity',
          isSwahili ? 'Bei ($currency)' : 'Unit price ($currency)',
          isSwahili ? 'Jumla ($currency)' : 'Amount ($currency)',
        ],
        data: [
          for (final line in invoice.lines)
            [
              line.description,
              numFmt.format(line.quantity),
              numFmt.format(line.unitPrice),
              numFmt.format(line.lineTotal),
            ],
        ],
        border: const pw.TableBorder(
          bottom: pw.BorderSide(color: _slate200, width: 0.7),
          horizontalInside: pw.BorderSide(color: _slate200, width: 0.6),
        ),
        headerStyle: pw.TextStyle(
          color: _defaultPrimary,
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
        ),
        headerHeight: 22,
        cellHeight: 22,
        cellStyle: const pw.TextStyle(color: _defaultPrimary, fontSize: 9),
        columnWidths: {
          0: const pw.FlexColumnWidth(4.5),
          1: const pw.FlexColumnWidth(1.5),
          2: const pw.FlexColumnWidth(2.0),
          3: const pw.FlexColumnWidth(2.0),
        },
        cellAlignments: {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.centerRight,
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
        },
      ),
      pw.SizedBox(height: 10),

      // Totals Section
      _buildTotalRow(
        isSwahili ? 'Jumla Ndogo (Subtotal):' : 'Subtotal:',
        fmtMoney(invoice.subtotal),
      ),
      if (invoice.discountAmount > 0)
        _buildTotalRow(
          isSwahili ? 'Punguzo (Discount):' : 'Discount:',
          '-${fmtMoney(invoice.discountAmount)}',
          valueColor: _amber700,
        ),
      pw.SizedBox(height: 4),
      _buildTotalRow(
        isSwahili ? 'Jumla ($currency):' : 'Total ($currency):',
        fmtMoney(invoice.totalAmount),
        isBold: true,
        fontSize: 10.5,
      ),
      if (invoice.amountPaid > 0) ...[
        _buildTotalRow(
          isSwahili ? 'Imelipwa (Paid):' : 'Amount Paid:',
          '-${fmtMoney(invoice.amountPaid)}',
          valueColor: _green700,
        ),
        _buildTotalRow(
          isSwahili ? 'Salio (Balance Due):' : 'Balance Due:',
          fmtMoney(invoice.balanceDue),
          isBold: true,
        ),
      ],

      _buildPdfPaymentHistoryTable(
        invoice: invoice,
        numFmt: numFmt,
        currency: currency,
        isSwahili: isSwahili,
      ),

      pw.SizedBox(height: 18),

      // Payment Instructions (Left) + "Issued by, signature:" (Right)
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 6,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  isSwahili ? 'Maelekezo ya Malipo:' : 'Payment Details:',
                  style: pw.TextStyle(
                    color: _slate700,
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  paymentInstructions,
                  style: const pw.TextStyle(
                    color: _slate700,
                    fontSize: 8.5,
                    lineSpacing: 1.5,
                  ),
                ),
                if (notesAndTerms.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Text(
                    notesAndTerms,
                    style: const pw.TextStyle(color: _slate500, fontSize: 8),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            flex: 4,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  isSwahili
                      ? 'Imetolewa na, sahihi:'
                      : 'Issued by, signature:',
                  style: pw.TextStyle(
                    color: _defaultPrimary,
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                if (signatureImage != null)
                  pw.Container(
                    height: 46,
                    width: 130,
                    alignment: pw.Alignment.centerRight,
                    child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
                  )
                else if (signatoryName.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 6),
                    child: pw.Text(
                      signatoryName,
                      style: pw.TextStyle(
                        color: _defaultPrimary,
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  )
                else
                  pw.SizedBox(height: 24),
                pw.Container(width: 120, height: 0.7, color: _slate200),
                pw.SizedBox(height: 3),
                pw.Text(
                  signatoryName.isNotEmpty ? signatoryName : signatoryTitle,
                  style: const pw.TextStyle(color: _slate500, fontSize: 8),
                ),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  pw.Widget _buildModernRibbonFooter({
    required pw.Context context,
    required Organization? organization,
    required String orgName,
    required CustomerInvoice invoice,
    required bool isSwahili,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (organization?.phone != null &&
                  organization!.phone!.trim().isNotEmpty)
                pw.Text(
                  'Tel: ${organization.phone!.trim()}',
                  style: const pw.TextStyle(
                    color: _defaultPrimary,
                    fontSize: 8.5,
                  ),
                ),
              if (organization?.website != null &&
                  organization!.website!.trim().isNotEmpty)
                pw.Text(
                  organization.website!.trim(),
                  style: const pw.TextStyle(
                    color: _defaultPrimary,
                    fontSize: 8.5,
                  ),
                ),
              if (organization?.email != null &&
                  organization!.email!.trim().isNotEmpty)
                pw.Text(
                  organization.email!.trim(),
                  style: const pw.TextStyle(
                    color: _defaultPrimary,
                    fontSize: 8.5,
                  ),
                ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Divider(color: _slate700, thickness: 0.8),
          pw.SizedBox(height: 3),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                [
                  orgName,
                  if (organization?.address != null &&
                      organization!.address!.trim().isNotEmpty)
                    organization.address!.trim(),
                ].join('  |  '),
                style: const pw.TextStyle(color: _slate700, fontSize: 8),
              ),
              pw.Text(
                '${isSwahili ? "Ukurasa" : "Page"} ${context.pageNumber} / ${context.pagesCount}',
                style: const pw.TextStyle(color: _slate500, fontSize: 8),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 1B. CLASSIC WHOLESALE GRID PDF BODY ──
  List<pw.Widget> _buildClassicGridPdfBody({
    required CustomerInvoice invoice,
    required Organization? organization,
    required String orgName,
    required String initials,
    required PdfColor primaryColor,
    required PdfColor secondaryColor,
    required bool showLogo,
    required pw.MemoryImage? logoImage,
    required pw.MemoryImage? signatureImage,
    required DateFormat slashDateFmt,
    required NumberFormat numFmt,
    required String currency,
    required String Function(double) fmtMoney,
    required String paymentInstructions,
    required String notesAndTerms,
    required String signatoryName,
    required String signatoryTitle,
    required bool isSwahili,
  }) {
    return [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        color: primaryColor,
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              invoice.documentTitle.toUpperCase(),
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'NO: ${invoice.number}',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 11.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: primaryColor, width: 0.9),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    orgName.toUpperCase(),
                    style: pw.TextStyle(
                      color: primaryColor,
                      fontSize: 11.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (organization?.address != null &&
                      organization!.address!.trim().isNotEmpty)
                    pw.Text(
                      organization.address!.trim(),
                      style: const pw.TextStyle(color: _slate700, fontSize: 9),
                    ),
                  if (organization?.phone != null &&
                      organization!.phone!.trim().isNotEmpty)
                    pw.Text(
                      'Tel: ${organization.phone!.trim()}',
                      style: const pw.TextStyle(color: _slate700, fontSize: 9),
                    ),
                  if (organization?.taxId != null &&
                      organization!.taxId!.trim().isNotEmpty)
                    pw.Text(
                      'TIN: ${organization.taxId!.trim()}',
                      style: pw.TextStyle(
                        color: _slate700,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
            pw.SizedBox(width: 14),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    isSwahili ? 'MTEJA (CUSTOMER):' : 'CUSTOMER / BUYER:',
                    style: pw.TextStyle(
                      color: secondaryColor,
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    invoice.customerLabel,
                    style: pw.TextStyle(
                      color: _defaultPrimary,
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (invoice.customerAddress != null &&
                      invoice.customerAddress!.trim().isNotEmpty)
                    pw.Text(
                      invoice.customerAddress!.trim(),
                      style: const pw.TextStyle(color: _slate700, fontSize: 9),
                    ),
                  if (invoice.customerPhone != null &&
                      invoice.customerPhone!.trim().isNotEmpty)
                    pw.Text(
                      'Tel: ${invoice.customerPhone!.trim()}',
                      style: const pw.TextStyle(color: _slate700, fontSize: 9),
                    ),
                  pw.Text(
                    '${isSwahili ? "Tarehe" : "Date"}: ${slashDateFmt.format(invoice.issueDate.toLocal())}',
                    style: pw.TextStyle(
                      color: _defaultPrimary,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: [
          '#',
          isSwahili ? 'Bidhaa / Maelezo' : 'Description',
          isSwahili ? 'Idadi' : 'Qty',
          isSwahili ? 'Bei ($currency)' : 'Rate',
          isSwahili ? 'Jumla ($currency)' : 'Amount',
        ],
        data: [
          for (var i = 0; i < invoice.lines.length; i++)
            [
              '${i + 1}',
              invoice.lines[i].description,
              numFmt.format(invoice.lines[i].quantity),
              numFmt.format(invoice.lines[i].unitPrice),
              numFmt.format(invoice.lines[i].lineTotal),
            ],
        ],
        border: pw.TableBorder.all(color: primaryColor, width: 0.8),
        headerStyle: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 8.5,
          fontWeight: pw.FontWeight.bold,
        ),
        headerDecoration: pw.BoxDecoration(color: primaryColor),
        headerHeight: 22,
        cellHeight: 20,
        cellStyle: const pw.TextStyle(color: _defaultPrimary, fontSize: 8.5),
        columnWidths: {
          0: const pw.FixedColumnWidth(24),
          1: const pw.FlexColumnWidth(4.2),
          2: const pw.FlexColumnWidth(1.3),
          3: const pw.FlexColumnWidth(1.8),
          4: const pw.FlexColumnWidth(2.0),
        },
        cellAlignments: {
          0: pw.Alignment.center,
          1: pw.Alignment.centerLeft,
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
          4: pw.Alignment.centerRight,
        },
      ),
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: _slate50,
          border: pw.Border.all(color: primaryColor, width: 0.8),
        ),
        child: pw.Column(
          children: [
            _buildTotalRow(
              isSwahili ? 'JUMLA KUU ($currency):' : 'TOTAL ($currency):',
              fmtMoney(invoice.totalAmount),
              isBold: true,
              fontSize: 10.5,
              valueColor: primaryColor,
            ),
            if (invoice.amountPaid > 0) ...[
              _buildTotalRow(
                isSwahili ? 'Imelipwa (Paid):' : 'Amount Paid:',
                '-${fmtMoney(invoice.amountPaid)}',
                valueColor: _green700,
              ),
              _buildTotalRow(
                isSwahili ? 'Salio (Balance Due):' : 'Balance Due:',
                fmtMoney(invoice.balanceDue),
                isBold: true,
              ),
            ],
          ],
        ),
      ),

      _buildPdfPaymentHistoryTable(
        invoice: invoice,
        numFmt: numFmt,
        currency: currency,
        isSwahili: isSwahili,
      ),

      pw.SizedBox(height: 12),
      pw.Text(
        paymentInstructions,
        style: const pw.TextStyle(color: _slate700, fontSize: 8.5),
      ),
      pw.SizedBox(height: 22),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (signatureImage != null)
                  pw.Container(
                    height: 40,
                    child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
                  )
                else
                  pw.SizedBox(height: 24),
                pw.Divider(color: primaryColor, thickness: 0.8),
                pw.Text(
                  isSwahili
                      ? 'Imetolewa Na (Sahihi & Muhuri)'
                      : 'Prepared & Authorized By',
                  style: pw.TextStyle(
                    color: _slate700,
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 24),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(height: 24),
                pw.Divider(color: primaryColor, thickness: 0.8),
                pw.Text(
                  isSwahili
                      ? 'Imepokelewa Na Mteja (Sahihi)'
                      : 'Received & Accepted By Customer',
                  style: pw.TextStyle(
                    color: _slate700,
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  // ── 1C. CUSTOM LETTERHEAD / PRE-PRINTED PAPER PDF BODY ──
  List<pw.Widget> _buildCustomLetterheadPdfBody({
    required CustomerInvoice invoice,
    required Organization? organization,
    required String orgName,
    required PdfColor primaryColor,
    required PdfColor secondaryColor,
    required pw.MemoryImage? letterheadImage,
    required pw.MemoryImage? signatureImage,
    required DateFormat dateFmt,
    required NumberFormat numFmt,
    required String currency,
    required String Function(double) fmtMoney,
    required String paymentInstructions,
    required String notesAndTerms,
    required String signatoryName,
    required String signatoryTitle,
    required String qrData,
    required bool isSwahili,
  }) {
    final topMarginMm = organization?.prePrintedTopMarginMm ?? 38.0;
    return [
      if (organization?.hideHeaderForPrePrinted ?? false)
        pw.SizedBox(height: topMarginMm * PdfPageFormat.mm)
      else if (letterheadImage != null) ...[
        pw.Container(
          width: double.infinity,
          child: pw.Image(letterheadImage, fit: pw.BoxFit.fitWidth),
        ),
        pw.SizedBox(height: 12),
      ],
      ..._buildExecutiveCorporatePdfBody(
        invoice: invoice,
        organization: organization,
        orgName: orgName,
        initials: 'JB',
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
        showLogo: false,
        logoImage: null,
        signatureImage: signatureImage,
        dateFmt: dateFmt,
        numFmt: numFmt,
        currency: currency,
        fmtMoney: fmtMoney,
        paymentInstructions: paymentInstructions,
        notesAndTerms: notesAndTerms,
        signatoryName: signatoryName,
        signatoryTitle: signatoryTitle,
        qrData: qrData,
        isSwahili: isSwahili,
        omitSellerHeader: (organization?.hideHeaderForPrePrinted ?? false) ||
            letterheadImage != null,
      ),
    ];
  }

  // ── 1D. EXECUTIVE CORPORATE PDF BODY ──
  List<pw.Widget> _buildExecutiveCorporatePdfBody({
    required CustomerInvoice invoice,
    required Organization? organization,
    required String orgName,
    required String initials,
    required PdfColor primaryColor,
    required PdfColor secondaryColor,
    required bool showLogo,
    required pw.MemoryImage? logoImage,
    required pw.MemoryImage? signatureImage,
    required DateFormat dateFmt,
    required NumberFormat numFmt,
    required String currency,
    required String Function(double) fmtMoney,
    required String paymentInstructions,
    required String notesAndTerms,
    required String signatoryName,
    required String signatoryTitle,
    required String qrData,
    required bool isSwahili,
    bool omitSellerHeader = false,
  }) {
    return [
      if (!omitSellerHeader) ...[
        // Header Accent Ribbon
        pw.Container(
          height: 5,
          decoration: pw.BoxDecoration(
            color: primaryColor,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
          ),
        ),
        pw.SizedBox(height: 14),

        // Header Title and Organization Info
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              flex: 6,
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (showLogo) ...[
                    if (logoImage != null)
                      pw.Container(
                        width: 48,
                        height: 48,
                        margin: const pw.EdgeInsets.only(right: 12),
                        padding: const pw.EdgeInsets.all(3),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: _slate200, width: 0.8),
                          borderRadius:
                              const pw.BorderRadius.all(pw.Radius.circular(6)),
                        ),
                        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                      )
                    else
                      pw.Container(
                        width: 44,
                        height: 44,
                        margin: const pw.EdgeInsets.only(right: 12),
                        alignment: pw.Alignment.center,
                        decoration: pw.BoxDecoration(
                          color: primaryColor,
                          borderRadius:
                              const pw.BorderRadius.all(pw.Radius.circular(6)),
                        ),
                        child: pw.Text(
                          initials,
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 15,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          orgName.toUpperCase(),
                          style: pw.TextStyle(
                            color: primaryColor,
                            fontSize: 15,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        if (organization?.taxId != null &&
                            organization!.taxId!.trim().isNotEmpty)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 2),
                            child: pw.Text(
                              'TIN: ${organization.taxId!.trim()}',
                              style: pw.TextStyle(
                                color: secondaryColor,
                                fontSize: 9.5,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        if (organization?.address != null &&
                            organization!.address!.trim().isNotEmpty)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 2),
                            child: pw.Text(
                              organization.address!.trim(),
                              style: const pw.TextStyle(
                                color: _slate700,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        if (organization?.phone != null &&
                            organization!.phone!.trim().isNotEmpty)
                          pw.Text(
                            'Tel: ${organization.phone!.trim()}',
                            style: const pw.TextStyle(
                              color: _slate700,
                              fontSize: 9,
                            ),
                          ),
                        if (organization?.email != null &&
                            organization!.email!.trim().isNotEmpty)
                          pw.Text(
                            organization.email!.trim(),
                            style: const pw.TextStyle(
                              color: _slate700,
                              fontSize: 9,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: pw.BoxDecoration(
                    color: primaryColor,
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    invoice.documentTitle.toUpperCase(),
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '#${invoice.number}',
                  style: pw.TextStyle(
                    color: _slate700,
                    fontSize: 11.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  '${isSwahili ? "Tarehe" : "Issue Date"}: ${dateFmt.format(invoice.issueDate.toLocal())}',
                  style: const pw.TextStyle(color: _slate500, fontSize: 8.5),
                ),
                if (invoice.dueDate != null)
                  pw.Text(
                    '${isSwahili ? "Mwisho" : "Due Date"}: ${dateFmt.format(invoice.dueDate!.toLocal())}',
                    style: pw.TextStyle(
                      color: invoice.isOverdue ? _red700 : _slate500,
                      fontSize: 8.5,
                      fontWeight: invoice.isOverdue
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                    ),
                  ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 14),
      ],

      // Bill To & Terms Card
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: _slate50,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          border: pw.Border.all(color: _slate200, width: 0.6),
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
                    isSwahili
                        ? 'KWA MTEJA / MPOKEAJI (BILL TO):'
                        : 'BILL TO (RECEIVER):',
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
                      fontSize: 12.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (invoice.customerAttention != null &&
                      invoice.customerAttention!.trim().isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2),
                      child: pw.Text(
                        'Attn: ${invoice.customerAttention!.trim()}',
                        style: pw.TextStyle(
                          color: _slate700,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  if (invoice.customerAddress != null &&
                      invoice.customerAddress!.trim().isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 1.5),
                      child: pw.Text(
                        invoice.customerAddress!.trim(),
                        style: const pw.TextStyle(
                          color: _slate700,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  if (invoice.customerPhone != null &&
                      invoice.customerPhone!.trim().isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 1.5),
                      child: pw.Text(
                        'Tel: ${invoice.customerPhone!.trim()}',
                        style: const pw.TextStyle(
                          color: _slate700,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  if (invoice.customerEmail != null &&
                      invoice.customerEmail!.trim().isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 1.5),
                      child: pw.Text(
                        'Email: ${invoice.customerEmail!.trim()}',
                        style: const pw.TextStyle(
                          color: _slate700,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  if (invoice.customerTin != null &&
                      invoice.customerTin!.trim().isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2),
                      child: pw.Text(
                        'TIN: ${invoice.customerTin!.trim()}',
                        style: pw.TextStyle(
                          color: secondaryColor,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                if (invoice.referenceNumber != null &&
                    invoice.referenceNumber!.trim().isNotEmpty)
                  pw.Text(
                    '${isSwahili ? "Kumbukumbu" : "Ref / PO"}: ${invoice.referenceNumber!.trim()}',
                    style: pw.TextStyle(
                      color: _slate700,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                if (invoice.paymentTerms != null &&
                    invoice.paymentTerms!.trim().isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 2),
                    child: pw.Text(
                      '${isSwahili ? "Masharti" : "Terms"}: ${invoice.paymentTerms!.trim()}',
                      style: const pw.TextStyle(
                        color: _slate500,
                        fontSize: 8.5,
                      ),
                    ),
                  ),
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
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
                    invoice.status == InvoiceStatus.paid
                        ? (isSwahili ? 'IMELIPWA' : 'PAID')
                        : invoice.status == InvoiceStatus.partiallyPaid
                            ? (isSwahili ? 'IMELIPWA NUSU' : 'PARTIAL')
                            : (isSwahili ? 'INASUBIRI MALIPO' : 'UNPAID'),
                    style: pw.TextStyle(
                      fontSize: 8,
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
      pw.SizedBox(height: 14),

      // Items Table
      pw.TableHelper.fromTextArray(
        headers: [
          '#',
          isSwahili ? 'Bidhaa / Huduma' : 'Item Description',
          isSwahili ? 'Kipimo' : 'Unit',
          isSwahili ? 'Idadi' : 'Qty',
          isSwahili ? 'Bei ($currency)' : 'Unit Price',
          isSwahili ? 'Punguzo' : 'Discount',
          isSwahili ? 'Jumla ($currency)' : 'Line Total',
        ],
        data: [
          for (var i = 0; i < invoice.lines.length; i++)
            [
              '${i + 1}',
              invoice.lines[i].description,
              invoice.lines[i].unitOfMeasure.isNotEmpty
                  ? invoice.lines[i].unitOfMeasure
                  : 'Pcs',
              numFmt.format(invoice.lines[i].quantity),
              numFmt.format(invoice.lines[i].unitPrice),
              invoice.lines[i].discountAmount > 0
                  ? '-${numFmt.format(invoice.lines[i].discountAmount)}'
                  : '-',
              numFmt.format(invoice.lines[i].lineTotal),
            ],
        ],
        border: pw.TableBorder.all(color: _slate200, width: 0.5),
        headerStyle: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 8.5,
          fontWeight: pw.FontWeight.bold,
        ),
        headerDecoration: pw.BoxDecoration(color: primaryColor),
        headerHeight: 24,
        cellHeight: 22,
        cellStyle: const pw.TextStyle(color: _slate700, fontSize: 8.5),
        columnWidths: {
          0: const pw.FixedColumnWidth(24),
          1: const pw.FlexColumnWidth(3.5),
          2: const pw.FlexColumnWidth(1.0),
          3: const pw.FlexColumnWidth(0.9),
          4: const pw.FlexColumnWidth(1.4),
          5: const pw.FlexColumnWidth(1.1),
          6: const pw.FlexColumnWidth(1.5),
        },
        cellAlignments: {
          0: pw.Alignment.center,
          1: pw.Alignment.centerLeft,
          2: pw.Alignment.center,
          3: pw.Alignment.centerRight,
          4: pw.Alignment.centerRight,
          5: pw.Alignment.centerRight,
          6: pw.Alignment.centerRight,
        },
        oddRowDecoration: const pw.BoxDecoration(color: _slate50),
      ),
      pw.SizedBox(height: 14),

      // Financial Summary + Payment Instructions
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Payment Instructions & Terms
          pw.Expanded(
            flex: 6,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: _slate50,
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: _slate200, width: 0.6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    isSwahili
                        ? 'MAELEKEZO YA MALIPO (PAYMENT DETAILS)'
                        : 'PAYMENT INSTRUCTIONS',
                    style: pw.TextStyle(
                      color: primaryColor,
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    paymentInstructions,
                    style: const pw.TextStyle(
                      color: _slate700,
                      fontSize: 8.5,
                      lineSpacing: 2,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    isSwahili
                        ? 'Taja namba ya ankara #${invoice.number} unapofanya malipo.'
                        : 'Please quote Invoice #${invoice.number} when making payment.',
                    style: pw.TextStyle(
                      color: secondaryColor,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (notesAndTerms.isNotEmpty) ...[
                    pw.SizedBox(height: 8),
                    pw.Divider(color: _slate200, thickness: 0.5),
                    pw.Text(
                      isSwahili
                          ? 'MASHARTI NA MAELEZO:'
                          : 'TERMS & NOTES:',
                      style: pw.TextStyle(
                        color: _slate500,
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      notesAndTerms,
                      style: const pw.TextStyle(
                        color: _slate700,
                        fontSize: 8,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          pw.SizedBox(width: 14),
          // Totals Table
          pw.Expanded(
            flex: 5,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: _slate50,
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: _slate200, width: 0.6),
              ),
              child: pw.Column(
                children: [
                  _buildTotalRow(
                    isSwahili ? 'Jumla Ndogo:' : 'Subtotal:',
                    fmtMoney(invoice.subtotal),
                  ),
                  if (invoice.discountAmount > 0)
                    _buildTotalRow(
                      isSwahili ? 'Punguzo:' : 'Discount:',
                      '-${fmtMoney(invoice.discountAmount)}',
                      valueColor: _amber700,
                    ),
                  pw.Divider(color: _slate200, thickness: 0.6),
                  _buildTotalRow(
                    isSwahili ? 'JUMLA KUU:' : 'TOTAL AMOUNT:',
                    fmtMoney(invoice.totalAmount),
                    isBold: true,
                    fontSize: 10.5,
                    valueColor: primaryColor,
                  ),
                  if (invoice.amountPaid > 0)
                    _buildTotalRow(
                      isSwahili ? 'Kiasi Kilicholipwa:' : 'Amount Paid:',
                      '-${fmtMoney(invoice.amountPaid)}',
                      valueColor: _green700,
                    ),
                  pw.SizedBox(height: 6),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: pw.BoxDecoration(
                      color: primaryColor,
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          isSwahili ? 'SALIO LA KULIPWA:' : 'BALANCE DUE:',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          fmtMoney(invoice.balanceDue),
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      _buildPdfPaymentHistoryTable(
        invoice: invoice,
        numFmt: numFmt,
        currency: currency,
        isSwahili: isSwahili,
      ),

      pw.SizedBox(height: 16),

      // QR Code + Authorized Signatory / Official Stamp Box
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Container(
            width: 58,
            height: 58,
            padding: const pw.EdgeInsets.all(3),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _slate200, width: 0.6),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: qrData,
            ),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _slate200, width: 0.6),
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'FOR: ${orgName.toUpperCase()}',
                    style: pw.TextStyle(
                      color: _slate500,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (signatureImage != null) ...[
                    pw.SizedBox(height: 4),
                    pw.Container(
                      height: 36,
                      child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
                    ),
                  ] else
                    pw.SizedBox(height: 18),
                  pw.Divider(color: _slate700, thickness: 0.6),
                  if (signatoryName.isNotEmpty)
                    pw.Text(
                      signatoryName,
                      style: pw.TextStyle(
                        color: primaryColor,
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  pw.Text(
                    '$signatoryTitle  |  ${isSwahili ? "Sahihi & Muhuri" : "Signature & Official Stamp"}',
                    style: const pw.TextStyle(
                      color: _slate500,
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ];
  }

  // =========================================================================
  // 2. INVOICE - 80MM CONTINUOUS THERMAL ROLL PROFILE
  // =========================================================================

  Future<Uint8List> generateInvoiceThermal80mm({
    required CustomerInvoice invoice,
    Organization? organization,
    bool isSwahili = false,
  }) async {
    final String orgName =
        (organization?.name != null && organization!.name!.trim().isNotEmpty)
            ? organization.name!.trim()
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
    final paymentInstructions =
        _resolvePaymentInstructions(invoice, organization, isSwahili);

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
              '${invoice.documentTitle} #${invoice.number}',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              dateFmt.format(invoice.issueDate.toLocal()),
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.Text(
              '${isSwahili ? "Mteja" : "Client"}: ${invoice.customerLabel}',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
            ),
            if (invoice.customerPhone != null &&
                invoice.customerPhone!.trim().isNotEmpty)
              pw.Text(
                'Tel: ${invoice.customerPhone!.trim()}',
                style: const pw.TextStyle(fontSize: 7.5),
              ),
            if (invoice.customerAddress != null &&
                invoice.customerAddress!.trim().isNotEmpty)
              pw.Text(
                invoice.customerAddress!.trim(),
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 7.5),
              ),
            if (invoice.customerTin != null &&
                invoice.customerTin!.trim().isNotEmpty)
              pw.Text(
                'TIN: ${invoice.customerTin!.trim()}',
                style: pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                ),
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
                      'Disc: -${numFmt.format(line.discountAmount)}',
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
            _buildThermalRow('TOTAL:', fmtMoney(invoice.totalAmount),
                isBold: true, fontSize: 10),
            if (invoice.amountPaid > 0)
              _buildThermalRow('Paid:', fmtMoney(invoice.amountPaid)),
            _buildThermalRow('BAL DUE:', fmtMoney(invoice.balanceDue),
                isBold: true, fontSize: 9.5),

            if (invoice.payments.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              _buildThermalDashedLine(),
              pw.SizedBox(height: 3),
              pw.Text(
                isSwahili ? 'STAKABADHI ZA MALIPO:' : 'PAYMENTS RECORDED:',
                style: pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              for (final p in invoice.payments)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          '${p.method}${p.reference != null ? " (${p.reference})" : ""}',
                          style: const pw.TextStyle(fontSize: 7),
                          maxLines: 1,
                        ),
                      ),
                      pw.Text(
                        fmtMoney(p.amount),
                        style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],

            if (paymentInstructions.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              _buildThermalDashedLine(),
              pw.SizedBox(height: 3),
              pw.Text(
                isSwahili ? 'MAELEKEZO YA KULIPA:' : 'PAYMENT INFO:',
                style: pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                paymentInstructions,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 6.5, color: _slate700),
              ),
            ],

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
    final String orgName = (organization?.name != null &&
            organization!.name!.isNotEmpty)
        ? organization.name!
        : 'Biashara Yetu';

    final document = pw.Document(
      title: 'DELIVERY NOTE ${note.number}',
      author: orgName,
      creator: 'Jolinx Business OS',
    );

    final dateFmt = DateFormat('dd MMM yyyy');
    final numFmt = NumberFormat('#,##0.##');

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
    final String orgName = (organization?.name != null &&
            organization!.name!.isNotEmpty)
        ? organization.name!
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

  static pw.Widget _buildPdfPaymentHistoryTable({
    required CustomerInvoice invoice,
    required NumberFormat numFmt,
    required String currency,
    required bool isSwahili,
  }) {
    if (invoice.payments.isEmpty) return pw.SizedBox.shrink();
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 8),
        pw.Text(
          isSwahili
              ? 'Historia ya Malipo (Payments Received):'
              : 'Payment History / Receipts:',
          style: pw.TextStyle(
            color: _slate700,
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.TableHelper.fromTextArray(
          headers: [
            isSwahili ? 'Tarehe' : 'Date',
            isSwahili ? 'Njia' : 'Method',
            isSwahili ? 'Kumbukumbu' : 'Reference',
            isSwahili ? 'Kiasi ($currency)' : 'Amount ($currency)',
          ],
          data: [
            for (final pmt in invoice.payments)
              [
                dateFmt.format(pmt.paidAtUtc.toLocal()),
                pmt.method,
                pmt.reference ?? '-',
                numFmt.format(pmt.amount),
              ],
          ],
          border: const pw.TableBorder(
            bottom: pw.BorderSide(color: _slate200, width: 0.6),
            horizontalInside: pw.BorderSide(color: _slate200, width: 0.5),
          ),
          headerStyle: pw.TextStyle(
            color: _defaultPrimary,
            fontSize: 7.5,
            fontWeight: pw.FontWeight.bold,
          ),
          headerDecoration: const pw.BoxDecoration(color: _slate100),
          headerHeight: 18,
          cellHeight: 18,
          cellStyle: const pw.TextStyle(color: _slate700, fontSize: 7.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2.6),
            1: const pw.FlexColumnWidth(2.2),
            2: const pw.FlexColumnWidth(2.7),
            3: const pw.FlexColumnWidth(2.5),
          },
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerLeft,
            3: pw.Alignment.centerRight,
          },
        ),
      ],
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
