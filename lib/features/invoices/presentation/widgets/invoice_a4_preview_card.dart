import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../settings/data/organization_repository.dart';
import '../../application/document_template_controller.dart';
import '../../domain/document_template.dart';
import '../../domain/invoice.dart';

/// Renders an executive A4 paper visual preview of a [CustomerInvoice]
/// directly inside the mobile or desktop screen so the user can inspect
/// the exact layout that will be exported to PDF / printed on A4.
///
/// Automatically adapts to the tenant's active [TenantDocumentConfiguration]
/// ([InvoiceLayoutStyle.modernRibbon], [InvoiceLayoutStyle.executiveCorporate],
/// [InvoiceLayoutStyle.classicGrid], or [InvoiceLayoutStyle.customLetterhead]),
/// brand colors, logo visibility, uploaded signature/stamp, and letterhead banner.
class InvoiceA4PreviewCard extends ConsumerWidget {
  const InvoiceA4PreviewCard({
    super.key,
    required this.invoice,
    required this.organization,
    required this.isSwahili,
    this.onConfigureBranding,
    this.templateConfig,
  });

  final CustomerInvoice invoice;
  final Organization organization;
  final bool isSwahili;
  final VoidCallback? onConfigureBranding;
  final TenantDocumentConfiguration? templateConfig;

  static const Color _navy = Color(0xFF0F172A);
  static const Color _teal = Color(0xFF0D9488);
  static const Color _slate700 = Color(0xFF334155);
  static const Color _slate500 = Color(0xFF64748B);
  static const Color _slate200 = Color(0xFFE2E8F0);
  static const Color _slate50 = Color(0xFFF8FAFC);

