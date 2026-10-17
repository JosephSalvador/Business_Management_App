import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr/qr.dart' as qr;
import 'package:share_plus/share_plus.dart';

import '../../../core/storage/locale_store.dart';
import '../../receipts/data/receipt_providers.dart';
import '../../receipts/domain/receipt_format.dart';
import '../../receipts/domain/receipt_preview.dart';
import '../../receipts/domain/receipt_qr.dart';
import '../../receipts/domain/receipt_renderer.dart';
import '../domain/sale.dart';
import 'web_bluetooth/web_bluetooth_printer.dart';

class ReceiptPrinterService {
  final Thermal80mmRenderer _renderer;

  ReceiptPrinterService({
    ReceiptLanguage language = ReceiptLanguage.english,
    ReceiptPaperWidth paperWidth = ReceiptPaperWidth.mm80,
  }) : _renderer = Thermal80mmRenderer.forWidth(paperWidth, language: language);

  /// Encodes a receipt as ESC/POS bytes for a thermal printer.
  ///
  /// The renderer already emits every line positioned inside the paper width
  /// (centered header, right-aligned money column), so text is sent verbatim.
  /// The printer only adds what plain text cannot express: bold emphasis and
  /// the QR raster image. Re-centering here would double-shift the lines.
  List<int> buildEscPosBytes({
    required ReceiptPreview receipt,
    bool isReprint = false,
  }) {
    final bytes = <int>[];
    final lines =
        _renderer.render(receipt: receipt, isReprint: isReprint).split('\n');

    bytes.addAll([0x1B, 0x40]); // Initialize
    bytes.addAll([0x1B, 0x61, 0x00]); // Left align — layout is renderer-owned

    var businessNamePrinted = false;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // QR marker → print the actual QR image instead of the placeholder line.
      if (trimmed == '[QR CODE]' && receipt.qrPayload.isNotEmpty) {
        bytes.addAll([0x1B, 0x61, 0x01]); // Center the raster image
        bytes.addAll(
            _buildQrRaster(receipt.qrPayload, moduleSize: 3, margin: 1));
        bytes.addAll([0x0A]);
        bytes.addAll([0x1B, 0x61, 0x00]); // Back to left align
        continue;
      }

      final isSeparator =
          trimmed.startsWith('---') || trimmed.startsWith('===');
      final isTotal = trimmed.startsWith('GRAND TOTAL') ||
          trimmed.startsWith('TOTAL') ||
          trimmed.startsWith('JUMLA');
      final isWatermark = trimmed.startsWith('***');
      final isItemHeader = trimmed.contains('Qty') || trimmed.contains('Kiasi');
      final isBusinessName = !businessNamePrinted &&
          !isWatermark &&
          !isSeparator &&
          !isTotal &&
          !isItemHeader;

      // Bold: watermark rules, the business name, separator rules,
      // the item header row and the GRAND TOTAL row.
      final bold = isWatermark ||
          isSeparator ||
          isTotal ||
          isItemHeader ||
          isBusinessName;
      if (isBusinessName) businessNamePrinted = true;

      if (bold) bytes.addAll([0x1B, 0x45, 0x01]); // Bold on
      bytes.addAll(_encodeUtf8(line));
      bytes.addAll([0x0A]); // Line feed
      if (bold) bytes.addAll([0x1B, 0x45, 0x00]); // Bold off
    }

    bytes.addAll([0x1B, 0x64, 0x03]); // Feed 3 lines
    bytes.addAll([0x1D, 0x56, 0x00]); // Partial cut

