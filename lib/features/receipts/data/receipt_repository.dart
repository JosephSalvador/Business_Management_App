/// Receipt data layer. Handles API calls for receipt operations with local caching.
library;

import '../../../core/network/api_client.dart';
import '../../../core/storage/local_receipt_dao.dart';
import '../../../core/storage/receipt_cache.dart';
import '../domain/receipt_preview.dart';
import '../domain/receipt_layout.dart';

/// Repository for receipt-related API operations with offline SQLite caching.
class ReceiptRepository {
  const ReceiptRepository(
    this._client,
    this._cache, {
    LocalReceiptDao? localReceiptDao,
  }) : _localReceiptDao = localReceiptDao;

  final ApiClient _client;
  final ReceiptCache _cache;
  final LocalReceiptDao? _localReceiptDao;

  /// Fetches the receipt preview data for a sale.
  /// Checks local SQLite store first (100% offline); if miss, checks file cache;
  /// if miss, fetches from API and caches locally in both.
  Future<ReceiptPreview> getPreview(String saleId) async {
    // 1. Check local SQLite store first
    if (_localReceiptDao != null) {
      final local = await _localReceiptDao.getReceipt(saleId);
      if (local != null) return local;
    }

    // 2. Check file cache
    final cached = await _cache.get(saleId);
    if (cached != null) return cached;

    // 3. Fetch from API
    final response = await _client.get<Map<String, dynamic>>(
      '/api/v1/receipts/$saleId/preview',
    );
    final receipt = ReceiptPreview.fromJson(response.data!);

    // 4. Cache in local SQLite and file cache for all future offline prints
    if (_localReceiptDao != null) {
      try {
        await _localReceiptDao.saveReceipt(
          saleId: saleId,
          tenantId: '',
          receiptNumber: receipt.saleNumber,
          receipt: receipt,
        );
      } catch (_) {}
    }
    await _cache.put(saleId, receipt);

    return receipt;
  }

  /// Fetches receipt from API only (bypasses cache).
  Future<ReceiptPreview> refreshPreview(String saleId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/v1/receipts/$saleId/preview',
    );
    final receipt = ReceiptPreview.fromJson(response.data!);
    if (_localReceiptDao != null) {
      try {
        await _localReceiptDao.saveReceipt(
          saleId: saleId,
          tenantId: '',
          receiptNumber: receipt.saleNumber,
          receipt: receipt,
        );
      } catch (_) {}
    }
    await _cache.put(saleId, receipt);
    return receipt;
  }

  /// Records a print event for a sale.
  Future<PrintEventRecorded> recordPrint({
    required String saleId,
    required PrintType type,
    String? deviceId,
    String? notes,
  }) async {
    if (_localReceiptDao != null) {
      try {
        await _localReceiptDao.incrementPrintCount(saleId);
      } catch (_) {}
    }

    final response = await _client.post<Map<String, dynamic>>(
      '/api/v1/receipts/$saleId/print',
      body: {
        'type': type.index,
        if (deviceId != null) 'deviceId': deviceId,
        if (notes != null) 'notes': notes,
      },
    );
    return PrintEventRecorded.fromJson(response.data!);
  }

  /// Seeds the default thermal layout for the current tenant.
  Future<String> seedDefaultLayout() async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/v1/receipts/layouts/seed',
    );
    return response.data!['value'] as String;
  }

  /// Lists all receipt layouts for the current tenant.
  Future<List<ReceiptLayout>> listLayouts() async {
    final response = await _client.get<List<dynamic>>(
      '/api/v1/receipts/layouts',
    );
    return response.data!
        .map((e) => ReceiptLayout.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// Print type enum matching the backend.
enum PrintType {
  original,
  customerCopy,
  reprint,
}
