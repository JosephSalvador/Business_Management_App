/// Riverpod providers for the receipts feature.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/storage/locale_store.dart';
import '../data/receipt_repository.dart';
import '../domain/receipt_preview.dart';
import '../domain/receipt_renderer.dart';

/// Provider for the receipt repository.
final receiptRepositoryProvider = Provider<ReceiptRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  final cache = ref.watch(receiptCacheProvider);
  return ReceiptRepository(client, cache);
});

/// Provider for the receipt preview data.
final receiptPreviewProvider =
    FutureProvider.family<ReceiptPreview, String>((ref, saleId) async {
  final repo = ref.watch(receiptRepositoryProvider);
  return repo.getPreview(saleId);
});

/// Provider for the thermal 80mm renderer, in the app's current language.
final thermalRendererProvider = Provider<Thermal80mmRenderer>((ref) {
  final locale = ref.watch(localeControllerProvider);
  return Thermal80mmRenderer(
    language: receiptLanguageForCode(locale.languageCode),
  );
});
