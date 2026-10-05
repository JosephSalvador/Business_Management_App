/// QR code utilities for receipt rendering.
///
/// Generates QR payloads for receipt verification. Currently encodes human-readable
/// text that customers can scan to verify receipt authenticity.
///
/// Future: When a domain is available, swap [buildQrPayload] to return a URL
/// like `https://yourdomain.com/receipt/{saleId}` instead of text.
library;

import 'receipt_format.dart';
import 'receipt_preview.dart';

/// Configuration for QR code content.
///
/// Change [mode] to switch between offline text and online URL verification.
class QrConfig {
  const QrConfig._();

  /// QR content mode.
  static const QrMode mode = QrMode.text;

  /// Base URL for URL mode (used when [mode] is [QrMode.url]).
  ///
  /// Example: `'https://app.jolinx.co.tz/receipt'`
  static const String? baseUrl = null;
}

/// QR content mode.
enum QrMode {
  /// Human-readable text (works offline, no domain needed).
  text,

  /// URL that opens a verification page (requires hosted domain).
  url,
}

/// Builds the QR payload from receipt data.
///
/// Always returns a payload — even without fiscal hash, the QR encodes
/// basic sale info (business name, receipt number, total, date).
///
/// [currency] is the tenant's ISO code (e.g. `TZS`) and is printed verbatim so
/// the QR total matches the receipt's GRAND TOTAL row. The QR total stays
/// whole-number — it is verification text, not a ledger figure.
String buildQrPayload({
  required String businessName,
  required String saleNumber,
  required double totalAmount,
  required DateTime saleDate,
  String? fiscalHash,
  String currency = '',
}) {
  switch (QrConfig.mode) {
    case QrMode.url:
      if (QrConfig.baseUrl == null || QrConfig.baseUrl!.isEmpty) {
        return _buildTextPayload(businessName, saleNumber, totalAmount,
            saleDate, fiscalHash, currency);
      }
      return '${QrConfig.baseUrl}/$saleNumber';

    case QrMode.text:
      return _buildTextPayload(businessName, saleNumber, totalAmount, saleDate,
          fiscalHash, currency);
  }
}

String _buildTextPayload(
  String businessName,
  String saleNumber,
  double totalAmount,
  DateTime saleDate,
  String? fiscalHash,
  String currency,
) {
  final dateStr = _formatDate(saleDate);
  final totalStr = _formatTotal(totalAmount);
  final symbol = receiptCurrency(currency);

  final buffer = StringBuffer()
    ..writeln(businessName)
    ..writeln('RISITI: $saleNumber')
    ..writeln('JUMLA: $symbol $totalStr')
    ..writeln('TAREHE: $dateStr');

  if (fiscalHash != null && fiscalHash.isNotEmpty) {
    final shortHash =
        fiscalHash.length > 8 ? fiscalHash.substring(0, 8) : fiscalHash;
    buffer.writeln('THIBITISHO: $shortHash');
  }

  return buffer.toString();
}

/// Builds QR payload from a [ReceiptPreview] model.
String buildQrPayloadFromReceipt(ReceiptPreview receipt) {
  return buildQrPayload(
    businessName: receipt.businessName,
    saleNumber: receipt.saleNumber,
    totalAmount: receipt.totalAmount,
    saleDate: receipt.saleDate,
    fiscalHash: receipt.fiscalHash,
    currency: receipt.currency,
  );
}

String _formatDate(DateTime date) {
  final d = date.toLocal();
  final day = d.day.toString().padLeft(2, '0');
  final month = d.month.toString().padLeft(2, '0');
  final year = d.year;
  return '$day/$month/$year';
}

String _formatTotal(double amount) {
  final formatted = amount.toStringAsFixed(0);
  final parts = formatted.split('');
  final buffer = StringBuffer();
  for (var i = 0; i < parts.length; i++) {
    if (i > 0 && (parts.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(parts[i]);
  }
  return buffer.toString();
}
