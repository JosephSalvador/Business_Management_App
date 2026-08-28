import '../../../shared/format/money.dart';
import 'sale.dart';

/// Builds the plain-text receipt for a completed sale. Pure function so the
/// preview page, sharing and tests all render exactly the same ticket.
String buildReceiptText({
  required SaleDto sale,
  required String businessName,
  DateTime? now,
}) {
  final time = (now ?? DateTime.now()).toLocal();
  final buffer = StringBuffer()
    ..writeln(businessName)
    ..writeln('RISITI: ${sale.number}')
    ..writeln(_formatTimestamp(time))
    ..writeln('-' * 32);

  for (final line in sale.lines) {
    final name = line.productName.length > 20
        ? line.productName.substring(0, 20)
        : line.productName;
    final quantity = line.quantity % 1 == 0
        ? line.quantity.round().toString()
        : line.quantity.toStringAsFixed(2);
    final unit = formatMoney(line.unitPrice, symbol: '');
    final discount = line.discountAmount > 0
        ? ' − ${formatMoney(line.discountAmount)}'
        : '';
    buffer.writeln('$name\n  $quantity × $unit$discount');
    buffer.writeln('     ${formatMoney(line.lineTotal)}');
  }

  buffer
    ..writeln('-' * 32)
    ..writeln('Jumla ndogo: ${formatMoney(sale.subtotal)}')
    ..writeln('Kodi (VAT): ${formatMoney(sale.taxAmount)}');
  if (sale.discountAmount > 0) {
    buffer.writeln('Punguzo: ${formatMoney(sale.discountAmount)}');
  }
  buffer
    ..writeln('JUMLA: ${formatMoney(sale.totalAmount)}')
    ..writeln(
      'Malipo: ${sale.payments.map((payment) => payment.label).join(' + ')}',
    );
  if (sale.isVoided) {
    buffer.writeln('*** MUAMALA UMEFUTWA ***');
  }
  buffer
    ..writeln('-' * 32)
    ..writeln('Asante karibu tena!');
  return buffer.toString();
}

String _formatTimestamp(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}';
}
