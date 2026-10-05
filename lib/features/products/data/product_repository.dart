import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../domain/catalog.dart';
import '../domain/product.dart';

class ProductDraft {
  const ProductDraft({
    required this.name,
    required this.unitOfMeasureId,
    this.productType = ProductType.goods,
    this.description,
    this.sku,
    this.barcode,
    this.categoryId,
    this.brandId,
    this.taxCategoryId,
    this.costPrice,
  });

  final String name;
  final String unitOfMeasureId;
  final int productType;
  final String? description;
  final String? sku;
  final String? barcode;
  final String? categoryId;
  final String? brandId;
  final String? taxCategoryId;
  final double? costPrice;

  Product toDomain() => Product(
        id: '',
        name: name,
        description: description,
        sku: sku,
        barcode: barcode,
        categoryId: categoryId,
        brandId: brandId,
        unitOfMeasureId: unitOfMeasureId,
        productType: productType,
        status: ProductStatus.active,
        taxCategoryId: taxCategoryId,
        costPrice: costPrice,
      );
}

class PagedProducts {
  const PagedProducts({required this.items, required this.total});

  final List<Product> items;
  final int total;
}

class OpeningStockEntry {
  const OpeningStockEntry({
    required this.warehouseId,
    required this.productId,
    required this.quantity,
    required this.unitOfMeasureId,
    this.reason,
    this.unitCost,
  });

  final String warehouseId;
  final String productId;
  final double quantity;
  final String unitOfMeasureId;
  final String? reason;
  final double? unitCost;

  Map<String, dynamic> toBody() => {
        'warehouseId': warehouseId,
        'productId': productId,
        'quantity': quantity,
        'unitOfMeasureId': unitOfMeasureId,
        'effectiveAt': DateTime.now().toUtc().toIso8601String(),
        if (reason != null && reason!.trim().isNotEmpty)
          'reason': reason!.trim(),
        if (unitCost != null) 'unitCost': unitCost,
      };
}

/// A positive/negative stock movement recorded through the adjustments
/// endpoint. The backend rejects a zero delta and any delta below the current
/// balance. [idempotencyKey] is a client-generated GUID that makes a retry after
/// a dropped response safe — the server dedupes on it (mirrors sales).
class AdjustStockEntry {
  const AdjustStockEntry({
    required this.warehouseId,
    required this.productId,
    required this.quantityDelta,
    this.reason,
    this.unitCost,
    this.reasonType,
    this.idempotencyKey,
  });

  final String warehouseId;
  final String productId;
  final double quantityDelta;
  final String? reason;
  final double? unitCost;
  final String? reasonType;
  final String? idempotencyKey;

  Map<String, dynamic> toBody() => {
        'warehouseId': warehouseId,
        'productId': productId,
        'quantityDelta': quantityDelta,
        'effectiveAt': DateTime.now().toUtc().toIso8601String(),
        if (reason != null && reason!.trim().isNotEmpty)
          'reason': reason!.trim(),
        if (unitCost != null) 'unitCost': unitCost,
        if (reasonType != null && reasonType!.trim().isNotEmpty)
          'reasonType': reasonType!.trim(),
      };
}

/// Speaks to the existing Business OS catalog, pricing and inventory APIs.
/// The backend stays the single source of truth for stock and prices.
class ProductRepository {
  ProductRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<PagedProducts> list({
    int page = 1,
    int pageSize = 50,
    String? search,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    };
    final response = await _apiClient.get<dynamic>(
      '/api/v1/products',
      query: query,
    );
    return _decodePage(response);
  }

