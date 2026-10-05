/// Receipt rendering engine. Renders receipt data into printable text formats.
library;

import 'dart:math';

import 'receipt_format.dart';
import 'receipt_preview.dart';

/// Abstract interface for receipt renderers. Different formats (thermal 80mm,
/// A4, PDF) implement this interface to produce their specific output.
abstract class ReceiptRenderer {
  /// Renders a receipt preview into the target format (plain text for thermal,
  /// structured text for A4, etc.).
  String render({
    required ReceiptPreview receipt,
    bool isReprint = false,
  });
}

/// Receipt language for labels.
enum ReceiptLanguage {
  english,
  swahili,
}

/// Maps an app locale language code (`en`, `sw`) to the receipt label language,
/// so the printed ticket speaks the language the user is reading the UI in.
ReceiptLanguage receiptLanguageForCode(String? languageCode) =>
    languageCode == 'sw' ? ReceiptLanguage.swahili : ReceiptLanguage.english;

/// Localized labels for receipt rendering.
///
/// [thermalRendererProvider] picks the language from the app locale, so both
/// the on-screen ticket and the printed text share this table.
class ReceiptLabels {
  const ReceiptLabels._();

  static const Map<ReceiptLanguage, Map<String, String>> _labels = {
    ReceiptLanguage.english: {
      'reprint': '*** REPRINT ***',
      'voided': '*** SALE VOIDED ***',
      'phone': 'Phone',
      'email': 'Email',
      'taxNo': 'Tax No',
      'receiptNo': 'Receipt No.',
      'dateTime': 'Date / Time',
      'cashier': 'Cashier',
      'customer': 'Customer',
      'walkIn': 'Walk-in Customer',
      'colItem': 'Item',
      'colQty': 'Qty',
      'colPrice': 'Price',
      'colTotal': 'Total',
      'subtotal': 'Subtotal',
      'discount': 'Discount',
      'grandTotal': 'GRAND TOTAL',
      'paidAmount': 'Paid Amount',
      'paymentMethod': 'Payment Method',
      'transactionId': 'Transaction ID',
      'change': 'Change',
      'verification': 'Verification',
      'scanHint': 'Scan to verify receipt',
      'footerThanks': 'Thank you for shopping with us!',
      'footerPolicy1': 'Goods once sold will not be taken back.',
      'footerPolicy2': 'Visit us again!',
      'footerBrand': 'Jolinx ERP',
    },
    ReceiptLanguage.swahili: {
      'reprint': '*** REPRINT ***',
      'voided': '*** MUAMALA UMEFUTWA ***',
      'phone': 'Simu',
      'email': 'Barua pepe',
      'taxNo': 'Namba ya Kodi',
      'receiptNo': 'Risiti Na.',
      'dateTime': 'Tarehe / Muda',
      'cashier': 'Muuzaji',
      'customer': 'Mteja',
      'walkIn': 'Mteja wa kupita-njia',
      'colItem': 'Bidhaa',
      'colQty': 'Kiasi',
      'colPrice': 'Bei',
      'colTotal': 'Jumla',
      'subtotal': 'Jumla ndogo',
      'discount': 'Punguzo',
      'grandTotal': 'JUMLA',
      'paidAmount': 'Lilipwa',
      'paymentMethod': 'Njia ya Malipo',
      'transactionId': 'Kitambulisho cha Muamala',
      'change': 'Change',
      'verification': 'Thibitisho',
      'scanHint': 'Changanua ili kuthibitisha',
      'footerThanks': 'Asante kwa kununua kwetu!',
      'footerPolicy1': 'Bidhaa zilizouzwa hazirudishwi.',
      'footerPolicy2': 'Zuru tena!',
      'footerBrand': 'Jolinx ERP',
    },
  };

  static Map<String, String> of(ReceiptLanguage lang) =>
      _labels[lang] ?? _labels[ReceiptLanguage.english]!;
}

/// Thermal 80mm receipt renderer.
///
/// The renderer is the single source of truth for receipt layout: it emits
/// every line already positioned inside [lineWidth] columns (centered header,
/// right-aligned money column). Printers receive the text verbatim — see
/// `buildEscPosBytes`, which only adds bold and the QR image.
class Thermal80mmRenderer implements ReceiptRenderer {
  const Thermal80mmRenderer({
    this.lineWidth = receiptLineWidth,
    this.language = ReceiptLanguage.english,
  });

