import 'package:intl/intl.dart';

final NumberFormat _grouped = NumberFormat.decimalPattern();
final NumberFormat _twoDecimals = NumberFormat('#,##0.00');

/// Formats an amount for display, e.g. 2500 → "TSh 2,500" and 2500.5 →
/// "TSh 2,500.50". [symbol] defaults to the Tanzanian shilling sign.
///
/// [alwaysDecimals] forces two decimal places even for whole amounts — the
/// receipt money columns always show `2,500.00` so figures line up.
String formatMoney(
  double amount, {
  String symbol = 'TSh',
  bool alwaysDecimals = false,
}) {
  final formatted = alwaysDecimals
      ? _twoDecimals.format(amount)
      : (amount * 100).truncate() % 100 == 0
          ? _grouped.format(amount.round())
          : _twoDecimals.format(amount);
  return symbol.isEmpty ? formatted : '$symbol $formatted';
}

/// Formats a bare amount with no currency symbol: "2,500" or "2,500.50".
/// Used inside compact rows and chips where the TSh prefix is already shown.
String formatPriceValue(double value, {bool alwaysDecimals = false}) =>
    alwaysDecimals
        ? _twoDecimals.format(value)
        : (value * 100).truncate() % 100 == 0
            ? _grouped.format(value.round())
            : _twoDecimals.format(value);
