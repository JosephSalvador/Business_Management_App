/// Receipt data layer. Handles API calls for receipt operations with local caching.
library;

import '../../../core/network/api_client.dart';
import '../../../core/storage/receipt_cache.dart';
import '../domain/receipt_preview.dart';
import '../domain/receipt_layout.dart';

/// Repository for receipt-related API operations.
class ReceiptRepository {
  const ReceiptRepository(this._client, this._cache);

  final ApiClient _client;
  final ReceiptCache _cache;

  /// Fetches the receipt preview data for a sale.
  /// Checks local cache first; if miss, fetches from API and caches.
  Future<ReceiptPreview> getPreview(String saleId) async {
    // Check cache first
    final cached = await _cache.get(saleId);
    if (cached != null) return cached;

    // Fetch from API
    final response = await _client.get<Map<String, dynamic>>(
      '/api/v1/receipts/$saleId/preview',
    );
    final receipt = ReceiptPreview.fromJson(response.data!);

    // Cache for future prints
    await _cache.put(saleId, receipt);

    return receipt;
  }

  /// Fetches receipt from API only (bypasses cache).
  Future<ReceiptPreview> refreshPreview(String saleId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/v1/receipts/$saleId/preview',
    );
    final receipt = ReceiptPreview.fromJson(response.data!);
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
