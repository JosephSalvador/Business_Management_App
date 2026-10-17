/// Riverpod providers for the receipts feature.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/storage/locale_store.dart';
import '../data/receipt_repository.dart';
import '../domain/receipt_format.dart';
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

/// Configured thermal printer paper width (58mm portable vs 80mm counter).
final receiptPaperWidthProvider =
    StateProvider<ReceiptPaperWidth>((ref) => ReceiptPaperWidth.mm80);

/// Provider for the thermal renderer, configured for active language and paper width.
final thermalRendererProvider = Provider<Thermal80mmRenderer>((ref) {
  final locale = ref.watch(localeControllerProvider);
  final paperWidth = ref.watch(receiptPaperWidthProvider);
  return Thermal80mmRenderer.forWidth(
    paperWidth,
    language: receiptLanguageForCode(locale.languageCode),
  );
});
