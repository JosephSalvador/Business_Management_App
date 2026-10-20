import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr/qr.dart' as qr;
import 'package:share_plus/share_plus.dart';

import '../../../core/storage/locale_store.dart';
import '../../../core/storage/receipt_customization_store.dart';
import '../../receipts/data/receipt_providers.dart';
import '../../receipts/domain/receipt_customization.dart';
import '../../receipts/domain/receipt_format.dart';
import '../../receipts/domain/receipt_preview.dart';
import '../../receipts/domain/receipt_qr.dart';
import '../../receipts/domain/receipt_renderer.dart';
import '../domain/sale.dart';
import 'browser_printer/browser_printer.dart';
import 'web_bluetooth/web_bluetooth_printer.dart';

class ReceiptPrinterService {
  final Thermal80mmRenderer _renderer;
  final ReceiptPaperWidth paperWidth;
  final ReceiptCustomization? customization;

  ReceiptPrinterService({
    ReceiptLanguage language = ReceiptLanguage.english,
    this.paperWidth = ReceiptPaperWidth.mm80,
    this.customization,
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
    final lines = _renderer
        .render(
          receipt: receipt,
          isReprint: isReprint,
          customization: customization,
        )
        .split('\n');

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
      final isItemHeader =
          (trimmed.startsWith('ITEM') && trimmed.contains('TOTAL')) ||
              (trimmed.startsWith('BIDHAA') && trimmed.contains('JUMLA'));
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

  bool get hasBrowserPrinting => browserPrinter.isSupported;

  bool get canPrintDirectly =>
      canPrintViaBluetooth || hasWebBluetooth || hasBrowserPrinting;

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

  String _buildQrSvg(String data, {int size = 150}) {
    if (data.isEmpty) return '';
    try {
      final qrCode = qr.QrCode.fromData(
        data: data,
        errorCorrectLevel: qr.QrErrorCorrectLevel.M,
      );
      final qrImage = qr.QrImage(qrCode);
      final count = qrImage.moduleCount;
      final cellSize = (size / count).toDouble();
      final buf = StringBuffer();
      buf.write(
          '<svg xmlns="http://www.w3.org/2000/svg" width="$size" height="$size" viewBox="0 0 $size $size">');
      buf.write('<rect width="100%" height="100%" fill="#fff"/>');
      for (var r = 0; r < count; r++) {
        for (var c = 0; c < count; c++) {
          if (qrImage.isDark(r, c)) {
            final x = (c * cellSize).toStringAsFixed(2);
            final y = (r * cellSize).toStringAsFixed(2);
            final w = cellSize.toStringAsFixed(2);
            final h = cellSize.toStringAsFixed(2);
            buf.write(
                '<rect x="$x" y="$y" width="$w" height="$h" fill="#000"/>');
          }
        }
      }
      buf.write('</svg>');
      return buf.toString();
    } catch (_) {
      return '';
    }
  }

  String buildReceiptHtml({
    required ReceiptPreview receipt,
    bool isReprint = false,
  }) {
    final qrSvg = _buildQrSvg(receipt.qrPayload);
    final widthMm =
        paperWidth == ReceiptPaperWidth.mm58 ? '58mm' : '80mm';
    final contentWidthMm =
        paperWidth == ReceiptPaperWidth.mm58 ? '48mm' : '72mm';

    final buffer = StringBuffer();
    buffer.write('''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Receipt ${receipt.saleNumber}</title>
<style>
  @page {
    margin: 0;
    size: $widthMm auto;
  }
  * {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
  }
  body {
    font-family: 'Courier New', Courier, monospace;
    font-size: 13px;
    line-height: 1.35;
    color: #000;
    background: #fff;
    width: $contentWidthMm;
    max-width: 100%;
    margin: 0 auto;
    padding: 8px 4px;
  }
  .center { text-align: center; }
  .right { text-align: right; }
  .bold { font-weight: bold; }
  .title { font-size: 16px; font-weight: bold; margin-bottom: 4px; text-transform: uppercase; }
  .dashed { border-top: 1px dashed #000; margin: 6px 0; }
  .solid { border-top: 2px solid #000; margin: 6px 0; }
  .row { display: flex; justify-content: space-between; margin: 2px 0; }
  .row .col-left { flex: 1; text-align: left; }
  .row .col-right { text-align: right; font-weight: 500; }
  .item-table { width: 100%; border-collapse: collapse; margin: 4px 0; }
  .item-table th { text-align: left; font-size: 12px; border-bottom: 1px dashed #000; padding-bottom: 4px; }
  .item-table td { padding: 3px 0; font-size: 12px; vertical-align: top; }
  .grand-total { font-size: 15px; font-weight: bold; }
  .qr-box { display: flex; justify-content: center; margin: 10px 0 6px 0; }
  .footer-text { text-align: center; font-size: 11px; margin-top: 4px; }
  .watermark { text-align: center; font-weight: bold; font-size: 14px; margin-bottom: 6px; }
  @media print {
    body { width: 100%; max-width: 100%; padding: 0; }
  }
</style>
</head>
<body>
''');

    if (isReprint) {
      buffer.write('<div class="watermark center">*** REPRINT ***</div>');
    }
    if (receipt.isVoided) {
      buffer.write('<div class="watermark center">*** SALE VOIDED ***</div>');
    }

    buffer.write('<div class="title center">${receipt.businessName}</div>');
    final tagline = customization?.headerTagline?.trim();
    if (tagline != null && tagline.isNotEmpty) {
      buffer.write(
          '<div class="center" style="font-style:italic;margin-bottom:3px">$tagline</div>');
    }
    final showTin = customization?.showTin ?? true;
    if (showTin && receipt.tin != null && receipt.tin!.isNotEmpty) {
      buffer.write('<div class="center">TIN: ${receipt.tin}</div>');
    }
    if (receipt.address != null && receipt.address!.isNotEmpty) {
      buffer.write('<div class="center">${receipt.address}</div>');
    }
    if (receipt.phone != null && receipt.phone!.isNotEmpty) {
      buffer.write('<div class="center">Tel: ${receipt.phone}</div>');
    }
    if (receipt.branchName != null && receipt.branchName!.isNotEmpty) {
      buffer.write('<div class="center">${receipt.branchName}</div>');
    }

    buffer.write('<div class="dashed"></div>');
    buffer.write(
        '<div class="row"><span class="col-left">Receipt:</span><span class="col-right bold">${receipt.saleNumber}</span></div>');
    buffer.write(
        '<div class="row"><span class="col-left">Date:</span><span class="col-right">${receipt.saleDate.toLocal().toString().substring(0, 16)}</span></div>');
    final showCashier = customization?.showCashier ?? true;
    if (showCashier && receipt.cashierName != null && receipt.cashierName!.isNotEmpty) {
      buffer.write(
          '<div class="row"><span class="col-left">Cashier:</span><span class="col-right">${receipt.cashierName}</span></div>');
    }
    final showCustomer = customization?.showCustomer ?? true;
    if (showCustomer && receipt.customerName != null && receipt.customerName!.isNotEmpty) {
      buffer.write(
          '<div class="row"><span class="col-left">Customer:</span><span class="col-right">${receipt.customerName}</span></div>');
    }

    buffer.write('<div class="dashed"></div>');
    buffer.write(
        '<div class="row bold" style="font-size:12px;margin-bottom:4px"><span class="col-left">ITEM</span><span class="col-right">TOTAL</span></div>');
    buffer.write('<div class="dashed"></div>');
    for (final line in receipt.lines) {
      final qtyStr = receiptQuantity(line.quantity);
      final unitPriceStr = line.unitPrice.toStringAsFixed(0);
      final lineTotalStr = line.lineTotal.toStringAsFixed(0);
      buffer.write('<div style="margin:4px 0">');
      buffer.write(
          '<div class="bold" style="font-size:13px;word-break:break-word">${line.productName}</div>');
      buffer.write(
          '<div class="row" style="font-size:12px;color:#333"><span class="col-left">&nbsp;&nbsp;$qtyStr x $unitPriceStr</span><span class="col-right">$lineTotalStr</span></div>');
      buffer.write('</div>');
    }
    buffer.write('<div class="dashed"></div>');

    buffer.write('<div class="dashed"></div>');
    buffer.write(
        '<div class="row"><span class="col-left">Subtotal:</span><span class="col-right">${receipt.subtotal.toStringAsFixed(0)}</span></div>');
    if (receipt.discountAmount > 0) {
      buffer.write(
          '<div class="row"><span class="col-left">Discount:</span><span class="col-right">-${receipt.discountAmount.toStringAsFixed(0)}</span></div>');
    }
    if (receipt.taxAmount > 0) {
      buffer.write(
          '<div class="row"><span class="col-left">Tax:</span><span class="col-right">${receipt.taxAmount.toStringAsFixed(0)}</span></div>');
    }

    buffer.write('<div class="solid"></div>');
    buffer.write(
        '<div class="row grand-total"><span class="col-left">TOTAL:</span><span class="col-right">${receipt.currency} ${receipt.totalAmount.toStringAsFixed(0)}</span></div>');
    buffer.write('<div class="solid"></div>');

    for (final p in receipt.payments) {
      buffer.write(
          '<div class="row"><span class="col-left">${p.method}:</span><span class="col-right">${p.amount.toStringAsFixed(0)}</span></div>');
    }
    if (receipt.change > 0) {
      buffer.write(
          '<div class="row"><span class="col-left">Change:</span><span class="col-right">${receipt.change.toStringAsFixed(0)}</span></div>');
    }

    if (qrSvg.isNotEmpty) {
      buffer.write('<div class="dashed"></div>');
      buffer.write('<div class="qr-box">$qrSvg</div>');
      buffer.write(
          '<div class="footer-text">Scan to verify receipt</div>');
    }

    buffer.write('<div class="dashed"></div>');
    final thanks = customization?.footerThanks?.trim();
    buffer.write(
        '<div class="footer-text">${(thanks != null && thanks.isNotEmpty) ? thanks : 'Thank you for shopping with us!'}</div>');
    final policy = customization?.footerPolicy?.trim();
    buffer.write(
        '<div class="footer-text">${(policy != null && policy.isNotEmpty) ? policy : 'Goods once sold will not be accepted back.'}</div>');
    final contact = customization?.footerContact?.trim();
    if (contact != null && contact.isNotEmpty) {
      buffer.write(
          '<div class="footer-text">$contact</div>');
    }
    buffer.write(
        '<div class="footer-text bold" style="margin-top:6px">Powered by Jolinx ERP</div>');

    buffer.write('</body></html>');
    return buffer.toString();
  }

  Future<bool> printViaBrowser({
    required ReceiptPreview receipt,
    bool isReprint = false,
  }) async {
    try {
      final html = buildReceiptHtml(receipt: receipt, isReprint: isReprint);
      return await browserPrinter.printHtml(html);
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
    } else if (hasBrowserPrinting) {
      return printViaBrowser(receipt: receipt, isReprint: isReprint);
    }
    return false;
  }

  String buildReceiptText({
    required ReceiptPreview receipt,
    bool isReprint = false,
  }) {
    return _renderer.render(
      receipt: receipt,
      isReprint: isReprint,
      customization: customization,
    );
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
    final text = _renderer.render(
      receipt: receipt,
      isReprint: isReprint,
      customization: customization,
    );
    await SharePlus.instance.share(ShareParams(text: text));
    return true;
  }

  Future<bool> shareReceiptPdf({
    required ReceiptPreview receipt,
    bool isReprint = false,
  }) async {
    final pdf = await buildReceiptPdf(receipt: receipt, isReprint: isReprint);
    final bytes = await pdf.save();
    final safeNumber =
        receipt.saleNumber.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            mimeType: 'application/pdf',
            name: 'receipt-$safeNumber.pdf',
          ),
        ],
      ),
    );
    return true;
  }

  Future<bool> shareReceiptImage({
    required Uint8List pngBytes,
    required String saleNumber,
  }) async {
    final safeNumber =
        saleNumber.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            pngBytes,
            mimeType: 'image/png',
            name: 'receipt-$safeNumber.png',
          ),
        ],
      ),
    );
    return true;
  }

  Future<pw.Document> buildReceiptPdf({
    required ReceiptPreview receipt,
    bool isReprint = false,
  }) async {
    final pdf = pw.Document();
    final receiptText = _renderer.render(
      receipt: receipt,
      isReprint: isReprint,
      customization: customization,
    );
    final lines = receiptText.split('\n');

    pdf.addPage(
      pw.Page(
        pageFormat: paperWidth == ReceiptPaperWidth.mm58
            ? PdfPageFormat.roll57
            : PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              pw.Text(
                line,
                style: pw.TextStyle(
                  font: pw.Font.courier(),
                  fontSize: paperWidth == ReceiptPaperWidth.mm58 ? 8 : 9,
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
  final customization = ref.watch(receiptCustomizationProvider);
  return ReceiptPrinterService(
    language: receiptLanguageForCode(locale.languageCode),
    paperWidth: paperWidth,
    customization: customization,
  );
});
