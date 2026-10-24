import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../../products/data/product_repository.dart';
import '../domain/stock.dart';

import 'offline_inventory_service.dart';

/// A paged envelope shared by the inventory endpoints: `{items, total}`.
class PagedStock<T> {
  const PagedStock({required this.items, required this.total});

  final List<T> items;
  final int total;
}

/// Speaks to the Business OS inventory API. The backend remains the single
/// source of truth for balances, movements and transfers; the local cache
/// serves as an offline projection only.
class InventoryRepository {
  InventoryRepository({
    required ApiClient apiClient,
    OfflineInventoryService? offlineService,
  })  : _apiClient = apiClient,
        _offlineService = offlineService;

  final ApiClient _apiClient;
  final OfflineInventoryService? _offlineService;

  /// Enriched stock balances across warehouses and locations. Pass
  /// [warehouseId] to scope to one warehouse, [productId] to zoom into a
  /// product's locations, [search] to filter by product name/sku/barcode.
  Future<PagedStock<StockBalanceItem>> stockBalances({
    int page = 1,
    int pageSize = 200,
    String? warehouseId,
    String? productId,
    String? search,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
      if (warehouseId != null && warehouseId.isNotEmpty)
        'warehouseId': warehouseId,
      if (productId != null && productId.isNotEmpty) 'productId': productId,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    };
    final response = await _apiClient.get<dynamic>(
      '/api/v1/inventory/stock',
      query: query,
    );
    return _decodePage(response, StockBalanceItem.fromJson);
  }

  /// Stock movement history. [warehouseId] scopes to one warehouse,
  /// [productId] to one product.
  Future<PagedStock<StockMovementItem>> stockMovements({
    int page = 1,
    int pageSize = 200,
    String? warehouseId,
    String? productId,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
      if (warehouseId != null && warehouseId.isNotEmpty)
        'warehouseId': warehouseId,
      if (productId != null && productId.isNotEmpty) 'productId': productId,
    };
    final response = await _apiClient.get<dynamic>(
      '/api/v1/inventory/movements',
      query: query,
    );
    return _decodePage(response, StockMovementItem.fromJson);
  }

  /// Records opening stock; the returned enriched balance is the server truth.
  Future<StockBalanceItem> recordOpeningStock(OpeningStockEntry entry) async {
    final response = await _apiClient.post<dynamic>(
      '/api/v1/inventory/stock/opening',
      body: entry.toBody(),
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return StockBalanceItem.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  /// Records an adjustment; the returned enriched balance is the server truth.
  Future<StockBalanceItem> adjustStock(
    AdjustStockEntry entry, {
    bool remoteOnly = false,
  }) async {
    try {
      final response = await _apiClient.post<dynamic>(
        '/api/v1/inventory/stock/adjustments',
        body: entry.toBody(),
        headers: entry.idempotencyKey != null
            ? {'Idempotency-Key': entry.idempotencyKey!}
            : const {},
      );
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      return StockBalanceItem.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on AppException {
      if (remoteOnly) rethrow;
      if (_offlineService != null) {
        await _offlineService!.recordOfflineInboundReceiving(
          productId: entry.productId,
          productName: entry.productId,
          quantity: entry.quantityDelta,
          warehouseId: entry.warehouseId,
          notes: entry.reason,
        );
        return StockBalanceItem(
          productId: entry.productId,
          productName: '',
          sku: '',
          barcode: null,
          warehouseId: entry.warehouseId,
          warehouseName: '',
          stockLocationId: '',
          stockLocationName: '',
          unitOfMeasureName: '',
          quantity: entry.quantityDelta,
        );
      }
      rethrow;
    }
  }

  static PagedStock<T> _decodePage<T>(
    Response<dynamic> response,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    final doc = Map<String, dynamic>.from(response.data as Map);
    final items = (doc['items'] as List<dynamic>? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((raw) => fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
    final total = (doc['total'] as num?)?.toInt() ?? items.length;
    return PagedStock(items: items, total: total);
  }
}