  Future<Product> getById(String id) async {
    final response = await _apiClient.get<dynamic>('/api/v1/products/$id');
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return Product.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<Product> create(ProductDraft draft) async {
    final response = await _apiClient.post<dynamic>(
      '/api/v1/products',
      body: draft.toDomain().toCreateBody(),
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return Product.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<Product> update(String id, ProductDraft draft) async {
    final response = await _apiClient.put<dynamic>(
      '/api/v1/products/$id',
      body: draft.toDomain().toUpdateBody(),
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return Product.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<List<UnitOfMeasure>> units() async {
    final data = await _listArray('/api/v1/units');
    return data.map(UnitOfMeasure.fromJson).toList(growable: false);
  }

  Future<UnitOfMeasure> createUnit(String name, String abbreviation) async {
    final response = await _apiClient.post<dynamic>(
      '/api/v1/units',
      body: {'name': name, 'abbreviation': abbreviation},
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return UnitOfMeasure.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<List<TaxCategory>> taxCategories() async {
    final data = await _listArray('/api/v1/tax-categories');
    return data.map(TaxCategory.fromJson).toList(growable: false);
  }

  /// Product categories for the tenant. Empty for a fresh business.
  Future<List<Category>> categories() async {
    final data = await _listArray('/api/v1/categories');
    return data.map(Category.fromJson).toList(growable: false);
  }

  /// Brands for the tenant. Empty for a fresh business.
  Future<List<Brand>> brands() async {
    final data = await _listArray('/api/v1/brands');
    return data.map(Brand.fromJson).toList(growable: false);
  }

  /// Active warehouses for the tenant. The default "Main Store" created during
  /// business setup arrives first in practice; callers should not care.
  Future<List<Warehouse>> warehouses() async {
    final response = await _apiClient.get<dynamic>(
      '/api/v1/warehouses',
      query: const {'page': 1, 'pageSize': 50},
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    final doc = Map<String, dynamic>.from(response.data as Map);
    final items = (doc['items'] as List<dynamic>? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((raw) => Warehouse.fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
    return items;
  }

  /// Stock balances across all locations (first page, generous size) used for
  /// per-product stock badges. Backend remains authoritative.
  Future<List<StockBalance>> balances() async {
    final response = await _apiClient.get<dynamic>(
      '/api/v1/inventory/stock',
      query: const {'page': 1, 'pageSize': 200},
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    final doc = Map<String, dynamic>.from(response.data as Map);
    return (doc['items'] as List<dynamic>? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((raw) => StockBalance.fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }

  Future<StockBalance> recordOpeningStock(OpeningStockEntry entry) async {
    final response = await _apiClient.post<dynamic>(
      '/api/v1/inventory/stock/opening',
      body: entry.toBody(),
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return StockBalance.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<StockBalance> adjustStock(AdjustStockEntry entry) async {
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
    return StockBalance.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  /// The tenant's default price list — created automatically during business
  /// setup. Selling prices live here, not on products.
  Future<PriceList?> defaultPriceList() async {
    final data = await _listArray('/api/v1/price-lists');
    for (final raw in data) {
      final list = PriceList.fromJson(raw);
      if (list.isDefault) {
        return list;
      }
    }
    return null;
  }

  Future<List<ProductPrice>> prices(String priceListId) async {
    final data = await _listArray('/api/v1/price-lists/$priceListId/prices');
    return data.map(ProductPrice.fromJson).toList(growable: false);
  }

  /// Sets (or replaces) a product's Retail selling price on the default price
  /// list. The backend PUT *replaces* every price on the list, so the current
  /// rows are fetched and re-sent merged — never wipe other products' prices.
  Future<void> setSellingPrice({
    required PriceList priceList,
    required String productId,
    required double price,
    int priceType = 0,
  }) async {
    final existing = await prices(priceList.id);
    final others = existing
        .where((row) =>
            !(row.productId == productId && row.priceType == priceType))
        .toList();
    final mine = ProductPrice(
      id: existing
          .where(
              (row) => row.productId == productId && row.priceType == priceType)
          .map((row) => row.id)
          .firstOrNull,
      productId: productId,
      priceType: priceType,
      price: price,
      currency: priceList.currency,
    );
    final response = await _apiClient.put<dynamic>(
      '/api/v1/price-lists/${priceList.id}/prices',
      body: {
        'prices': [...others, mine].map((row) => row.toBody()).toList()
      },
    );
    if (response.statusCode == 409) {
      throw ConflictException('Bei hii ipo tayari.');
    }
    if (response.statusCode != 200) {
      throw ServerException('Imeshindikana kuhifadhi bei.');
    }
  }

  Future<List<Map<String, dynamic>>> _listArray(String path) async {
    final response = await _apiClient.get<dynamic>(path);
    if (response.statusCode != 200 || response.data is! List) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return (response.data as List<dynamic>)
        .whereType<Map<dynamic, dynamic>>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .toList(growable: false);
  }

  PagedProducts _decodePage(Response<dynamic> response) {
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    final doc = Map<String, dynamic>.from(response.data as Map);
    final items = (doc['items'] as List<dynamic>? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((raw) => Product.fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
    return PagedProducts(
      items: items,
      total: (doc['total'] as num?)?.toInt() ?? items.length,
    );
  }
}