  /// The character width of the thermal paper (42 chars for 80mm standard).
  final int lineWidth;

  /// The language for receipt labels.
  final ReceiptLanguage language;

  @override
  String render({
    required ReceiptPreview receipt,
    bool isReprint = false,
  }) {
    final labels = ReceiptLabels.of(language);
    final out = <String>[];
    final rule = '-' * lineWidth;
    final currency = receipt.currency;

    if (isReprint) {
      out.add(labels['reprint']!);
      out.add(rule);
    }
    if (receipt.isVoided) {
      out.add(labels['voided']!);
      out.add(rule);
    }

    // Business header — centered, every line omitted when it has no value.
    void center(String text) {
      for (final part in _wrap(text, lineWidth)) {
        out.add(_center(part));
      }
    }

    center(receipt.businessName);
    if (_hasValue(receipt.branchName)) center(receipt.branchName!);
    if (_hasValue(receipt.address)) center(receipt.address!);
    if (_hasValue(receipt.phone)) {
      center('${labels['phone']}: ${receipt.phone}');
    }
    if (_hasValue(receipt.email)) {
      center('${labels['email']}: ${receipt.email}');
    }
    if (_hasValue(receipt.tin)) {
      center('${labels['taxNo']}: ${receipt.tin}');
    }

    // Meta block — label column of 16, then ": value".
    out.add(rule);
    out.add(_metaRow(labels['receiptNo']!, receipt.saleNumber));
    out.add(_metaRow(labels['dateTime']!, receiptDate(receipt.saleDate)));
    if (_hasValue(receipt.cashierName)) {
      out.add(_metaRow(labels['cashier']!, receipt.cashierName!));
    }
    out.add(_metaRow(labels['customer']!, _customerName(receipt, labels)));

    // Item table — dynamic column widths so the 4 columns always fit.
    out.add(rule);
    if (receipt.lines.isNotEmpty) {
      final widths = _itemWidths(receipt, labels);
      out.add(_itemRow(
        name: labels['colItem']!,
        qty: labels['colQty']!,
        price: labels['colPrice']!,
        total: labels['colTotal']!,
        widths: widths,
      ));
      out.add(rule);
      for (final line in receipt.lines) {
        out.add(_itemRow(
          name: line.productName,
          qty: receiptQuantity(line.quantity),
          price: receiptMoneyBare(line.unitPrice),
          total: receiptMoneyBare(line.lineTotal),
          widths: widths,
        ));
      }
      out.add(rule);
    }

    // Totals — Subtotal / Discount (n%) / GRAND TOTAL. No tax row: VAT is not
    // implemented yet, so the ticket never derives or prints a tax figure.
    out.add(_row(
      labels['subtotal']!,
      receiptMoney(receipt.subtotal, currency: currency),
    ));
    if (receipt.discountAmount > 0) {
      final pct = receiptDiscountPercent(
        subtotal: receipt.subtotal,
        discountAmount: receipt.discountAmount,
      );
      out.add(_row(
        '${labels['discount']} ($pct%)',
        receiptMoneyNegative(receipt.discountAmount, currency: currency),
      ));
    }
    out.add('=' * lineWidth);
    out.add(_row(
      labels['grandTotal']!,
      receiptMoney(receipt.totalAmount, currency: currency),
    ));

    // Payments — tender rows, with the gateway reference when there is one.
    out.add(rule);
    out.add(_row(
      labels['paidAmount']!,
      receiptMoney(receipt.amountPaid, currency: currency),
    ));
    out.add(_row(
      labels['paymentMethod']!,
      receipt.payments.map((p) => p.method).join(' + '),
    ));
    final reference = receipt.payments
        .map((p) => p.reference)
        .firstWhere((r) => _hasValue(r), orElse: () => null);
    if (_hasValue(reference)) {
      out.add(_row(labels['transactionId']!, reference!));
    }
    if (receipt.change > 0) {
      out.add(_row(
        labels['change']!,
        receiptMoney(receipt.change, currency: currency),
      ));
    }

    // Fiscal + QR — each section prints only when it has content.
    out.add(rule);
    final hash = receipt.fiscalHash;
    if (_hasValue(hash)) {
      out.add(_fit('${labels['verification']}: $hash'));
      out.add(rule);
    }
    if (receipt.qrPayload.isNotEmpty) {
      out.add('[QR CODE]');
      out.add(_center(receipt.saleNumber));
      out.add(rule);
    }

    out.add(labels['footerThanks']!);
    out.add(labels['footerPolicy1']!);
    out.add(labels['footerPolicy2']!);
    out.add(labels['footerBrand']!);

    return out.map(_fit).join('\n');
  }

