import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/receipts/domain/receipt_preview.dart';

/// Caches receipt data locally so printing doesn't require backend calls.
class ReceiptCache {
  ReceiptCache({Directory? cacheDir}) : _cacheDir = cacheDir;

  final Directory? _cacheDir;

  Future<Directory> get _dir async {
    if (_cacheDir != null) return _cacheDir;
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/receipt_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  Future<File> _fileFor(String saleId) async {
    final dir = await _dir;
    return File('${dir.path}/$saleId.json');
  }

  /// Returns cached receipt for [saleId], or null if not cached.
  Future<ReceiptPreview?> get(String saleId) async {
    try {
      final file = await _fileFor(saleId);
      if (!await file.exists()) return null;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return ReceiptPreview.fromJson(json);
    } on Exception {
      return null;
    }
  }

  /// Caches receipt data for [saleId].
  Future<void> put(String saleId, ReceiptPreview receipt) async {
    try {
      final file = await _fileFor(saleId);
      await file.writeAsString(jsonEncode(receipt.toJson()));
    } on Exception {
      // Silently fail — cache is best-effort
    }
  }

  /// Removes cached receipt for [saleId].
  Future<void> remove(String saleId) async {
    try {
      final file = await _fileFor(saleId);
      if (await file.exists()) {
        await file.delete();
      }
    } on Exception {
      // Silently fail
    }
  }

  /// Clears all cached receipts.
  Future<void> clear() async {
    try {
      final dir = await _dir;
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } on Exception {
      // Silently fail
    }
  }
}

final receiptCacheProvider = Provider<ReceiptCache>((_) => ReceiptCache());
