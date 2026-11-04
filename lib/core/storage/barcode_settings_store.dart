import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum BarcodeSymbologyPreference {
  code128,
  ean13,
  both;

  String get displayName => switch (this) {
        BarcodeSymbologyPreference.code128 => 'Code 128 (Alphanumeric)',
        BarcodeSymbologyPreference.ean13 => 'EAN-13 (Standard Retail)',
        BarcodeSymbologyPreference.both => 'Both / Chagua Kila Bidhaa',
      };
}

class BarcodeSettings {
  const BarcodeSettings({
    this.symbology = BarcodeSymbologyPreference.both,
    this.customPrefix = 'JLX',
    this.showPrice = true,
    this.showStoreName = true,
    this.showSku = true,
    this.includeQr = false,
    this.defaultWidthMm = 50.0,
    this.defaultHeightMm = 30.0,
    this.continuousRoll = false,
  });

  final BarcodeSymbologyPreference symbology;
  final String customPrefix;
  final bool showPrice;
  final bool showStoreName;
  final bool showSku;
  final bool includeQr;
  final double defaultWidthMm;
  final double defaultHeightMm;
  final bool continuousRoll;

  BarcodeSettings copyWith({
    BarcodeSymbologyPreference? symbology,
    String? customPrefix,
    bool? showPrice,
    bool? showStoreName,
    bool? showSku,
    bool? includeQr,
    double? defaultWidthMm,
    double? defaultHeightMm,
    bool? continuousRoll,
  }) =>
      BarcodeSettings(
        symbology: symbology ?? this.symbology,
        customPrefix: customPrefix ?? this.customPrefix,
        showPrice: showPrice ?? this.showPrice,
        showStoreName: showStoreName ?? this.showStoreName,
        showSku: showSku ?? this.showSku,
        includeQr: includeQr ?? this.includeQr,
        defaultWidthMm: defaultWidthMm ?? this.defaultWidthMm,
        defaultHeightMm: defaultHeightMm ?? this.defaultHeightMm,
        continuousRoll: continuousRoll ?? this.continuousRoll,
      );

  Map<String, dynamic> toJson() => {
        'symbology': symbology.name,
        'customPrefix': customPrefix,
        'showPrice': showPrice,
        'showStoreName': showStoreName,
        'showSku': showSku,
        'includeQr': includeQr,
        'defaultWidthMm': defaultWidthMm,
        'defaultHeightMm': defaultHeightMm,
        'continuousRoll': continuousRoll,
      };

  factory BarcodeSettings.fromJson(Map<String, dynamic> json) => BarcodeSettings(
        symbology: BarcodeSymbologyPreference.values.firstWhere(
          (e) => e.name == json['symbology'],
          orElse: () => BarcodeSymbologyPreference.both,
        ),
        customPrefix: json['customPrefix'] as String? ?? 'JLX',
        showPrice: json['showPrice'] as bool? ?? true,
        showStoreName: json['showStoreName'] as bool? ?? true,
        showSku: json['showSku'] as bool? ?? true,
        includeQr: json['includeQr'] as bool? ?? false,
        defaultWidthMm: (json['defaultWidthMm'] as num?)?.toDouble() ?? 50.0,
        defaultHeightMm: (json['defaultHeightMm'] as num?)?.toDouble() ?? 30.0,
        continuousRoll: json['continuousRoll'] as bool? ?? false,
      );
}

class BarcodeSettingsStore {
  BarcodeSettingsStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  static const _keySettings = 'jolinx.barcode_settings';
  final FlutterSecureStorage _storage;

  Future<BarcodeSettings> load() async {
    try {
      final raw = await _storage.read(key: _keySettings);
      if (raw != null && raw.isNotEmpty) {
        return BarcodeSettings.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {
      // Fallback on corrupt read
    }
    return const BarcodeSettings();
  }

  Future<void> save(BarcodeSettings settings) async {
    await _storage.write(
      key: _keySettings,
      value: jsonEncode(settings.toJson()),
    );
  }
}

final barcodeSettingsStoreProvider = Provider<BarcodeSettingsStore>((ref) {
  return BarcodeSettingsStore();
});

class BarcodeSettingsController extends Notifier<BarcodeSettings> {
  @override
  BarcodeSettings build() {
    _restore();
    return const BarcodeSettings();
  }

  Future<void> _restore() async {
    final settings = await ref.read(barcodeSettingsStoreProvider).load();
    state = settings;
  }

  Future<void> update(BarcodeSettings settings) async {
    state = settings;
    await ref.read(barcodeSettingsStoreProvider).save(settings);
  }
}

final barcodeSettingsProvider =
    NotifierProvider<BarcodeSettingsController, BarcodeSettings>(
  BarcodeSettingsController.new,
);
