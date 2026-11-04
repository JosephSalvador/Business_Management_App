import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/storage/barcode_settings_store.dart';
import 'package:jolinx_app/features/inventory/data/barcode_label_printer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BarcodeLabelPrinterService printerService;

  setUp(() {
    printerService = const BarcodeLabelPrinterService();
  });

  group('BarcodeLabelPrinterService', () {
    const testItem = LabelPrintItem(
      productName: 'Chai Bora Tea 100g',
      barcode: '2000000000107',
      price: 2500,
      sku: 'CHAI-100',
      storeName: 'Jolinx Supermarket',
      quantity: 1,
    );

    const alphanumericItem = LabelPrintItem(
      productName: 'Wireless Mouse Pro',
      barcode: 'JLX-892104',
      price: 35000,
      sku: 'WM-01',
      storeName: 'Jolinx Tech Store',
      quantity: 1,
    );

    test('buildStickerPdf generates non-empty PDF bytes for standard 50x30mm', () async {
      const settings = BarcodeSettings(
        showPrice: true,
        showStoreName: true,
        showSku: true,
      );

      final bytes = await printerService.buildStickerPdf(
        item: testItem,
        widthMm: 50,
        heightMm: 30,
        settings: settings,
        copies: 1,
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
      // PDF documents start with %PDF- header (ASCII: 0x25, 0x50, 0x44, 0x46, 0x2D)
      expect(String.fromCharCodes(bytes.sublist(0, 5)), equals('%PDF-'));
    });

    test('buildStickerPdf handles compact dimensions (e.g. 30x20mm)', () async {
      const settings = BarcodeSettings(
        showPrice: true,
        showStoreName: false,
        showSku: false,
      );

      final bytes = await printerService.buildStickerPdf(
        item: alphanumericItem,
        widthMm: 30,
        heightMm: 20,
        settings: settings,
        copies: 2,
      );

      expect(bytes.isNotEmpty, isTrue);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), equals('%PDF-'));
    });

    test('buildA4SheetPdf generates multi-label sheet grid', () async {
      const settings = BarcodeSettings(
        showPrice: true,
        showStoreName: true,
        showSku: true,
      );

      final bytes = await printerService.buildA4SheetPdf(
        item: testItem,
        settings: settings,
        totalLabels: 24,
        columns: 3,
        rows: 8,
      );

      expect(bytes.isNotEmpty, isTrue);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), equals('%PDF-'));
    });
  });
}
