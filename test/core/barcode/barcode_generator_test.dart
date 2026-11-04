import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/barcode/barcode_generator_service.dart';
import 'package:jolinx_app/core/storage/barcode_settings_store.dart';

void main() {
  group('BarcodeGeneratorService - Check Digit & Validation', () {
    test('calculateEan13CheckDigit computes correct modulo 10 checksum', () {
      // Known 12-digit payloads
      const payload1 = '200000000010';
      final check1 = BarcodeGeneratorService.calculateEan13CheckDigit(payload1);
      expect(BarcodeGeneratorService.isValidEan13('$payload1$check1'), isTrue);

      // Invalid length should return 0
      expect(BarcodeGeneratorService.calculateEan13CheckDigit('123'), equals(0));

      // Test with known GS1 barcode: 9780201379624 -> check digit 4
      final checkGs1 = BarcodeGeneratorService.calculateEan13CheckDigit('978020137962');
      expect(checkGs1, equals(4));
      expect(BarcodeGeneratorService.isValidEan13('9780201379624'), isTrue);
      expect(BarcodeGeneratorService.isValidEan13('9780201379625'), isFalse);
    });

    test('isValidEan13 checks exact 13 numeric digits and checksum', () {
      expect(BarcodeGeneratorService.isValidEan13('12345'), isFalse);
      expect(BarcodeGeneratorService.isValidEan13('978020137962A'), isFalse);
      expect(BarcodeGeneratorService.isValidEan13('9780201379624'), isTrue);
    });

    test('calculateUpcACheckDigit computes correct 12-digit UPC checksum', () {
      // Known UPC-A payload: 03600029145 -> check digit 2
      final checkUpc = BarcodeGeneratorService.calculateUpcACheckDigit('03600029145');
      expect(checkUpc, equals(2));
      expect(BarcodeGeneratorService.isValidUpcA('036000291452'), isTrue);
      expect(BarcodeGeneratorService.isValidUpcA('036000291453'), isFalse);
      expect(BarcodeGeneratorService.isValidUpcA('0360002914'), isFalse);
    });
  });

  group('BarcodeGeneratorService - Generation', () {
    test('generateCode128 generates formatted alphanumeric codes', () {
      final code1 = BarcodeGeneratorService.generateCode128(prefix: 'TEST', sequence: 42);
      expect(code1, equals('TEST-42'));

      final codeEmptyPrefix = BarcodeGeneratorService.generateCode128(prefix: '', sequence: 999);
      expect(codeEmptyPrefix, equals('999'));

      final codeRandom = BarcodeGeneratorService.generateCode128(prefix: 'JLX');
      expect(codeRandom.startsWith('JLX-'), isTrue);
    });

    test('generateEan13 generates valid 13-digit retail barcode with in-store prefix', () {
      final ean = BarcodeGeneratorService.generateEan13(inStorePrefix: '20', sequence: 100);
      expect(ean.length, equals(13));
      expect(ean.startsWith('20'), isTrue);
      expect(BarcodeGeneratorService.isValidEan13(ean), isTrue);
      expect(BarcodeGeneratorService.detectFormat(ean), equals(BarcodeFormatKind.ean13));
    });

    test('detectFormat correctly classifies formats', () {
      expect(BarcodeGeneratorService.detectFormat('9780201379624'), equals(BarcodeFormatKind.ean13));
      expect(BarcodeGeneratorService.detectFormat('036000291452'), equals(BarcodeFormatKind.upcA));
      expect(BarcodeGeneratorService.detectFormat('JLX-982103'), equals(BarcodeFormatKind.code128));
      expect(BarcodeGeneratorService.detectFormat('SKU12345'), equals(BarcodeFormatKind.code128));
    });

    test('generateFromSettings respects tenant preferences', () {
      const code128Settings = BarcodeSettings(
        symbology: BarcodeSymbologyPreference.code128,
        customPrefix: 'SHOP',
      );
      final code128 = BarcodeGeneratorService.generateFromSettings(code128Settings);
      expect(code128.startsWith('SHOP-'), isTrue);

      const eanSettings = BarcodeSettings(
        symbology: BarcodeSymbologyPreference.ean13,
      );
      final ean = BarcodeGeneratorService.generateFromSettings(eanSettings);
      expect(ean.length, equals(13));
      expect(BarcodeGeneratorService.isValidEan13(ean), isTrue);
    });
  });

  group('BarcodeSettings - Model & Serialization', () {
    test('toJson and fromJson serialize symmetrically', () {
      const settings = BarcodeSettings(
        symbology: BarcodeSymbologyPreference.both,
        customPrefix: 'KVT',
        showPrice: false,
        showStoreName: true,
        showSku: false,
        includeQr: true,
        defaultWidthMm: 40.0,
        defaultHeightMm: 25.0,
        continuousRoll: true,
      );

      final json = settings.toJson();
      final restored = BarcodeSettings.fromJson(json);

      expect(restored.symbology, equals(BarcodeSymbologyPreference.both));
      expect(restored.customPrefix, equals('KVT'));
      expect(restored.showPrice, isFalse);
      expect(restored.showStoreName, isTrue);
      expect(restored.showSku, isFalse);
      expect(restored.includeQr, isTrue);
      expect(restored.defaultWidthMm, equals(40.0));
      expect(restored.defaultHeightMm, equals(25.0));
      expect(restored.continuousRoll, isTrue);
    });

    test('copyWith updates individual fields correctly', () {
      const initial = BarcodeSettings();
      final modified = initial.copyWith(
        customPrefix: 'NEW',
        defaultWidthMm: 60.0,
      );

      expect(modified.customPrefix, equals('NEW'));
      expect(modified.defaultWidthMm, equals(60.0));
      expect(modified.defaultHeightMm, equals(initial.defaultHeightMm));
      expect(modified.showPrice, equals(initial.showPrice));
    });
  });
}
