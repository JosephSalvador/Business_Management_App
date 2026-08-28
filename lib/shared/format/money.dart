import 'package:intl/intl.dart';

final NumberFormat _grouped = NumberFormat.decimalPattern();

/// Formats an amount for display, e.g. 2500 → "TSh 2,500" and 2500.5 →
/// "TSh 2,500.50". [symbol] defaults to the Tanzanian shilling sign.
String formatMoney(double amount, {String symbol = 'TSh'}) {
  final formatted = (amount * 100).truncate() % 100 == 0
      ? _grouped.format(amount.round())
      : NumberFormat('#,##0.00').format(amount);
  return symbol.isEmpty ? formatted : '$symbol $formatted';
}
