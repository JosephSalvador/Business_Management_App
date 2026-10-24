/// Receipt rendering engine. Renders receipt data into printable text formats.
library;

import 'receipt_customization.dart';
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
    ReceiptCustomization? customization,
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
      'taxNo': 'TIN',
      'receiptNo': 'Receipt No.',
      'dateTime': 'Date / Time',
      'cashier': 'Cashier',
      'customer': 'Customer',
      'walkIn': 'Walk-in Customer',
      'colItem': 'ITEM',
      'colQty': 'Qty',
      'colPrice': 'Price',
      'colTotal': 'TOTAL',
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
      'taxNo': 'TIN',
      'receiptNo': 'Risiti Na.',
      'dateTime': 'Tarehe / Muda',
      'cashier': 'Muuzaji',
      'customer': 'Mteja',
      'walkIn': 'Mteja wa kupita-njia',
      'colItem': 'BIDHAA',
      'colQty': 'Kiasi',
      'colPrice': 'Bei',
      'colTotal': 'JUMLA',
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

/// Thermal receipt renderer supporting both 80mm and 58mm paper widths.
///
/// The renderer is the single source of truth for receipt layout: it emits
/// every line already positioned inside [lineWidth] columns (centered header,
/// right-aligned money column). Printers receive the text verbatim — see
/// `buildEscPosBytes`, which only adds bold and the QR image.
class Thermal80mmRenderer implements ReceiptRenderer {
  const Thermal80mmRenderer({
    this.lineWidth = receiptLineWidth,
    this.metaLabelWidth = receiptMetaLabelWidth,
    this.language = ReceiptLanguage.english,
  });

  /// Factory constructor to configure renderer for a specific [ReceiptPaperWidth].
  factory Thermal80mmRenderer.forWidth(
    ReceiptPaperWidth width, {
    ReceiptLanguage language = ReceiptLanguage.english,
  }) =>
      Thermal80mmRenderer(
        lineWidth: width.lineWidth,
        metaLabelWidth: width.metaLabelWidth,
        language: language,
      );

  /// 58mm preset (32 columns, handheld Bluetooth POS).
  factory Thermal80mmRenderer.mm58({
    ReceiptLanguage language = ReceiptLanguage.english,
  }) =>
      Thermal80mmRenderer.forWidth(ReceiptPaperWidth.mm58, language: language);

  /// 80mm preset (42 columns, standard counter printer).
  factory Thermal80mmRenderer.mm80({
    ReceiptLanguage language = ReceiptLanguage.english,
  }) =>
      Thermal80mmRenderer.forWidth(ReceiptPaperWidth.mm80, language: language);

  /// The character width of the thermal paper (42 chars for 80mm, 32 chars for 58mm).
  final int lineWidth;

  /// Width allocated for meta labels before the colon separator.
  final int metaLabelWidth;

  /// The language for receipt labels.
  final ReceiptLanguage language;

  @override
  String render({
    required ReceiptPreview receipt,
    bool isReprint = false,
    ReceiptCustomization? customization,
  }) {
    final labels = ReceiptLabels.of(language);
    final out = <String>[];
    final rule = '-' * lineWidth;
    final currency = receipt.currency;

    if (isReprint) {
      out.add(_center(labels['reprint']!));
      out.add(rule);
    }
    if (receipt.isVoided) {
      out.add(_center(labels['voided']!));
      out.add(rule);
    }

    // Business header — centered, every line omitted when it has no value.
    void center(String text) {
      for (final part in _wrap(text, lineWidth)) {
        out.add(_center(part));
      }
    }

    center(receipt.businessName);
    if (_hasValue(customization?.headerTagline)) {
      center(customization!.headerTagline!);
    }
    if (_hasValue(receipt.branchName)) center(receipt.branchName!);
    if (_hasValue(receipt.address)) center(receipt.address!);
    if (_hasValue(receipt.phone)) {
      center('${labels['phone']}: ${receipt.phone}');
    }
    if (_hasValue(receipt.email)) {
      center('${labels['email']}: ${receipt.email}');
    }
    final showTin = customization?.showTin ?? true;
    if (showTin && _hasValue(receipt.tin)) {
      center('${labels['taxNo']}: ${receipt.tin}');
    }

    // Meta block — label column of 16, then ": value".
    out.add(rule);
    out.add(_metaRow(labels['receiptNo']!, receipt.saleNumber));
    out.add(_metaRow(labels['dateTime']!, receiptDate(receipt.saleDate)));
    final showCashier = customization?.showCashier ?? true;
    if (showCashier && _hasValue(receipt.cashierName)) {
      out.add(_metaRow(labels['cashier']!, receipt.cashierName!));
    }
    final showCustomer = customization?.showCustomer ?? true;
    if (showCustomer) {
      out.add(_metaRow(labels['customer']!, _customerName(receipt, labels)));
    }

    // Item section — 2-column header (ITEM / TOTAL) and 2-line wrapped items.
    out.add(rule);
    if (receipt.lines.isNotEmpty) {
      out.add(_row(labels['colItem']!, labels['colTotal']!));
      out.add(rule);
      for (final line in receipt.lines) {
        // Line 1: Full product name word-wrapped across lineWidth
        for (final part in _wrap(line.productName, lineWidth)) {
          out.add(_fit(part));
        }
        // Line 2: Indented "  qty x price" on left, line total on right
        final qtyStr = receiptQuantity(line.quantity);
        final unitPriceStr = receiptMoneyBare(line.unitPrice);
        final lineTotalStr = receiptMoneyBare(line.lineTotal);
        out.add(_row('  $qtyStr x $unitPriceStr', lineTotalStr));
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
      out.add(_center('[QR CODE]'));
      out.add(_center(receipt.saleNumber));
      out.add(rule);
    }

    // Footer section — uses tenant custom messages when configured
    final thanksNote = _hasValue(customization?.footerThanks)
        ? customization!.footerThanks!
        : labels['footerThanks']!;
    out.add(_center(thanksNote));

    final policyNote = _hasValue(customization?.footerPolicy)
        ? customization!.footerPolicy!
        : labels['footerPolicy1']!;
    for (final line in _wrap(policyNote, lineWidth)) {
      out.add(_center(line));
    }

    if (_hasValue(customization?.footerContact)) {
      for (final line in _wrap(customization!.footerContact!, lineWidth)) {
        out.add(_center(line));
      }
    } else {
      out.add(_center(labels['footerPolicy2']!));
    }

    out.add(_center(labels['footerBrand']!));

    return out.map(_fit).join('\n');
  }

  static bool _hasValue(String? value) =>
      value != null && value.trim().isNotEmpty;

  static String _customerName(
      ReceiptPreview receipt, Map<String, String> labels) {
    final name = receipt.customerName;
    return _hasValue(name) ? name!.trim() : labels['walkIn']!;
  }

  /// Label padded to [metaLabelWidth], then `: value`.
  String _metaRow(String label, String value) {
    final prefix = '${label.padRight(metaLabelWidth)}: ';
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

/// Generalized alias for the thermal receipt renderer supporting multiple widths.
typedef ThermalReceiptRenderer = Thermal80mmRenderer;
