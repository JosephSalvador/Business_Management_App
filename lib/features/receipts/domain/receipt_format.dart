/// Shared receipt formatting rules.
///
/// Both the thermal text renderer and the on-screen ticket widget format money,
/// dates, quantities and percentage rows through these helpers so the printed
/// and rendered receipts can never drift apart (see docs/ArchitectureRules.md —
/// no duplicated business formatting across layers).
library;

import 'package:intl/intl.dart';

import '../../../shared/format/money.dart';

/// Standard thermal paper widths supported by the printing engine.
enum ReceiptPaperWidth {
  /// 58 mm paper stock (standard for handheld Bluetooth POS terminals, 32 columns).
  mm58(32, 11),

  /// 80 mm paper stock (standard for counter thermal receipt printers, 42 columns).
  mm80(42, 16);

  const ReceiptPaperWidth(this.lineWidth, this.metaLabelWidth);

  /// Character width of this paper stock.
  final int lineWidth;

  /// Width allocated for meta labels before the colon separator.
  final int metaLabelWidth;
}

/// Character width of the thermal paper (42 columns for 80 mm stock default).
const int receiptLineWidth = 42;

/// Character width for 58 mm stock (portable handheld terminals).
const int receiptLineWidth58 = 32;

/// Column width of the receipt meta labels (`Receipt No.`, `Cashier`, …) for 80mm.
const int receiptMetaLabelWidth = 16;

/// Column width of the receipt meta labels for 58mm.
const int receiptMetaLabelWidth58 = 11;

final NumberFormat _whole = NumberFormat('#,##0');

/// The display symbol printed on receipt money rows for [currencyCode].
///
/// The receipt prints the tenant's ISO code as-is (`TZS 23.75`) so the figure
/// matches the currency stored on the sale. Unknown/empty codes fall back to
/// the platform default (`TZS`).
String receiptCurrency(String? currencyCode) {
  final code = (currencyCode ?? '').trim();
  return code.isEmpty ? 'TZS' : code.toUpperCase();
}

/// Money for a totals/payment row: `TZS 23.75` — always two decimals so
/// figures line up in the right-hand column.
String receiptMoney(num amount, {required String currency}) => formatMoney(
      amount.toDouble(),
      symbol: receiptCurrency(currency),
      alwaysDecimals: true,
    );

/// Money for a negated row: `-TZS 1.19`.
String receiptMoneyNegative(num amount, {required String currency}) =>
    '-${receiptMoney(amount, currency: currency)}';

/// Bare amount for the item table columns: `2.50`, `1,250.00`.
///
/// The currency symbol is omitted here on purpose — column width is the
/// binding constraint at 42 characters; every totals row carries the symbol.
String receiptMoneyBare(num amount) =>
    formatPriceValue(amount.toDouble(), alwaysDecimals: true);

/// Quantity column: whole numbers print bare (`2`), fractions print two
/// decimals (`2.50`) so the column never widens unexpectedly.
String receiptQuantity(num quantity) => quantity % 1 == 0
    ? quantity.round().toString()
    : quantity.toStringAsFixed(2);

/// Receipt date: `dd-MMM-yyyy hh:mm a` → `01-Jun-2025 10:24 AM`.
String receiptDate(DateTime time) {
  final local = time.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final day = local.day.toString().padLeft(2, '0');
  final month = months[local.month - 1];
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final meridiem = local.hour < 12 ? 'AM' : 'PM';
  return '$day-$month-${local.year} $hour12:$minute $meridiem';
}

/// Whole percent discount of the receipt: `discountAmount / subtotal * 100`.
/// Returns `0` for a zero subtotal (no discount row is printed anyway).
int receiptDiscountPercent({
  required double subtotal,
  required double discountAmount,
}) {
  if (subtotal <= 0 || discountAmount <= 0) return 0;
  return (discountAmount / subtotal * 100).round();
}

/// Groups a whole amount: `8720` → `8,720`.
String receiptWholeAmount(num amount) => _whole.format(amount);
