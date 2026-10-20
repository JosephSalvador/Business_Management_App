import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/receipts/domain/receipt_customization.dart';

/// Storage service for tenant receipt header & footer customization.
class ReceiptCustomizationStore {
  ReceiptCustomizationStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  static const _keyPrefix = 'jolinx.receipt_customization';

  final FlutterSecureStorage _storage;

  Future<ReceiptCustomization?> read({String? tenantId}) async {
    try {
      final key = tenantId != null && tenantId.isNotEmpty
          ? '$_keyPrefix.$tenantId'
          : _keyPrefix;
      final jsonStr = await _storage.read(key: key);
      if (jsonStr == null || jsonStr.trim().isEmpty) return null;
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return ReceiptCustomization.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(ReceiptCustomization customization, {String? tenantId}) async {
    try {
      final key = tenantId != null && tenantId.isNotEmpty
          ? '$_keyPrefix.$tenantId'
          : _keyPrefix;
      final jsonStr = jsonEncode(customization.toJson());
      await _storage.write(key: key, value: jsonStr);
    } catch (_) {}
  }
}

final receiptCustomizationStoreProvider =
    Provider<ReceiptCustomizationStore>((_) => ReceiptCustomizationStore());

/// Notifier managing active receipt customization.
class ReceiptCustomizationNotifier extends Notifier<ReceiptCustomization> {
  @override
  ReceiptCustomization build() {
    // Start with default, then restore asynchronously
    _restore();
    return ReceiptCustomization.defaultConfiguration;
  }

  Future<void> _restore() async {
    try {
      final store = ref.read(receiptCustomizationStoreProvider);
      final saved = await store.read();
      if (saved != null) {
        state = saved;
      }
    } catch (_) {}
  }

  Future<void> update(ReceiptCustomization customization, {String? tenantId}) async {
    state = customization;
    await ref
        .read(receiptCustomizationStoreProvider)
        .write(customization, tenantId: tenantId);
  }

  void restoreFromSaved(ReceiptCustomization saved) {
    state = saved;
  }
}

final receiptCustomizationProvider =
    NotifierProvider<ReceiptCustomizationNotifier, ReceiptCustomization>(
  ReceiptCustomizationNotifier.new,
);
