import 'dart:math';
import '../storage/barcode_settings_store.dart';

enum BarcodeFormatKind {
  code128,
  ean13,
  upcA,
  qrCode;

  String get displayName => switch (this) {
        BarcodeFormatKind.code128 => 'Code 128 (Alphanumeric)',
        BarcodeFormatKind.ean13 => 'EAN-13 (Standard Retail)',
        BarcodeFormatKind.upcA => 'UPC-A (12-Digit Retail)',
        BarcodeFormatKind.qrCode => 'QR Code (2D)',
      };
}

class BarcodeGeneratorService {
  BarcodeGeneratorService._();
  static final BarcodeGeneratorService instance = BarcodeGeneratorService._();

  /// Calculates the modulo-10 check digit for the first 12 digits of an EAN-13 code.
  static int calculateEan13CheckDigit(String twelveDigits) {
    if (twelveDigits.length != 12) return 0;
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      final digit = int.tryParse(twelveDigits[i]) ?? 0;
      sum += (i % 2 == 0) ? digit : (digit * 3);
    }
    final mod = sum % 10;
    return mod == 0 ? 0 : (10 - mod);
  }

  /// Validates whether a 13-digit string has a correct EAN-13 check digit.
  static bool isValidEan13(String code) {
    if (code.length != 13 || !RegExp(r'^\d{13}$').hasMatch(code)) return false;
    final expectedCheck = calculateEan13CheckDigit(code.substring(0, 12));
    return int.parse(code[12]) == expectedCheck;
  }

  /// Calculates the modulo-10 check digit for the first 11 digits of a UPC-A code.
  static int calculateUpcACheckDigit(String elevenDigits) {
    if (elevenDigits.length != 11) return 0;
    int sum = 0;
    for (int i = 0; i < 11; i++) {
      final digit = int.tryParse(elevenDigits[i]) ?? 0;
      sum += (i % 2 == 0) ? (digit * 3) : digit;
    }
    final mod = sum % 10;
    return mod == 0 ? 0 : (10 - mod);
  }

  /// Validates whether a 12-digit string has a correct UPC-A check digit.
  static bool isValidUpcA(String code) {
    if (code.length != 12 || !RegExp(r'^\d{12}$').hasMatch(code)) return false;
    final expectedCheck = calculateUpcACheckDigit(code.substring(0, 11));
    return int.parse(code[11]) == expectedCheck;
  }

  /// Generates an internal Code 128 alphanumeric barcode.
  /// Example output: `JLX-8392014`
  static String generateCode128({String prefix = 'JLX', int? sequence}) {
    final cleanPrefix = prefix.trim().toUpperCase().replaceAll(' ', '-');
    final numSeq = sequence ?? (Random().nextInt(900000) + 100000);
    return cleanPrefix.isNotEmpty ? '$cleanPrefix-$numSeq' : '$numSeq';
  }

  /// Generates a valid 13-digit EAN-13 barcode using the in-store prefix (20-29).
  /// Format: [2 digits prefix (e.g. 20)] + [10 digits sequence] + [1 check digit]
  static String generateEan13({String inStorePrefix = '20', int? sequence}) {
    var prefix = inStorePrefix.trim();
    if (prefix.length != 2 || int.tryParse(prefix) == null) {
      prefix = '20';
    }
    final random = Random();
    final seqStr = sequence != null
        ? sequence.toString().padLeft(10, '0')
        : (random.nextInt(900000000) + 1000000000).toString().substring(0, 10);
    final twelve = '$prefix$seqStr'.substring(0, 12);
    final check = calculateEan13CheckDigit(twelve);
    return '$twelve$check';
  }

  /// Generates a barcode string adhering to the tenant's current BarcodeSettings.
  static String generateFromSettings(BarcodeSettings settings,
      {BarcodeFormatKind? overrideFormat}) {
    final format = overrideFormat ??
        switch (settings.symbology) {
          BarcodeSymbologyPreference.code128 => BarcodeFormatKind.code128,
          BarcodeSymbologyPreference.ean13 => BarcodeFormatKind.ean13,
          BarcodeSymbologyPreference.both => BarcodeFormatKind.code128,
        };

    return switch (format) {
      BarcodeFormatKind.code128 =>
        generateCode128(prefix: settings.customPrefix),
      BarcodeFormatKind.ean13 => generateEan13(),
      BarcodeFormatKind.upcA => () {
          final nine = (Random().nextInt(900000000) + 100000000).toString();
          final eleven = '0$nine$nine'.substring(0, 11);
          final check = calculateUpcACheckDigit(eleven);
          return '$eleven$check';
        }(),
      BarcodeFormatKind.qrCode =>
        generateCode128(prefix: settings.customPrefix),
    };
  }

  /// Determines the detected format kind of an existing barcode string.
  static BarcodeFormatKind detectFormat(String barcode) {
    final clean = barcode.trim();
    if (clean.length == 13 && RegExp(r'^\d{13}$').hasMatch(clean)) {
      return BarcodeFormatKind.ean13;
    }
    if (clean.length == 12 && RegExp(r'^\d{12}$').hasMatch(clean)) {
      return BarcodeFormatKind.upcA;
    }
    return BarcodeFormatKind.code128;
  }
}
