import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../settings/data/organization_repository.dart';
import '../../domain/invoice.dart';

/// Renders an executive A4 paper visual preview of a [CustomerInvoice]
/// directly inside the mobile or desktop screen so the user can inspect
/// the exact layout that will be exported to PDF / printed on A4.
class InvoiceA4PreviewCard extends StatelessWidget {
  const InvoiceA4PreviewCard({
    super.key,
    required this.invoice,
    required this.organization,
    required this.isSwahili,
    this.onConfigureBranding,
  });

  final CustomerInvoice invoice;
  final Organization organization;
  final bool isSwahili;
  final VoidCallback? onConfigureBranding;

  static const Color _navy = Color(0xFF0F172A);
  static const Color _teal = Color(0xFF0D9488);
  static const Color _slate700 = Color(0xFF334155);
  static const Color _slate500 = Color(0xFF64748B);
  static const Color _slate200 = Color(0xFFE2E8F0);
  static const Color _slate50 = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final numberFormat = NumberFormat('#,##0.##');
    final currency =
        organization.currency.isNotEmpty ? organization.currency : 'TZS';

    String fmtMoney(double amount) => '$currency ${numberFormat.format(amount)}';

    final logoBytes = _decodeLogoBytes(organization.logoBase64);
    final paymentInstructions = _resolvePaymentInstructions();
    final notesAndTerms = _resolveNotesAndTerms();
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
      'Seller: ${organization.name}',
      'Client: ${invoice.customerName}',
      'Total: ${fmtMoney(invoice.totalAmount)}',
      'Balance: ${fmtMoney(invoice.balanceDue)}',
    ].join(' | ');

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
            decoration: const BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
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
                    GestureDetector(
                      onTap: onConfigureBranding,
                      child: _buildLogoAvatar(logoBytes),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            organization.name.isNotEmpty
                                ? organization.name.toUpperCase()
                                : 'YOUR BUSINESS NAME',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _navy,
                              letterSpacing: 0.3,
                            ),
                          ),
                          if (organization.taxId != null &&
                              organization.taxId!.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'TIN: ${organization.taxId!.trim()}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _teal,
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
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: _navy,
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
                        _buildStatusBadge(),
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
                      ),
                      _metaItem(
                        isSwahili ? 'Tarehe ya Mwisho' : 'Due Date',
                        dateFormat.format(invoice.dueDate.toLocal()),
                      ),
                      if (invoice.paymentTerms != null &&
                          invoice.paymentTerms!.trim().isNotEmpty)
                        _metaItem(
                          isSwahili ? 'Masharti' : 'Terms',
                          invoice.paymentTerms!.trim(),
                        ),
                      if (invoice.referenceNumber != null &&
                          invoice.referenceNumber!.trim().isNotEmpty)
                        _metaItem(
                          isSwahili ? 'Kumbukumbu / PO' : 'Ref / PO No',
                          invoice.referenceNumber!.trim(),
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
                    border: const Border(
                      left: BorderSide(color: _navy, width: 4),
                      top: BorderSide(color: _slate200),
                      right: BorderSide(color: _slate200),
                      bottom: BorderSide(color: _slate200),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSwahili ? 'KWA MTEJA (BILL TO)' : 'BILL TO',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _slate500,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        invoice.customerName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _navy,
                        ),
                      ),
                      if ((invoice.customerAttention?.trim().isNotEmpty ??
                              false) ||
                          (invoice.customerTin?.trim().isNotEmpty ?? false) ||
                          (invoice.customerPhone?.trim().isNotEmpty ?? false) ||
                          (invoice.customerEmail?.trim().isNotEmpty ?? false) ||
                          (invoice.customerAddress?.trim().isNotEmpty ??
                              false)) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            if (invoice.customerAttention != null &&
                                invoice.customerAttention!.trim().isNotEmpty)
                              Text(
                                'Attn: ${invoice.customerAttention!.trim()}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: _slate700,
                                ),
                              ),
                            if (invoice.customerTin != null &&
                                invoice.customerTin!.trim().isNotEmpty)
                              Text(
                                'TIN: ${invoice.customerTin!.trim()}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: _slate700,
                                ),
                              ),
                            if (invoice.customerPhone != null &&
                                invoice.customerPhone!.trim().isNotEmpty)
                              Text(
                                'Tel: ${invoice.customerPhone!.trim()}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: _slate700,
                                ),
                              ),
                            if (invoice.customerEmail != null &&
                                invoice.customerEmail!.trim().isNotEmpty)
                              Text(
                                invoice.customerEmail!.trim(),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: _slate700,
                                ),
                              ),
                          ],
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
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 4. Itemised Table
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _slate200),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Container(
                        color: _navy,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 22,
                              child: Text(
                                '#',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Text(
                                isSwahili
                                    ? 'Bidhaa / Huduma'
                                    : 'Item Description',
                                style: const TextStyle(
                                  color: Colors.white,
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
                                style: const TextStyle(
                                  color: Colors.white,
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
                                style: const TextStyle(
                                  color: Colors.white,
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
                        final unit = line.unitOfMeasure.isNotEmpty
                            ? line.unitOfMeasure
                            : 'Pcs';
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
                ),

                const SizedBox(height: 16),

                // 5. Financial Summary Totals
                Container(
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
                          color: _navy,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isSwahili ? 'SALIO LA KULIPWA' : 'BALANCE DUE',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              fmtMoney(invoice.balanceDue),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

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
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: _navy,
                              letterSpacing: 0.4,
                            ),
                          ),
                          if (onConfigureBranding != null)
                            InkWell(
                              onTap: onConfigureBranding,
                              child: Text(
                                isSwahili ? 'Hariri Benki/Nembo' : 'Edit Bank/Logo',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _teal,
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
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _teal,
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
                Row(
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
                              'FOR: ${organization.name.toUpperCase()}',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: _slate500,
                              ),
                            ),
                            const SizedBox(height: 22),
                            const Divider(height: 1, color: _slate700),
                            const SizedBox(height: 4),
                            if (signatoryName.isNotEmpty)
                              Text(
                                signatoryName,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: _navy,
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoAvatar(Uint8List? logoBytes) {
    if (logoBytes != null) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _slate200),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.memory(logoBytes, fit: BoxFit.contain),
      );
    }
    final words = organization.name
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

    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color color = const Color(0xFFB45309);
    String text = isSwahili ? 'INASUBIRI' : 'UNPAID';
    if (invoice.status == InvoiceStatus.paid) {
      color = const Color(0xFF15803D);
      text = isSwahili ? 'IMELIPWA' : 'PAID';
    } else if (invoice.status == InvoiceStatus.partiallyPaid) {
      color = _teal;
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

  Widget _metaItem(String label, String value) {
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
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: _navy,
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

  Uint8List? _decodeLogoBytes(String? logoBase64) {
    if (logoBase64 == null || logoBase64.trim().isEmpty) return null;
    try {
      var raw = logoBase64.trim();
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

  String _resolveNotesAndTerms() {
    if (invoice.notes != null && invoice.notes!.trim().isNotEmpty) {
      return invoice.notes!.trim();
    }
    if (organization.invoiceTerms != null &&
        organization.invoiceTerms!.trim().isNotEmpty) {
      return organization.invoiceTerms!.trim();
    }
    return '';
  }
}