  static bool _hasValue(String? value) =>
      value != null && value.trim().isNotEmpty;

  static String _customerName(
      ReceiptPreview receipt, Map<String, String> labels) {
    final name = receipt.customerName;
    return _hasValue(name) ? name!.trim() : labels['walkIn']!;
  }

  /// Label padded to [receiptMetaLabelWidth], then `: value`.
  String _metaRow(String label, String value) {
    final prefix = '${label.padRight(receiptMetaLabelWidth)}: ';
    return _fit('$prefix$value');
  }

  /// Label on the left, money right-aligned at the paper edge.
  String _row(String label, String value) {
    final fittedValue =
        value.length > lineWidth ? _truncate(value, lineWidth) : value;
    final free = lineWidth - fittedValue.length;
    final labelRoom = free > 1 ? free - 1 : 0;
    final fittedLabel =
        label.length > labelRoom ? _truncate(label, labelRoom) : label;
    return '${fittedLabel.padRight(free)}$fittedValue';
  }

  /// Character budget of each money column: qty, price, total. The name column
  /// takes whatever is left, so a long money figure can never truncate a value.
  List<int> _itemWidths(ReceiptPreview receipt, Map<String, String> labels) {
    var qtyW = labels['colQty']!.length;
    var priceW = labels['colPrice']!.length;
    var totalW = labels['colTotal']!.length;
    for (final line in receipt.lines) {
      qtyW = max(qtyW, receiptQuantity(line.quantity).length);
      priceW = max(priceW, receiptMoneyBare(line.unitPrice).length);
      totalW = max(totalW, receiptMoneyBare(line.lineTotal).length);
    }
    return [qtyW, priceW, totalW];
  }

  /// One item line (or the column header) using [widths] = qty, price, total.
  String _itemRow({
    required String name,
    required String qty,
    required String price,
    required String total,
    required List<int> widths,
  }) {
    final money =
        '${qty.padLeft(widths[0])} ${price.padLeft(widths[1])} ${total.padLeft(widths[2])}';
    final nameRoom = lineWidth - money.length - 1;
    if (nameRoom <= 0) return _fit(money);
    return '${_padOrTruncate(name, nameRoom)} $money';
  }

  String _padOrTruncate(String text, int width) =>
      text.length > width ? _truncate(text, width) : text.padRight(width);

  String _center(String text) {
    if (text.length >= lineWidth) return _fit(text);
    final padding = (lineWidth - text.length) ~/ 2;
    return '${' ' * padding}$text';
  }

  /// Word-wraps [text] so no produced segment exceeds [max] characters.
  List<String> _wrap(String text, int max) {
    if (text.length <= max) return [text];
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final lines = <String>[];
    var current = '';
    for (final word in words) {
      if (word.length > max) {
        if (current.isNotEmpty) {
          lines.add(current);
          current = '';
        }
        lines.add(_truncate(word, max));
        continue;
      }
      if (current.isEmpty) {
        current = word;
      } else if ('$current $word'.length <= max) {
        current = '$current $word';
      } else {
        lines.add(current);
        current = word;
      }
    }
    if (current.isNotEmpty) lines.add(current);
    return lines.isEmpty ? [text] : lines;
  }

  /// Guarantees a line is exactly [lineWidth] wide — pad right, or truncate
  /// with an ellipsis. Every renderer output line passes through this, so the
  /// width invariant holds no matter what data arrives.
  String _fit(String line) => line.length > lineWidth
      ? _truncate(line, lineWidth)
      : line.padRight(lineWidth);

  static String _truncate(String text, int max) {
    if (max <= 0) return '';
    if (text.length <= max) return text;
    if (max == 1) return '…';
    return '${text.substring(0, max - 1)}…';
  }
}