  Color _parseHex(String? hex, Color fallback) {
    if (hex == null || hex.trim().isEmpty) return fallback;
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final parsed = int.tryParse('FF$clean', radix: 16);
      if (parsed != null) return Color(parsed);
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeConfig = templateConfig ??
        ref.watch(documentTemplateControllerProvider).currentInvoiceConfiguration;
    final style = activeConfig.layoutStyle;
    final primaryColor = _parseHex(
      activeConfig.themePrimaryHex,
      _parseHex(style.defaultPrimaryHex, _navy),
    );
    final secondaryColor = _parseHex(
      activeConfig.themeSecondaryHex,
      _parseHex(style.defaultSecondaryHex, _teal),
    );
    final showLogo = activeConfig.showLogo;

    final dateFormat = DateFormat('dd/MM/yyyy');
    final numberFormat = NumberFormat('#,##0.##');
    final currency =
        organization.currency != null && organization.currency!.isNotEmpty
            ? organization.currency!
            : 'TZS';

    String fmtMoney(double amount) => '$currency ${numberFormat.format(amount)}';

    final logoBytes =
        showLogo ? _decodeBase64Bytes(organization.logoBase64) : null;
    final signatureBytes = _decodeBase64Bytes(organization.signatureBase64);
    final letterheadBytes =
        _decodeBase64Bytes(organization.letterheadHeaderBase64);
    final paymentInstructions = _resolvePaymentInstructions();
    final notesAndTerms = _resolveNotesAndTerms(activeConfig.footerNotes);
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
                : (isSwahili
                    ? 'Sahihi Iliyoidhinishwa'
                    : 'Authorized Signatory');

    final qrData = [
      invoice.documentTitle,
      'No: ${invoice.invoiceNumber}',
      'Seller: ${organization.name ?? ""}',
      'Client: ${invoice.customerLabel}',
      'Total: ${fmtMoney(invoice.totalAmount)}',
      'Balance: ${fmtMoney(invoice.balanceDue)}',
    ].join(' | ');

    switch (style) {
      case InvoiceLayoutStyle.modernRibbon:
        return _buildModernRibbonLayout(
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
          showLogo: showLogo,
          logoBytes: logoBytes,
          signatureBytes: signatureBytes,
          dateFormat: dateFormat,
          numberFormat: numberFormat,
          currency: currency,
          fmtMoney: fmtMoney,
          paymentInstructions: paymentInstructions,
          notesAndTerms: notesAndTerms,
          signatoryName: signatoryName,
          signatoryTitle: signatoryTitle,
        );
      case InvoiceLayoutStyle.classicGrid:
        return _buildClassicGridLayout(
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
          showLogo: showLogo,
          logoBytes: logoBytes,
          signatureBytes: signatureBytes,
          dateFormat: dateFormat,
          numberFormat: numberFormat,
          currency: currency,
          fmtMoney: fmtMoney,
          paymentInstructions: paymentInstructions,
          notesAndTerms: notesAndTerms,
          signatoryName: signatoryName,
          signatoryTitle: signatoryTitle,
        );
      case InvoiceLayoutStyle.customLetterhead:
        return _buildCustomLetterheadLayout(
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
          showLogo: showLogo,
          logoBytes: logoBytes,
          signatureBytes: signatureBytes,
          letterheadBytes: letterheadBytes,
          dateFormat: dateFormat,
          numberFormat: numberFormat,
          currency: currency,
          fmtMoney: fmtMoney,
          paymentInstructions: paymentInstructions,
          notesAndTerms: notesAndTerms,
          signatoryName: signatoryName,
          signatoryTitle: signatoryTitle,
          qrData: qrData,
        );
      case InvoiceLayoutStyle.executiveCorporate:
        return _buildExecutiveCorporateLayout(
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
          showLogo: showLogo,
          logoBytes: logoBytes,
          signatureBytes: signatureBytes,
          dateFormat: DateFormat('dd MMM yyyy'),
          numberFormat: numberFormat,
          fmtMoney: fmtMoney,
          paymentInstructions: paymentInstructions,
          notesAndTerms: notesAndTerms,
          signatoryName: signatoryName,
          signatoryTitle: signatoryTitle,
          qrData: qrData,
        );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 1. MODERN RIBBON LAYOUT (Matches the uploaded Gold & Charcoal sample)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildModernRibbonLayout({
    required Color primaryColor,
    required Color secondaryColor,
    required bool showLogo,
    required Uint8List? logoBytes,
    required Uint8List? signatureBytes,
    required DateFormat dateFormat,
    required NumberFormat numberFormat,
    required String currency,
    required String Function(double) fmtMoney,
    required String paymentInstructions,
    required String notesAndTerms,
    required String signatoryName,
    required String signatoryTitle,
  }) {
    final isPrimaryLight = primaryColor.computeLuminance() > 0.55;
    final ribbonFg = isPrimaryLight ? const Color(0xFF1E293B) : Colors.white;
    final ribbonLabelFg = isPrimaryLight
        ? const Color(0xFF334155)
        : Colors.white.withValues(alpha: 0.88);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _slate200),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row: Stacked Logo + Business Name (Left) | "Invoice #2022435" (Right)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 6,
                child: GestureDetector(
                  onTap: onConfigureBranding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showLogo) ...[
                        _buildLogoAvatar(logoBytes, primaryColor, size: 62),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        (organization.name != null &&
                                organization.name!.trim().isNotEmpty)
                            ? organization.name!.trim()
                            : 'Your Business Name',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                          height: 1.15,
                        ),
                      ),
                      if (organization.taxId != null &&
                          organization.taxId!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'TIN: ${organization.taxId!.trim()}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: _slate500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Invoice ${invoice.invoiceNumber}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      invoice.documentTitle,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: _slate500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildStatusBadge(secondaryColor),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Second Row: BILL TO (Left) | Issue date / Due date / Reference (Right)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSwahili ? 'KWA MTEJA (BILL TO)' : 'BILL TO',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      invoice.customerLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    if (invoice.customerAttention != null &&
                        invoice.customerAttention!.trim().isNotEmpty)
                      Text(
                        'Attn: ${invoice.customerAttention!.trim()}',
                        style: const TextStyle(fontSize: 11, color: _slate700),
                      ),
                    if (invoice.customerAddress != null &&
                        invoice.customerAddress!.trim().isNotEmpty)
                      Text(
                        invoice.customerAddress!.trim(),
                        style: const TextStyle(fontSize: 11, color: _slate700),
                      ),
                    if (invoice.customerPhone != null &&
                        invoice.customerPhone!.trim().isNotEmpty)
                      Text(
                        invoice.customerPhone!.trim(),
                        style: const TextStyle(fontSize: 11, color: _slate700),
                      ),
                    if (invoice.customerEmail != null &&
                        invoice.customerEmail!.trim().isNotEmpty)
                      Text(
                        invoice.customerEmail!.trim(),
                        style: const TextStyle(fontSize: 11, color: _slate700),
                      ),
                    if (invoice.customerTin != null &&
                        invoice.customerTin!.trim().isNotEmpty)
                      Text(
                        'TIN: ${invoice.customerTin!.trim()}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _slate700,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _rightAlignedMetaRow(
                      isSwahili ? 'Tarehe:' : 'Issue date:',
                      dateFormat.format(invoice.issueDate.toLocal()),
                    ),
                    const SizedBox(height: 3),
                    _rightAlignedMetaRow(
                      isSwahili ? 'Mwisho:' : 'Due date:',
                      invoice.dueDate != null
                          ? dateFormat.format(invoice.dueDate!.toLocal())
                          : dateFormat.format(invoice.issueDate.toLocal()),
                    ),
                    const SizedBox(height: 8),
                    _rightAlignedMetaRow(
                      isSwahili ? 'Kumbukumbu:' : 'Reference:',
                      (invoice.referenceNumber != null &&
                              invoice.referenceNumber!.trim().isNotEmpty)
                          ? invoice.referenceNumber!.trim()
                          : invoice.invoiceNumber,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Third Row: 4-Column Colored Highlight Ribbon
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      border: const Border(
                        right: BorderSide(color: Colors.white, width: 1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSwahili ? 'Na. ya Ankara' : 'Invoice No.',
                          style: TextStyle(fontSize: 9.5, color: ribbonLabelFg),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          invoice.invoiceNumber,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: ribbonFg,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      border: const Border(
                        right: BorderSide(color: Colors.white, width: 1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSwahili ? 'Tarehe' : 'Issue date',
                          style: TextStyle(fontSize: 9.5, color: ribbonLabelFg),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateFormat.format(invoice.issueDate.toLocal()),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: ribbonFg,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      border: const Border(
                        right: BorderSide(color: Colors.white, width: 1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSwahili ? 'Mwisho' : 'Due date',
                          style: TextStyle(fontSize: 9.5, color: ribbonLabelFg),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          invoice.dueDate != null
                              ? dateFormat.format(invoice.dueDate!.toLocal())
                              : '-',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: ribbonFg,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    color: secondaryColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSwahili
                              ? 'Jumla ($currency)'
                              : 'Total due ($currency)',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          numberFormat.format(
                            invoice.balanceDue > 0
                                ? invoice.balanceDue
                                : invoice.totalAmount,
                          ),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Fourth Row: Minimalist Horizontal-Rule Item Table
          Container(
            padding: const EdgeInsets.only(bottom: 6),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF94A3B8), width: 1.2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    isSwahili ? 'Maelezo' : 'Description',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    isSwahili ? 'Idadi' : 'Quantity',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    isSwahili ? 'Bei ($currency)' : 'Unit price',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    isSwahili ? 'Jumla ($currency)' : 'Amount',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...invoice.lines.map((line) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: _slate200, width: 0.8),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.description,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        if (line.discountAmount > 0)
                          Text(
                            '${isSwahili ? "Punguzo" : "Discount"}: -${numberFormat.format(line.discountAmount)}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFFB45309),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      numberFormat.format(line.quantity),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      numberFormat.format(line.unitPrice),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      numberFormat.format(line.lineTotal),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 10),

          // Totals Section
          _summaryRow(
            isSwahili ? 'Jumla Ndogo (Subtotal):' : 'Subtotal:',
            fmtMoney(invoice.subtotal),
          ),
          if (invoice.discountAmount > 0) ...[
            const SizedBox(height: 4),
            _summaryRow(
              isSwahili ? 'Punguzo (Discount):' : 'Discount:',
              '- ${fmtMoney(invoice.discountAmount)}',
              valueColor: const Color(0xFFB45309),
            ),
          ],
          const SizedBox(height: 6),
          _summaryRow(
            isSwahili ? 'Jumla ($currency):' : 'Total ($currency):',
            fmtMoney(invoice.totalAmount),
            isBold: true,
          ),
          if (invoice.amountPaid > 0) ...[
            const SizedBox(height: 4),
            _summaryRow(
              isSwahili ? 'Imelipwa (Paid):' : 'Amount Paid:',
              '- ${fmtMoney(invoice.amountPaid)}',
              valueColor: const Color(0xFF15803D),
            ),
            const SizedBox(height: 4),
            _summaryRow(
              isSwahili ? 'Salio (Balance Due):' : 'Balance Due:',
              fmtMoney(invoice.balanceDue),
              isBold: true,
            ),
          ],

          const SizedBox(height: 20),

          // Payment Details (Left) + "Issued by, signature:" with Signature Image (Right)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSwahili ? 'Maelekezo ya Malipo:' : 'Payment Details:',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _slate700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      paymentInstructions,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: _slate700,
                        height: 1.35,
                      ),
                    ),
                    if (notesAndTerms.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        notesAndTerms,
                        style: const TextStyle(
                          fontSize: 10,
                          color: _slate500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isSwahili
                          ? 'Imetolewa na, sahihi:'
                          : 'Issued by, signature:',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (signatureBytes != null)
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 56,
                          maxWidth: 150,
                        ),
                        child: Image.memory(
                          signatureBytes,
                          fit: BoxFit.contain,
                        ),
                      )
                    else if (signatoryName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          signatoryName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 32),
                    Container(
                      width: 140,
                      height: 1,
                      color: _slate200,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      signatoryName.isNotEmpty ? signatoryName : signatoryTitle,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: _slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Pinned Bottom Contact Footer (Phone | Website | Email + Divider + Address)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 4,
            children: [
              if (organization.phone != null &&
                  organization.phone!.trim().isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.phone, size: 12, color: Color(0xFF1E293B)),
                    const SizedBox(width: 4),
                    Text(
                      organization.phone!.trim(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              if (organization.website != null &&
                  organization.website!.trim().isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.language,
                      size: 12,
                      color: Color(0xFF1E293B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      organization.website!.trim(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              if (organization.email != null &&
                  organization.email!.trim().isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.send_outlined,
                      size: 12,
                      color: Color(0xFF1E293B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      organization.email!.trim(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Divider(height: 1, thickness: 1, color: Color(0xFF334155)),
          const SizedBox(height: 6),
          Text(
            [
              if (organization.name != null &&
                  organization.name!.trim().isNotEmpty)
                organization.name!.trim(),
              if (organization.address != null &&
                  organization.address!.trim().isNotEmpty)
                organization.address!.trim(),
            ].join(' • '),
            style: const TextStyle(
              fontSize: 9.5,
              color: _slate700,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 2. CLASSIC WHOLESALE GRID LAYOUT (Full bordered tabular layout)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildClassicGridLayout({
    required Color primaryColor,
    required Color secondaryColor,
    required bool showLogo,
    required Uint8List? logoBytes,
    required Uint8List? signatureBytes,
    required DateFormat dateFormat,
    required NumberFormat numberFormat,
    required String currency,
    required String Function(double) fmtMoney,
    required String paymentInstructions,
    required String notesAndTerms,
    required String signatoryName,
    required String signatoryTitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryColor, width: 1.5),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Banner Title
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            color: primaryColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  invoice.documentTitle.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  'NO: ${invoice.invoiceNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          // Boxed Seller & Buyer Grid
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: primaryColor),
                        bottom: BorderSide(color: primaryColor),
                        right: BorderSide(color: primaryColor),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (showLogo && logoBytes != null) ...[
                              _buildLogoAvatar(
                                logoBytes,
                                primaryColor,
                                size: 38,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                (organization.name ?? 'SELLER').toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (organization.address != null &&
                            organization.address!.trim().isNotEmpty)
                          Text(
                            organization.address!.trim(),
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: _slate700,
                            ),
                          ),
                        if (organization.phone != null &&
                            organization.phone!.trim().isNotEmpty)
                          Text(
                            'Tel: ${organization.phone!.trim()}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: _slate700,
                            ),
                          ),
                        if (organization.taxId != null &&
                            organization.taxId!.trim().isNotEmpty)
                          Text(
                            'TIN: ${organization.taxId!.trim()}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: _slate700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: primaryColor),
                        right: BorderSide(color: primaryColor),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSwahili ? 'MTEJA (CUSTOMER):' : 'CUSTOMER / BUYER:',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: secondaryColor,
                          ),
                        ),
                        Text(
                          invoice.customerLabel,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: _navy,
                          ),
                        ),
                        if (invoice.customerAddress != null &&
                            invoice.customerAddress!.trim().isNotEmpty)
                          Text(
                            invoice.customerAddress!.trim(),
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: _slate700,
                            ),
                          ),
                        if (invoice.customerPhone != null &&
                            invoice.customerPhone!.trim().isNotEmpty)
                          Text(
                            'Tel: ${invoice.customerPhone!.trim()}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: _slate700,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          '${isSwahili ? "Tarehe" : "Date"}: ${dateFormat.format(invoice.issueDate.toLocal())}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: _navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Gridded Table
          Table(
            border: TableBorder.all(color: primaryColor, width: 0.9),
            columnWidths: const {
              0: FixedColumnWidth(28),
              1: FlexColumnWidth(4.5),
              2: FlexColumnWidth(1.6),
              3: FlexColumnWidth(2),
              4: FlexColumnWidth(2.2),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                ),
                children: [
                  _gridCell('#', isHeader: true),
                  _gridCell(
                    isSwahili ? 'Bidhaa / Maelezo' : 'Description',
                    isHeader: true,
                  ),
                  _gridCell(
                    isSwahili ? 'Idadi' : 'Qty',
                    isHeader: true,
                    alignRight: true,
                  ),
                  _gridCell(
                    isSwahili ? 'Bei' : 'Rate',
                    isHeader: true,
                    alignRight: true,
                  ),
                  _gridCell(
                    isSwahili ? 'Jumla' : 'Amount',
                    isHeader: true,
                    alignRight: true,
                  ),
                ],
              ),
              ...List.generate(invoice.lines.length, (index) {
                final line = invoice.lines[index];
                return TableRow(
                  children: [
                    _gridCell('${index + 1}'),
                    _gridCell(line.description),
                    _gridCell(
                      numberFormat.format(line.quantity),
                      alignRight: true,
                    ),
                    _gridCell(
                      numberFormat.format(line.unitPrice),
                      alignRight: true,
                    ),
                    _gridCell(
                      numberFormat.format(line.lineTotal),
                      alignRight: true,
                      isBold: true,
                    ),
                  ],
                );
              }),
            ],
          ),

          // Totals Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _slate50,
              border: Border(
                left: BorderSide(color: primaryColor, width: 0.9),
                right: BorderSide(color: primaryColor, width: 0.9),
                bottom: BorderSide(color: primaryColor, width: 0.9),
              ),
            ),
            child: Column(
              children: [
                _summaryRow(
                  isSwahili ? 'Jumla Kuu ($currency)' : 'TOTAL ($currency)',
                  fmtMoney(invoice.totalAmount),
                  isBold: true,
                  valueColor: primaryColor,
                ),
                if (invoice.amountPaid > 0) ...[
                  const SizedBox(height: 4),
                  _summaryRow(
                    isSwahili ? 'Imelipwa (Paid)' : 'Paid',
                    fmtMoney(invoice.amountPaid),
                    valueColor: const Color(0xFF15803D),
                  ),
                  const SizedBox(height: 4),
                  _summaryRow(
                    isSwahili ? 'Salio (Balance Due)' : 'Balance Due',
                    fmtMoney(invoice.balanceDue),
                    isBold: true,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),
          Text(
            paymentInstructions,
            style: const TextStyle(fontSize: 10.5, color: _slate700),
          ),
          const SizedBox(height: 18),

          // Dual Signatures: Prepared By & Received By
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (signatureBytes != null)
                      SizedBox(
                        height: 42,
                        child: Image.memory(
                          signatureBytes,
                          fit: BoxFit.contain,
                        ),
                      )
                    else
                      const SizedBox(height: 28),
                    Divider(height: 1, color: primaryColor),
                    const SizedBox(height: 4),
                    Text(
                      isSwahili
                          ? 'Imetolewa Na (Sahihi & Muhuri)'
                          : 'Prepared & Authorized By',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _slate700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 28),
                    Divider(height: 1, color: primaryColor),
                    const SizedBox(height: 4),
                    Text(
                      isSwahili
                          ? 'Imepokelewa Na Mteja (Sahihi)'
                          : 'Received & Accepted By Customer',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _slate700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 3. CUSTOM LETTERHEAD / PRE-PRINTED STATIONERY LAYOUT
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildCustomLetterheadLayout({
    required Color primaryColor,
    required Color secondaryColor,
    required bool showLogo,
    required Uint8List? logoBytes,
    required Uint8List? signatureBytes,
    required Uint8List? letterheadBytes,
    required DateFormat dateFormat,
    required NumberFormat numberFormat,
    required String currency,
    required String Function(double) fmtMoney,
    required String paymentInstructions,
    required String notesAndTerms,
    required String signatoryName,
    required String signatoryTitle,
    required String qrData,
  }) {
    final topMarginMm = organization.prePrintedTopMarginMm ?? 38;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _slate200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Area: Either Pre-Printed Blank Margin OR Uploaded Designer Letterhead Banner
          if (organization.hideHeaderForPrePrinted)
            Container(
              height: (topMarginMm * 2.1).clamp(48.0, 160.0),
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _slate50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _slate200,
                  style: BorderStyle.solid,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                isSwahili
                    ? 'NAFASI YA LETTERHEAD ILIYOKO KWENYE KARATASI (${topMarginMm.toInt()} mm)\n(Sehemu hii itaachwa wazi wakati wa ku-print)'
                    : 'PRE-PRINTED STATIONERY HEADER SPACE (${topMarginMm.toInt()} mm)\n(Left blank when printing on your physical letterhead)',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: _slate500,
                ),
              ),
            )
          else if (letterheadBytes != null)
            Image.memory(
              letterheadBytes,
              fit: BoxFit.fitWidth,
              width: double.infinity,
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              color: primaryColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    (organization.name ?? 'YOUR BUSINESSLETTERHEAD')
                        .toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  if (onConfigureBranding != null)
                    Text(
                      isSwahili
                          ? 'Pakia Picha ya Letterhead'
                          : 'Upload Header Banner',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10.5,
                      ),
                    ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSwahili ? 'KWA MTEJA (BILL TO)' : 'BILL TO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: secondaryColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            invoice.customerLabel,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _navy,
                            ),
                          ),
                          if (invoice.customerAddress != null &&
                              invoice.customerAddress!.trim().isNotEmpty)
                            Text(
                              invoice.customerAddress!.trim(),
                              style: const TextStyle(
                                fontSize: 11,
                                color: _slate700,
                              ),
                            ),
                          if (invoice.customerPhone != null &&
                              invoice.customerPhone!.trim().isNotEmpty)
                            Text(
                              'Tel: ${invoice.customerPhone!.trim()}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: _slate700,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          invoice.documentTitle.toUpperCase(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: primaryColor,
                          ),
                        ),
                        Text(
                          '#${invoice.invoiceNumber}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _slate700,
                          ),
                        ),
                        Text(
                          dateFormat.format(invoice.issueDate.toLocal()),
                          style: const TextStyle(
                            fontSize: 11,
                            color: _slate500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStandardItemsTable(primaryColor, numberFormat),
                const SizedBox(height: 14),
                _buildStandardSummaryCard(primaryColor, fmtMoney),
                const SizedBox(height: 14),
                _buildSignatureAndQrFooter(
                  primaryColor: primaryColor,
                  qrData: qrData,
                  signatureBytes: signatureBytes,
                  signatoryName: signatoryName,
                  signatoryTitle: signatoryTitle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 4. EXECUTIVE CORPORATE LAYOUT (Dynamic Theme Colors + Signature Support)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildExecutiveCorporateLayout({
    required Color primaryColor,
    required Color secondaryColor,
    required bool showLogo,
    required Uint8List? logoBytes,
    required Uint8List? signatureBytes,
    required DateFormat dateFormat,
    required NumberFormat numberFormat,
    required String Function(double) fmtMoney,
    required String paymentInstructions,
    required String notesAndTerms,
    required String signatoryName,
    required String signatoryTitle,
    required String qrData,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _slate200),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Accent Bar
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1 & 2. Seller Header + Document Title & Number
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showLogo) ...[
                      GestureDetector(
                        onTap: onConfigureBranding,
                        child: _buildLogoAvatar(logoBytes, primaryColor),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (organization.name != null &&
                                    organization.name!.isNotEmpty)
                                ? organization.name!.toUpperCase()
                                : 'YOUR BUSINESS NAME',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: primaryColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                          if (organization.taxId != null &&
                              organization.taxId!.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'TIN: ${organization.taxId!.trim()}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: secondaryColor,
                                ),
                              ),
                            ),
                          if (organization.address != null &&
                              organization.address!.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                organization.address!.trim(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _slate700,
                                ),
                              ),
                            ),
                          if (organization.phone != null &&
                              organization.phone!.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Text(
                                'Tel: ${organization.phone!.trim()}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _slate700,
                                ),
                              ),
                            ),
                          if (organization.email != null &&
                              organization.email!.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Text(
                                organization.email!.trim(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _slate700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          invoice.documentTitle.toUpperCase(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: primaryColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '#${invoice.invoiceNumber}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _slate700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildStatusBadge(secondaryColor),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Metadata Strip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _slate50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _slate200),
                  ),
                  child: Wrap(
                    spacing: 18,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      _metaItem(
                        isSwahili ? 'Tarehe ya Kutolewa' : 'Issue Date',
                        dateFormat.format(invoice.issueDate.toLocal()),
                        primaryColor,
                      ),
                      if (invoice.dueDate != null)
                        _metaItem(
                          isSwahili ? 'Tarehe ya Mwisho' : 'Due Date',
                          dateFormat.format(invoice.dueDate!.toLocal()),
                          primaryColor,
                        ),
                      if (invoice.paymentTerms != null &&
                          invoice.paymentTerms!.trim().isNotEmpty)
                        _metaItem(
                          isSwahili ? 'Masharti' : 'Terms',
                          invoice.paymentTerms!.trim(),
                          primaryColor,
                        ),
                      if (invoice.referenceNumber != null &&
                          invoice.referenceNumber!.trim().isNotEmpty)
                        _metaItem(
                          isSwahili ? 'Kumbukumbu / PO' : 'Ref / PO No',
                          invoice.referenceNumber!.trim(),
                          primaryColor,
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 3. Bill To Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _slate50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(color: primaryColor, width: 4),
                      top: const BorderSide(color: _slate200),
                      right: const BorderSide(color: _slate200),
                      bottom: const BorderSide(color: _slate200),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSwahili
                            ? 'KWA MTEJA / MPOKEAJI (BILL TO)'
                            : 'BILL TO (RECEIVER)',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _slate500,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        invoice.customerLabel,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                        ),
                      ),
                      if (invoice.customerAttention != null &&
                          invoice.customerAttention!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            '${isSwahili ? "Kwa Uangalizi wa (Attn)" : "Attn"}: ${invoice.customerAttention!.trim()}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: _slate700,
                            ),
                          ),
                        ),
                      if (invoice.customerAddress != null &&
                          invoice.customerAddress!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            invoice.customerAddress!.trim(),
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: _slate700,
                            ),
                          ),
                        ),
                      if ((invoice.customerPhone?.trim().isNotEmpty ?? false) ||
                          (invoice.customerEmail?.trim().isNotEmpty ?? false) ||
                          (invoice.customerTin?.trim().isNotEmpty ?? false)) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 14,
                          runSpacing: 4,
                          children: [
                            if (invoice.customerPhone != null &&
                                invoice.customerPhone!.trim().isNotEmpty)
                              Text(
                                'Tel: ${invoice.customerPhone!.trim()}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: _slate700,
                                ),
                              ),
                            if (invoice.customerEmail != null &&
                                invoice.customerEmail!.trim().isNotEmpty)
                              Text(
                                'Email: ${invoice.customerEmail!.trim()}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: _slate700,
                                ),
                              ),
                            if (invoice.customerTin != null &&
                                invoice.customerTin!.trim().isNotEmpty)
                              Text(
                                'TIN: ${invoice.customerTin!.trim()}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: secondaryColor,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 4. Itemised Table
                _buildStandardItemsTable(primaryColor, numberFormat),

                const SizedBox(height: 16),

                // 5. Financial Summary Totals
                _buildStandardSummaryCard(primaryColor, fmtMoney),

                const SizedBox(height: 14),

                // 6. Payment Instructions Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _slate50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _slate200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isSwahili
                                ? 'MAELEKEZO YA MALIPO (PAYMENT DETAILS)'
                                : 'PAYMENT INSTRUCTIONS',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: primaryColor,
                              letterSpacing: 0.4,
                            ),
                          ),
                          if (onConfigureBranding != null)
                            InkWell(
                              onTap: onConfigureBranding,
                              child: Text(
                                isSwahili
                                    ? 'Hariri Benki/Nembo'
                                    : 'Edit Bank/Logo',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: secondaryColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        paymentInstructions,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: _slate700,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isSwahili
                            ? 'Taja namba ya ankara #${invoice.invoiceNumber} unapofanya malipo.'
                            : 'Please quote Invoice #${invoice.invoiceNumber} when making payment.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: secondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),

                if (notesAndTerms.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    isSwahili
                        ? 'MASHARTI NA MAELEZO (TERMS & NOTES)'
                        : 'TERMS & CONDITIONS / NOTES',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _slate500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notesAndTerms,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: _slate700,
                      height: 1.35,
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // 7. QR Code & Official Signature / Stamp Block
                _buildSignatureAndQrFooter(
                  primaryColor: primaryColor,
                  qrData: qrData,
                  signatureBytes: signatureBytes,
                  signatoryName: signatoryName,
                  signatoryTitle: signatoryTitle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardItemsTable(
    Color primaryColor,
    NumberFormat numberFormat,
  ) {
    final isLightHeader = primaryColor.computeLuminance() > 0.55;
    final headerFg = isLightHeader ? const Color(0xFF1E293B) : Colors.white;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _slate200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: primaryColor,
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    '#',
                    style: TextStyle(
                      color: headerFg,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    isSwahili ? 'Bidhaa / Huduma' : 'Item Description',
                    style: TextStyle(
                      color: headerFg,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    isSwahili ? 'Idadi × Bei' : 'Qty × Price',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: headerFg,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    isSwahili ? 'Jumla' : 'Total',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: headerFg,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...List.generate(invoice.lines.length, (i) {
            final line = invoice.lines[i];
            final unit =
                line.unitOfMeasure.isNotEmpty ? line.unitOfMeasure : 'Pcs';
            return Container(
              color: i.isEven ? Colors.white : _slate50,
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 9,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: _slate500,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.description,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _navy,
                          ),
                        ),
                        if (line.discountAmount > 0)
                          Text(
                            '${isSwahili ? "Punguzo" : "Disc"}: -${numberFormat.format(line.discountAmount)}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFFB45309),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${numberFormat.format(line.quantity)} $unit\n@ ${numberFormat.format(line.unitPrice)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _slate700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      numberFormat.format(line.lineTotal),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStandardSummaryCard(
    Color primaryColor,
    String Function(double) fmtMoney,
  ) {
    final isLightPrimary = primaryColor.computeLuminance() > 0.55;
    final barFg = isLightPrimary ? const Color(0xFF1E293B) : Colors.white;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _slate50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _slate200),
      ),
      child: Column(
        children: [
          _summaryRow(
            isSwahili ? 'Jumla Ndogo (Subtotal)' : 'Subtotal',
            fmtMoney(invoice.subtotal),
          ),
          if (invoice.discountAmount > 0) ...[
            const SizedBox(height: 4),
            _summaryRow(
              isSwahili ? 'Punguzo (Discount)' : 'Discount',
              '- ${fmtMoney(invoice.discountAmount)}',
              valueColor: const Color(0xFFB45309),
            ),
          ],
          const Divider(height: 14),
          _summaryRow(
            isSwahili ? 'Jumla Kuu (Total)' : 'Total Amount',
            fmtMoney(invoice.totalAmount),
            isBold: true,
          ),
          if (invoice.amountPaid > 0) ...[
            const SizedBox(height: 4),
            _summaryRow(
              isSwahili ? 'Kiasi Kilicholipwa (Paid)' : 'Amount Paid',
              '- ${fmtMoney(invoice.amountPaid)}',
              valueColor: const Color(0xFF15803D),
              isBold: true,
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isSwahili ? 'SALIO LA KULIPWA' : 'BALANCE DUE',
                  style: TextStyle(
                    color: barFg,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  fmtMoney(invoice.balanceDue),
                  style: TextStyle(
                    color: barFg,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureAndQrFooter({
    required Color primaryColor,
    required String qrData,
    required Uint8List? signatureBytes,
    required String signatoryName,
    required String signatoryTitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _slate200),
          ),
          child: QrImageView(
            data: qrData,
            size: 60,
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _slate200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FOR: ${(organization.name ?? "BUSINESS").toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: _slate500,
                  ),
                ),
                const SizedBox(height: 6),
                if (signatureBytes != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 44,
                      maxWidth: 140,
                    ),
                    child: Image.memory(
                      signatureBytes,
                      fit: BoxFit.contain,
                    ),
                  )
                else
                  const SizedBox(height: 18),
                const Divider(height: 1, color: _slate700),
                const SizedBox(height: 4),
                if (signatoryName.isNotEmpty)
                  Text(
                    signatoryName,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                    ),
                  ),
                Text(
                  '$signatoryTitle • ${isSwahili ? "Sahihi & Muhuri" : "Signature & Stamp"}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: _slate500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _rightAlignedMetaRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: _slate700),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _gridCell(
    String text, {
    bool isHeader = false,
    bool alignRight = false,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          fontSize: isHeader ? 10.5 : 11,
          fontWeight:
              (isHeader || isBold) ? FontWeight.w800 : FontWeight.w500,
          color: _navy,
        ),
      ),
    );
  }

  Widget _buildLogoAvatar(
    Uint8List? logoBytes,
    Color primaryColor, {
    double size = 56,
  }) {
    if (logoBytes != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _slate200),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.memory(logoBytes, fit: BoxFit.contain),
      );
    }
    final words = (organization.name ?? 'JB')
        .trim()
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

    final isLight = primaryColor.computeLuminance() > 0.55;
    return Container(
      width: size - 4,
      height: size - 4,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: isLight ? const Color(0xFF1E293B) : Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Color secondaryColor) {
    Color color = const Color(0xFFB45309);
    String text = isSwahili ? 'INASUBIRI' : 'UNPAID';
    if (invoice.status == InvoiceStatus.paid) {
      color = const Color(0xFF15803D);
      text = isSwahili ? 'IMELIPWA' : 'PAID';
    } else if (invoice.status == InvoiceStatus.partiallyPaid) {
      color = secondaryColor;
      text = isSwahili ? 'IMELIPWA NUSU' : 'PARTIAL';
    } else if (invoice.status == InvoiceStatus.voided) {
      color = _slate500;
      text = isSwahili ? 'IMEFUTWA' : 'VOID';
    } else if (invoice.isOverdue) {
      color = const Color(0xFFB91C1C);
      text = isSwahili ? 'IMECHELEWA' : 'OVERDUE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _metaItem(String label, String value, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: _slate500),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color valueColor = _navy,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: _slate700,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 13 : 12,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Uint8List? _decodeBase64Bytes(String? rawBase64) {
    if (rawBase64 == null || rawBase64.trim().isEmpty) return null;
    try {
      var raw = rawBase64.trim();
      final commaIndex = raw.indexOf(',');
      if (raw.startsWith('data:') && commaIndex != -1) {
        raw = raw.substring(commaIndex + 1);
      }
      final bytes = base64Decode(raw);
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  String _resolvePaymentInstructions() {
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
    if (lines.isNotEmpty) return lines.join('\n');
    return isSwahili
        ? 'Lipa kupitia Benki, Simu (M-Pesa / Tigo Pesa / Airtel Money), au Fedha Taslimu.'
        : 'Payable via Bank Transfer, Mobile Money, or Cash.';
  }

  String _resolveNotesAndTerms(String? templateFooterNotes) {
    if (invoice.notes != null && invoice.notes!.trim().isNotEmpty) {
      return invoice.notes!.trim();
    }
    if (templateFooterNotes != null && templateFooterNotes.trim().isNotEmpty) {
      return templateFooterNotes.trim();
    }
    if (organization.invoiceTerms != null &&
        organization.invoiceTerms!.trim().isNotEmpty) {
      return organization.invoiceTerms!.trim();
    }
    return '';
  }
}
