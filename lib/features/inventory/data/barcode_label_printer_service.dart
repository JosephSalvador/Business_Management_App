import 'dart:typed_data';
import 'package:barcode_widget/barcode_widget.dart' as bw;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/barcode/barcode_generator_service.dart';
import '../../../../core/storage/barcode_settings_store.dart';
import '../../../../shared/format/money.dart';

class LabelPrintItem {
  const LabelPrintItem({
    required this.productName,
    required this.barcode,
    this.price,
    this.sku,
    this.storeName,
    this.quantity = 1,
  });

  final String productName;
  final String barcode;
  final double? price;
  final String? sku;
  final String? storeName;
  final int quantity;
}

class BarcodeLabelPrinterService {
  const BarcodeLabelPrinterService();

  static const double mmToPt = 72.0 / 25.4;

  bw.Barcode _resolveBarcode(String code) {
    final format = BarcodeGeneratorService.detectFormat(code);
    switch (format) {
      case BarcodeFormatKind.ean13:
        if (BarcodeGeneratorService.isValidEan13(code)) {
          return bw.Barcode.ean13();
        }
        return bw.Barcode.code128();
      case BarcodeFormatKind.upcA:
        if (BarcodeGeneratorService.isValidUpcA(code)) {
          return bw.Barcode.upcA();
        }
        return bw.Barcode.code128();
      case BarcodeFormatKind.code128:
      case BarcodeFormatKind.qrCode:
        return bw.Barcode.code128();
    }
  }

  /// Builds a PDF document containing single or multiple sticker labels
  /// sized to ANY arbitrary width (mm) and height (mm).
  Future<Uint8List> buildStickerPdf({
    required LabelPrintItem item,
    required double widthMm,
    required double heightMm,
    required BarcodeSettings settings,
    int copies = 1,
  }) async {
    final pdf = pw.Document();

    final widthPt = widthMm * mmToPt;
    final heightPt = heightMm * mmToPt;
    final pageFormat = PdfPageFormat(widthPt, heightPt, marginAll: 2 * mmToPt);

    final isCompact = heightMm < 25.0;
    final barcodeEngine = _resolveBarcode(item.barcode);

    for (int i = 0; i < copies; i++) {
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (pw.Context context) {
            return pw.Container(
              width: double.infinity,
              height: double.infinity,
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // Store Header (if height permits and enabled)
                  if (!isCompact &&
                      settings.showStoreName &&
                      item.storeName != null &&
                      item.storeName!.isNotEmpty)
                    pw.Text(
                      item.storeName!.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: (heightMm * 0.12).clamp(7.0, 11.0),
                        fontWeight: pw.FontWeight.bold,
                      ),
                      maxLines: 1,
                    ),

                  // Product Name
                  pw.Text(
                    item.productName,
                    style: pw.TextStyle(
                      fontSize: (heightMm * 0.16).clamp(8.0, 13.0),
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                    maxLines: isCompact ? 1 : 2,
                    overflow: pw.TextOverflow.clip,
                  ),

                  // Barcode Graphic + Text
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                      child: pw.BarcodeWidget(
                        barcode: barcodeEngine,
                        data: item.barcode,
                        drawText: true,
                        textStyle: pw.TextStyle(
                          fontSize: (heightMm * 0.14).clamp(6.5, 10.0),
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // Bottom Row: Price & SKU
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      if (settings.showSku &&
                          item.sku != null &&
                          item.sku!.isNotEmpty)
                        pw.Text(
                          'SKU: ${item.sku}',
                          style: pw.TextStyle(
                            fontSize: (heightMm * 0.12).clamp(6.0, 9.0),
                          ),
                        )
                      else
                        pw.SizedBox.shrink(),
                      if (settings.showPrice && item.price != null)
                        pw.Text(
                          formatMoney(item.price!),
                          style: pw.TextStyle(
                            fontSize: (heightMm * 0.18).clamp(9.0, 14.0),
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  /// Builds an A4 sheet (24 or 30 labels grid) for standard office desktop printers.
  Future<Uint8List> buildA4SheetPdf({
    required LabelPrintItem item,
    required BarcodeSettings settings,
    int totalLabels = 24,
    int columns = 3,
    int rows = 8,
  }) async {
    final pdf = pw.Document();
    final barcodeEngine = _resolveBarcode(item.barcode);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.GridView(
            crossAxisCount: columns,
            childAspectRatio: 2.2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: List.generate(
              totalLabels,
              (index) => pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                padding: const pw.EdgeInsets.all(6),
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      item.productName,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: pw.TextOverflow.clip,
                    ),
                    pw.Expanded(
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2),
                        child: pw.BarcodeWidget(
                          barcode: barcodeEngine,
                          data: item.barcode,
                          drawText: true,
                          textStyle: const pw.TextStyle(fontSize: 7),
                        ),
                      ),
                    ),
                    if (settings.showPrice && item.price != null)
                      pw.Text(
                        formatMoney(item.price!),
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Spools the label document to system or wireless print services.
  Future<void> printLabel({
    required LabelPrintItem item,
    required double widthMm,
    required double heightMm,
    required BarcodeSettings settings,
    int copies = 1,
    bool asA4Sheet = false,
  }) async {
    final bytes = asA4Sheet
        ? await buildA4SheetPdf(
            item: item,
            settings: settings,
            totalLabels: copies > 0 ? copies : 24,
          )
        : await buildStickerPdf(
            item: item,
            widthMm: widthMm,
            heightMm: heightMm,
            settings: settings,
            copies: copies,
          );

    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: 'Label_${item.productName}_${item.barcode}',
    );
  }
}

final barcodeLabelPrinterServiceProvider =
    Provider<BarcodeLabelPrinterService>((ref) {
  return const BarcodeLabelPrinterService();
});
