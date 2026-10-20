import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../shared/design_system/app_colors.dart';
import '../../domain/receipt_customization.dart';
import '../../domain/receipt_format.dart';
import '../../domain/receipt_preview.dart';
import '../../domain/receipt_renderer.dart';

/// On-screen receipt ticket — the UI twin of `Thermal80mmRenderer`.
///
/// The two share every formatting rule through `receipt_format.dart`, so the
/// ticket and the printed slip always show the same numbers. This widget is
/// presentation-only: it takes a [ReceiptPreview] and a [language] and talks
/// to no providers (docs/ArchitectureRules.md — no mixed layers).
class ReceiptTicketCard extends StatelessWidget {
  const ReceiptTicketCard({
    super.key,
    required this.receipt,
    this.customization,
    this.language = ReceiptLanguage.english,
    this.isReprint = false,
    this.dense = false,
  });

  /// Receipt data to display.
  final ReceiptPreview receipt;

  /// Optional tenant customization for header tagline and footer notes.
  final ReceiptCustomization? customization;

  /// Label language for this ticket.
  final ReceiptLanguage language;

  /// Prints the reprint watermark, matching the thermal output.
  final bool isReprint;

  /// Compact sizing for the success page, where the ticket sits in a column.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final labels = ReceiptLabels.of(language);
    final theme = Theme.of(context);
    final rule = dense ? 12.0 : 20.0;
    final currency = receipt.currency;