    return bytes;
  }

  List<int> _encodeUtf8(String text) {
    final bytes = <int>[];
    for (final rune in text.runes) {
      if (rune < 0x80) {
        bytes.add(rune);
      } else if (rune < 0x800) {
        bytes.add(0xC0 | (rune >> 6));
        bytes.add(0x80 | (rune & 0x3F));
      } else if (rune < 0x10000) {
        bytes.add(0xE0 | (rune >> 12));
        bytes.add(0x80 | ((rune >> 6) & 0x3F));
        bytes.add(0x80 | (rune & 0x3F));
      } else {
        bytes.add(0xF0 | (rune >> 18));
        bytes.add(0x80 | ((rune >> 12) & 0x3F));
        bytes.add(0x80 | ((rune >> 6) & 0x3F));
        bytes.add(0x80 | (rune & 0x3F));
      }
    }
    return bytes;
  }

  List<int> _buildQrRaster(String data, {int moduleSize = 3, int margin = 2}) {
    final qrCode = qr.QrCode.fromData(
      data: data,
      errorCorrectLevel: qr.QrErrorCorrectLevel.M,
    );

    final qrImage = qr.QrImage(qrCode);
    final moduleCount = qrImage.moduleCount;
    final size = moduleCount * moduleSize + margin * 2 * moduleSize;

    final pixels = List<int>.filled(size * size, 0); // 0 = white

    // Draw QR modules
    for (var row = 0; row < moduleCount; row++) {
      for (var col = 0; col < moduleCount; col++) {
        if (qrImage.isDark(row, col)) {
          // Fill moduleSize x moduleSize pixels
          for (var dy = 0; dy < moduleSize; dy++) {
            for (var dx = 0; dx < moduleSize; dx++) {
              final px = (margin + col) * moduleSize + dx;
              final py = (margin + row) * moduleSize + dy;
              if (px < size && py < size) {
                pixels[py * size + px] = 1; // black
              }
            }
          }
        }
      }
    }

    return _buildEscPosImage(pixels, size, size);
  }

  List<int> _buildEscPosImage(List<int> pixels, int width, int height) {
    final bytes = <int>[];

    // Use GS v 0 (raster bit image)
    bytes.addAll([0x1D, 0x76, 0x30, 0x00]);

    final bytesPerRow = (width + 7) ~/ 8;
    final dataBytes = <int>[];

    for (var y = 0; y < height; y++) {
      for (var xByte = 0; xByte < bytesPerRow; xByte++) {
        var byte = 0;
        for (var bit = 0; bit < 8; bit++) {
          final x = xByte * 8 + bit;
          if (x < width && pixels[y * width + x] == 1) {
            byte |= (0x80 >> bit);
          }
        }
        dataBytes.add(byte);
      }
    }

    bytes.addAll([bytesPerRow & 0xFF, (bytesPerRow >> 8) & 0xFF]);
    bytes.addAll([height & 0xFF, (height >> 8) & 0xFF]);
    bytes.addAll(dataBytes);

    return bytes;
  }

  Future<bool> printToDevice({
    required String address,
    required ReceiptPreview receipt,
    bool isReprint = false,
  }) async {
    try {
      final bytes = buildEscPosBytes(receipt: receipt, isReprint: isReprint);
      await FlutterBluetoothPrinter.printBytes(
        address: address,
        data: Uint8List.fromList(bytes),
        keepConnected: true,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  bool get canPrintViaBluetooth => !kIsWeb && Platform.isAndroid;

  bool get hasWebBluetooth => webBluetoothPrinter.isSupported;

  bool get canPrintDirectly => canPrintViaBluetooth || hasWebBluetooth;

  Future<bool> printViaWebBluetooth({
    required ReceiptPreview receipt,
    bool isReprint = false,
  }) async {
    try {
      final bytes = buildEscPosBytes(receipt: receipt, isReprint: isReprint);
      return await webBluetoothPrinter.printBytes(Uint8List.fromList(bytes));
    } catch (_) {
      return false;
    }
  }

  Future<bool> printUniversal({
    required ReceiptPreview receipt,
    String? bluetoothAddress,
    bool isReprint = false,
  }) async {
    if (canPrintViaBluetooth && bluetoothAddress != null) {
      return printToDevice(
        address: bluetoothAddress,
        receipt: receipt,
        isReprint: isReprint,
      );
    } else if (hasWebBluetooth) {
      return printViaWebBluetooth(receipt: receipt, isReprint: isReprint);
    }
    return false;
  }

  String buildReceiptText({
    required ReceiptPreview receipt,
    bool isReprint = false,
  }) {
    return _renderer.render(receipt: receipt, isReprint: isReprint);
  }

  /// Builds a minimal ReceiptPreview from a SaleDto for backward compatibility.
  ///
  /// The server-side preview is authoritative — this is only the offline/just-closed
  /// path where the sale has not been re-read from the API. Identity fields the
  /// [SaleDto] does not carry are passed in by the caller when known.
  ReceiptPreview saleToReceipt({
    required SaleDto sale,
    required String businessName,
    String? tin,
    String? address,
    String? phone,
    String? email,
    String? branchName,
    String? cashierName,
  }) {
    return ReceiptPreview(
      saleId: sale.id,
      saleNumber: sale.number,
      saleDate: sale.saleDate,
      isVoided: sale.isVoided,
      hasMetadata: false,
      isReprint: false,
      printCount: 0,
      businessName: businessName,
      tin: tin,
      address: address,
      phone: phone,
      email: email,
      branchName: branchName,
      cashierName: cashierName,
      customerName: sale.customerName,
      currency: sale.currency,
      qrPayload: buildQrPayload(
        businessName: businessName,
        saleNumber: sale.number,
        totalAmount: sale.totalAmount,
        saleDate: sale.saleDate,
        currency: sale.currency,
      ),
      lines: sale.lines
          .map((l) => ReceiptLine(
                productName: l.productName,
                quantity: l.quantity,
                unitPrice: l.unitPrice,
                discountAmount: l.discountAmount,
                lineTotal: l.lineTotal,
                taxCode: l.taxCode,
                taxAmount: l.taxAmount,
              ))
          .toList(),
      payments: sale.payments
          .map((p) => ReceiptPayment(
                method: p.label,
                amount: p.amount,
                reference: p.reference,
              ))
          .toList(),
      subtotal: sale.subtotal,
      taxAmount: sale.taxAmount,
      discountAmount: sale.discountAmount,
      totalAmount: sale.totalAmount,
      amountPaid: sale.amountPaid,
      change: sale.change,
    );
  }

  Future<bool> shareReceipt({
    required ReceiptPreview receipt,
    bool isReprint = false,
  }) async {
    final text = _renderer.render(receipt: receipt, isReprint: isReprint);
    await SharePlus.instance.share(ShareParams(text: text));
    return true;
  }

  Future<pw.Document> buildReceiptPdf({
    required ReceiptPreview receipt,
    bool isReprint = false,
  }) async {
    final pdf = pw.Document();
    final receiptText =
        _renderer.render(receipt: receipt, isReprint: isReprint);
    final lines = receiptText.split('\n');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll57,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              pw.Text(
                line,
                style: pw.TextStyle(
                  font: pw.Font.courier(),
                  fontSize: 9,
                ),
              ),
          ],
        ),
      ),
    );

    return pdf;
  }
}

/// Printer service for the app locale — the ticket language follows the
/// language the user is reading the UI in, and width follows the configured paper size.
final receiptPrinterServiceProvider = Provider<ReceiptPrinterService>((ref) {
  final locale = ref.watch(localeControllerProvider);
  final paperWidth = ref.watch(receiptPaperWidthProvider);
  return ReceiptPrinterService(
    language: receiptLanguageForCode(locale.languageCode),
    paperWidth: paperWidth,
  );
});
