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
class ReceiptPaperWidthNotifier extends Notifier<ReceiptPaperWidth> {
  @override
  ReceiptPaperWidth build() => ReceiptPaperWidth.mm80;

  @override
  set state(ReceiptPaperWidth value) {
    super.state = value;
    ref
        .read(printerStoreProvider)
        .savePaperWidth(value == ReceiptPaperWidth.mm58 ? '58' : '80');
  }

  void setWidth(ReceiptPaperWidth width) => state = width;

  void restore(String? saved) {
    if (saved == '58' || saved == 'mm58') {
      super.state = ReceiptPaperWidth.mm58;
    } else if (saved == '80' || saved == 'mm80') {
      super.state = ReceiptPaperWidth.mm80;
    }
  }

  Future<void> loadFromStore() async {
    final saved = await ref.read(printerStoreProvider).getPaperWidth();
    restore(saved);
  }
}

final receiptPaperWidthProvider =
    NotifierProvider<ReceiptPaperWidthNotifier, ReceiptPaperWidth>(
  ReceiptPaperWidthNotifier.new,
);

/// Provider for the thermal renderer, configured for active language and paper width.
final thermalRendererProvider = Provider<Thermal80mmRenderer>((ref) {
  final locale = ref.watch(localeControllerProvider);
  final paperWidth = ref.watch(receiptPaperWidthProvider);
  return Thermal80mmRenderer.forWidth(
    paperWidth,
    language: receiptLanguageForCode(locale.languageCode),
  );
});