    return Padding(
      padding: EdgeInsets.all(dense ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isReprint) ...[
            _bannerLine(context, labels['reprint']!),
            SizedBox(height: rule),
          ],
          if (receipt.isVoided) ...[
            _bannerLine(context, labels['voided']!),
            SizedBox(height: rule),
          ],
          _header(context, labels),
          SizedBox(height: rule),
          const Divider(height: 1),
          SizedBox(height: rule),
          _meta(context, labels),
          SizedBox(height: rule),
          const Divider(height: 1),
          SizedBox(height: rule),
          _items(context, labels),
          SizedBox(height: rule),
          const Divider(height: 1),
          SizedBox(height: rule),
          _totals(context, labels, currency),
          const SizedBox(height: 6),
          Container(height: 2, color: theme.colorScheme.outline),
          const SizedBox(height: 6),
          _grandTotal(context, labels, currency),
          SizedBox(height: rule),
          const Divider(height: 1),
          SizedBox(height: rule),
          _payments(context, labels, currency),
          if (_hasValue(receipt.fiscalHash)) ...[
            SizedBox(height: rule),
            const Divider(height: 1),
            SizedBox(height: rule),
            Text(
              '${labels['verification']}: ${receipt.fiscalHash}',
              style: _body(context),
            ),
          ],
          SizedBox(height: rule),
          const Divider(height: 1),
          SizedBox(height: rule),
          _footer(context, labels),
          if (receipt.qrPayload.isNotEmpty) ...[
            SizedBox(height: rule),
            // Center (not the stretch column) keeps the QR at its fixed [size]
            // instead of being forced to the card's full width.
            Center(
              child: QrImageView(
                data: receipt.qrPayload,
                version: QrVersions.auto,
                size: dense ? 150.0 : 200.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              receipt.saleNumber,
              textAlign: TextAlign.center,
              style: _body(context, size: dense ? 12.0 : 13.0),
            ),
            const SizedBox(height: 4),
            Text(
              labels['scanHint']!,
              textAlign: TextAlign.center,
              style: _body(context, size: dense ? 10.0 : 11.0, secondary: true),
            ),
          ],
        ],
      ),
    );
  }

  TextStyle _body(
    BuildContext context, {
    bool bold = false,
    double? size,
    bool secondary = false,
  }) =>
      TextStyle(
        fontFamily: 'RobotoMono',
        fontSize: size ?? (dense ? 12.5 : 14.0),
        height: 1.45,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        color: secondary
            ? AppColors.resolveTextSecondary(context)
            : AppColors.resolveTextPrimary(context),
      );

  static bool _hasValue(String? value) =>
      value != null && value.trim().isNotEmpty;

  Widget _bannerLine(BuildContext context, String text) => Text(
        text,
        textAlign: TextAlign.center,
        style: _body(context, bold: true, size: dense ? 14.0 : 16.0),
      );

  Widget _centered(BuildContext context, String text) => Text(
        text,
        textAlign: TextAlign.center,
        style: _body(context, size: dense ? 12.5 : 14.0),
      );

  Widget _header(BuildContext context, Map<String, String> labels) {
    final rows = <Widget>[
      Text(
        receipt.businessName,
        textAlign: TextAlign.center,
        style: _body(context, bold: true, size: dense ? 17.0 : 20.0),
      ),
    ];

    if (_hasValue(customization?.headerTagline)) {
      rows.add(Text(
        customization!.headerTagline!,
        textAlign: TextAlign.center,
        style: _body(context, size: dense ? 12.0 : 13.5).copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ));
    }

    void addIfPresent(String? value, String prefix) {
      if (!_hasValue(value)) return;
      rows.add(prefix.isEmpty
          ? _centered(context, value!)
          : _centered(context, '$prefix: $value'));
    }

    addIfPresent(receipt.branchName, '');
    addIfPresent(receipt.address, '');
    addIfPresent(receipt.phone, labels['phone']!);
    addIfPresent(receipt.email, labels['email']!);
    final showTin = customization?.showTin ?? true;
    if (showTin) {
      addIfPresent(receipt.tin, labels['taxNo']!);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 3),
          rows[i],
        ],
      ],
    );
  }

  Widget _meta(BuildContext context, Map<String, String> labels) {
    final showCashier = customization?.showCashier ?? true;
    final showCustomer = customization?.showCustomer ?? true;
    final rows = <MapEntry<String, String>>[
      MapEntry(labels['receiptNo']!, receipt.saleNumber),
      MapEntry(labels['dateTime']!, receiptDate(receipt.saleDate)),
      if (showCashier && _hasValue(receipt.cashierName))
        MapEntry(labels['cashier']!, receipt.cashierName!),
      if (showCustomer)
        MapEntry(
          labels['customer']!,
          _hasValue(receipt.customerName)
              ? receipt.customerName!.trim()
              : labels['walkIn']!,
        ),
    ];
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: EdgeInsets.symmetric(vertical: dense ? 1 : 2),
            child: Row(
              children: [
                Text(row.key, style: _body(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    row.value,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _body(context, bold: true),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _items(BuildContext context, Map<String, String> labels) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(labels['colItem']!, style: _body(context, bold: true)),
            Text(labels['colTotal']!, style: _body(context, bold: true)),
          ],
        ),
        const SizedBox(height: 6),
        const Divider(height: 1),
        const SizedBox(height: 8),
        for (var i = 0; i < receipt.lines.length; i++) ...[
          if (i > 0) SizedBox(height: dense ? 6 : 8),
          _itemTwoLine(context, receipt.lines[i]),
        ],
      ],
    );
  }

  Widget _itemTwoLine(BuildContext context, ReceiptLine line) {
    final qtyStr = receiptQuantity(line.quantity);
    final unitPriceStr = receiptMoneyBare(line.unitPrice);
    final lineTotalStr = receiptMoneyBare(line.lineTotal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Line 1: Full product name (never truncated by columns)
        Text(
          line.productName,
          style: _body(context, bold: true),
        ),
        const SizedBox(height: 2),
        // Line 2: "1 x 1,000.00" on left, line total on right
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '  $qtyStr x $unitPriceStr',
              style: _body(context).copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              lineTotalStr,
              style: _body(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _totals(
      BuildContext context, Map<String, String> labels, String currency) {
    final rows = <MapEntry<String, String>>[
      MapEntry(
        labels['subtotal']!,
        receiptMoney(receipt.subtotal, currency: currency),
      ),
    ];
    if (receipt.discountAmount > 0) {
      final pct = receiptDiscountPercent(
        subtotal: receipt.subtotal,
        discountAmount: receipt.discountAmount,
      );
      rows.add(MapEntry(
        '${labels['discount']} ($pct%)',
        receiptMoneyNegative(receipt.discountAmount, currency: currency),
      ));
    }
    return _valueRows(context, rows);
  }

  Widget _grandTotal(
          BuildContext context, Map<String, String> labels, String currency) =>
      _valueRows(
        context,
        [
          MapEntry(
            labels['grandTotal']!,
            receiptMoney(receipt.totalAmount, currency: currency),
          ),
        ],
        bold: true,
        size: dense ? 14.0 : 16.0,
      );

  Widget _payments(
      BuildContext context, Map<String, String> labels, String currency) {
    final reference = receipt.payments
        .map((p) => p.reference)
        .firstWhere((r) => _hasValue(r), orElse: () => null);
    final rows = <MapEntry<String, String>>[
      MapEntry(
        labels['paidAmount']!,
        receiptMoney(receipt.amountPaid, currency: currency),
      ),
      MapEntry(
        labels['paymentMethod']!,
        receipt.payments.map((p) => p.method).join(' + '),
      ),
      if (_hasValue(reference)) MapEntry(labels['transactionId']!, reference!),
    ];
    if (receipt.change > 0) {
      rows.add(MapEntry(
        labels['change']!,
        receiptMoney(receipt.change, currency: currency),
      ));
    }
    return _valueRows(context, rows);
  }

  Widget _valueRows(
    BuildContext context,
    List<MapEntry<String, String>> rows, {
    bool bold = false,
    double? size,
  }) {
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: EdgeInsets.symmetric(vertical: dense ? 1 : 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    row.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _body(context, bold: bold, size: size),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  row.value,
                  textAlign: TextAlign.right,
                  style: _body(context, bold: bold, size: size),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _footer(BuildContext context, Map<String, String> labels) {
    final thanksNote = _hasValue(customization?.footerThanks)
        ? customization!.footerThanks!
        : labels['footerThanks']!;
    final policyNote = _hasValue(customization?.footerPolicy)
        ? customization!.footerPolicy!
        : labels['footerPolicy1']!;

    final lines = [
      thanksNote,
      policyNote,
      if (_hasValue(customization?.footerContact))
        customization!.footerContact!
      else
        labels['footerPolicy2']!,
      labels['footerBrand']!,
    ];
    return Column(
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) const SizedBox(height: 3),
          _centered(context, lines[i]),
        ],
      ],
    );
  }
}
