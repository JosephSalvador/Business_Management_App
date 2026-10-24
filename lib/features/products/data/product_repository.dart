import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/storage/cached_catalog_dao.dart';
import '../../../core/storage/local_database.dart' show CachedProductsCompanion;
import '../../../core/storage/offline_cache_dao.dart';
import '../../../core/storage/sync_queue_dao.dart';
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
  ProductRepository({
    required ApiClient apiClient,
    OfflineCacheDao? cache,
    SyncQueueDao? queue,
    CachedCatalogDao? catalogDao,
    Future<String?> Function()? tenantIdOf,
    Future<String?> Function()? branchIdOf,
    Future<String> Function()? deviceIdOf,
    Uuid uuid = const Uuid(),
  })  : _apiClient = apiClient,
        _cache = cache,
        _queue = queue,
        _catalogDao = catalogDao,
        _tenantIdOf = tenantIdOf,
        _branchIdOf = branchIdOf,
        _deviceIdOf = deviceIdOf,
        _uuid = uuid;

  final ApiClient _apiClient;
  final OfflineCacheDao? _cache;
  final SyncQueueDao? _queue;
  final CachedCatalogDao? _catalogDao;
  final Future<String?> Function()? _tenantIdOf;
  final Future<String?> Function()? _branchIdOf;
  final Future<String> Function()? _deviceIdOf;
  final Uuid _uuid;

  static const _cacheKey = 'products_list';

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
    try {
      final response = await _apiClient.get<dynamic>(
        '/api/v1/products',
        query: query,
      );
      final paged = _decodePage(response);
      if (_cache != null && search == null && page == 1) {
        await _cache!.save(_cacheKey, {
          'items': paged.items.map((p) => p.toJson()).toList(),
          'total': paged.total,
        });
        for (final p in paged.items) {
          await _cache!.save('product_${p.id}', p.toJson());
        }
      }
      return paged;
    } on AppException {
      if (_cache != null) {
        final cached = await _cache!.load(_cacheKey);
        if (cached != null) {
          var items = (cached['items'] as List<dynamic>? ?? const [])
              .whereType<Map<dynamic, dynamic>>()
              .map((raw) => Product.fromJson(Map<String, dynamic>.from(raw)))
              .toList();

          if (search != null && search.trim().isNotEmpty) {
            final term = search.trim().toLowerCase();
            items = items.where((p) {
              final name = p.name.toLowerCase();
              final sku = (p.sku ?? '').toLowerCase();
              final barcode = (p.barcode ?? '').toLowerCase();
              return name.contains(term) ||
                  sku.contains(term) ||
                  barcode.contains(term);
            }).toList();
          }

          return PagedProducts(items: items, total: items.length);
        }
      }
      rethrow;
    }
  }

  Future<Product> getById(String id) async {
    try {
      final response = await _apiClient.get<dynamic>('/api/v1/products/$id');
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      final product =
          Product.fromJson(Map<String, dynamic>.from(response.data as Map));
      if (_cache != null) {
        await _cache!.save('product_$id', product.toJson());
      }
      return product;
    } on AppException {
      if (_cache != null) {
        final cached = await _cache!.load('product_$id');
        if (cached != null) {
          return Product.fromJson(cached);
        }
        final listCached = await _cache!.load(_cacheKey);
        if (listCached != null) {
          final items = (listCached['items'] as List<dynamic>? ?? const [])
              .whereType<Map<dynamic, dynamic>>()
              .map((raw) => Product.fromJson(Map<String, dynamic>.from(raw)));
          final found = items.where((p) => p.id == id);
          if (found.isNotEmpty) return found.first;
        }
      }
      rethrow;
    }
  }

  Future<Product> create(
    ProductDraft draft, {
    bool remoteOnly = false,
  }) async {
    try {
      final response = await _apiClient.post<dynamic>(
        '/api/v1/products',
        body: draft.toDomain().toCreateBody(),
      );
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      final created =
          Product.fromJson(Map<String, dynamic>.from(response.data as Map));
      if (_cache != null) {
        await _cache!.save('product_${created.id}', created.toJson());
        await _appendProductToCache(created);
      }
      return created;
    } on AppException {
      if (remoteOnly) rethrow;

      final localId = _uuid.v4();
      final localProduct = Product(
        id: localId,
        name: draft.name,
        description: draft.description,
        sku: draft.sku,
        barcode: draft.barcode,
        categoryId: draft.categoryId,
        brandId: draft.brandId,
        unitOfMeasureId: draft.unitOfMeasureId,
        productType: draft.productType,
        status: ProductStatus.active,
        taxCategoryId: draft.taxCategoryId,
        costPrice: draft.costPrice,
      );

      if (_cache != null) {
        await _cache!.save('product_$localId', localProduct.toJson());
        await _appendProductToCache(localProduct);
      }

      final tenantId = _tenantIdOf != null
          ? (await _tenantIdOf!()) ?? 'unknown'
          : 'unknown';
      final branchId =
          _branchIdOf != null ? (await _branchIdOf!()) ?? tenantId : tenantId;
      final deviceId = _deviceIdOf != null ? await _deviceIdOf!() : '';

      if (_catalogDao != null) {
        await _catalogDao!.upsertProduct(CachedProductsCompanion(
          tenantId: Value(tenantId),
          productId: Value(localId),
          name: Value(localProduct.name),
          sku: Value(localProduct.sku ?? ''),
          barcode: Value(localProduct.barcode ?? ''),
          unitOfMeasure: const Value('Pcs'),
          status: const Value(LocalProductCodes.statusActive),
          sellable: const Value(true),
          productType: const Value(LocalProductCodes.typeGoods),
          fetchedAt: Value(DateTime.now().toUtc()),
        ));
      }

      if (_queue != null) {
        await _queue!.enqueue(
          operationId: localId,
          tenantId: tenantId,
          branchId: branchId,
          deviceId: deviceId,
          operationType: 'product.create',
          aggregateType: 'product',
          aggregateId: localId,
          payload: jsonEncode(draft.toDomain().toCreateBody()),
        );
      }

      return localProduct;
    }
  }

  Future<void> _appendProductToCache(Product product) async {
    if (_cache == null) return;
    try {
      final listCached = await _cache!.load(_cacheKey);
      final items = (listCached?['items'] as List<dynamic>? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((raw) => Map<String, dynamic>.from(raw))
          .toList();
      items.removeWhere((p) => p['id'] == product.id);
      items.insert(0, product.toJson());
      await _cache!.save(_cacheKey, {
        'items': items,
        'total': items.length,
      });
    } catch (_) {}
  }

  Future<Product> update(
    String id,
    ProductDraft draft, {
    bool remoteOnly = false,
  }) async {
    try {
      final response = await _apiClient.put<dynamic>(
        '/api/v1/products/$id',
        body: draft.toDomain().toUpdateBody(),
      );
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      final updated =
          Product.fromJson(Map<String, dynamic>.from(response.data as Map));
      if (_cache != null) {
        await _cache!.save('product_$id', updated.toJson());
        await _appendProductToCache(updated);
      }
      return updated;
    } on AppException {
      if (remoteOnly) rethrow;

      final updated = Product(
        id: id,
        name: draft.name,
        description: draft.description,
        sku: draft.sku,
        barcode: draft.barcode,
        categoryId: draft.categoryId,
        brandId: draft.brandId,
        unitOfMeasureId: draft.unitOfMeasureId,
        productType: draft.productType,
        status: ProductStatus.active,
        taxCategoryId: draft.taxCategoryId,
        costPrice: draft.costPrice,
      );

      if (_cache != null) {
        await _cache!.save('product_$id', updated.toJson());
        await _appendProductToCache(updated);
      }

      final tenantId = _tenantIdOf != null
          ? (await _tenantIdOf!()) ?? 'unknown'
          : 'unknown';
      final branchId =
          _branchIdOf != null ? (await _branchIdOf!()) ?? tenantId : tenantId;
      final deviceId = _deviceIdOf != null ? await _deviceIdOf!() : '';

      if (_catalogDao != null) {
        await _catalogDao!.upsertProduct(CachedProductsCompanion(
          tenantId: Value(tenantId),
          productId: Value(id),
          name: Value(updated.name),
          sku: Value(updated.sku ?? ''),
          barcode: Value(updated.barcode ?? ''),
          unitOfMeasure: const Value('Pcs'),
          status: const Value(LocalProductCodes.statusActive),
          sellable: const Value(true),
          productType: const Value(LocalProductCodes.typeGoods),
          fetchedAt: Value(DateTime.now().toUtc()),
        ));
      }

      if (_queue != null) {
        await _queue!.enqueue(
          operationId: _uuid.v4(),
          tenantId: tenantId,
          branchId: branchId,
          deviceId: deviceId,
          operationType: 'product.update',
          aggregateType: 'product',
          aggregateId: id,
          payload: jsonEncode({'id': id, ...draft.toDomain().toUpdateBody()}),
        );
      }

      return updated;
    }
  }

  Future<List<UnitOfMeasure>> units() async {
    try {
      final data = await _listArray('/api/v1/units');
      final list = data.map(UnitOfMeasure.fromJson).toList(growable: false);
      if (_cache != null) {
        await _cache!.save('units_list', {'items': data});
      }
      return list;
    } on AppException {
      if (_cache != null) {
        final cached = await _cache!.load('units_list');
        if (cached != null) {
          final items = (cached['items'] as List<dynamic>? ?? const [])
              .whereType<Map<dynamic, dynamic>>()
              .map((r) => UnitOfMeasure.fromJson(Map<String, dynamic>.from(r)))
              .toList(growable: false);
          if (items.isNotEmpty) return items;
        }
      }
      return const [
        UnitOfMeasure(id: 'default-uom', name: 'Item', abbreviation: 'Pcs')
      ];
    }
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
    try {
      final data = await _listArray('/api/v1/tax-categories');
      final list = data.map(TaxCategory.fromJson).toList(growable: false);
      if (_cache != null) {
        await _cache!.save('tax_categories_list', {'items': data});
      }
      return list;
    } on AppException {
      if (_cache != null) {
        final cached = await _cache!.load('tax_categories_list');
        if (cached != null) {
          final items = (cached['items'] as List<dynamic>? ?? const [])
              .whereType<Map<dynamic, dynamic>>()
              .map((r) => TaxCategory.fromJson(Map<String, dynamic>.from(r)))
              .toList(growable: false);
          return items;
        }
      }
      return const [];
    }
  }

  /// Product categories for the tenant. Empty for a fresh business.
  Future<List<Category>> categories() async {
    try {
      final data = await _listArray('/api/v1/categories');
      final list = data.map(Category.fromJson).toList(growable: false);
      if (_cache != null) {
        await _cache!.save('categories_list', {'items': data});
      }
      return list;
    } on AppException {
      if (_cache != null) {
        final cached = await _cache!.load('categories_list');
        if (cached != null) {
          final items = (cached['items'] as List<dynamic>? ?? const [])
              .whereType<Map<dynamic, dynamic>>()
              .map((r) => Category.fromJson(Map<String, dynamic>.from(r)))
              .toList(growable: false);
          return items;
        }
      }
      return const [];
    }
  }

  /// Brands for the tenant. Empty for a fresh business.
  Future<List<Brand>> brands() async {
    try {
      final data = await _listArray('/api/v1/brands');
      final list = data.map(Brand.fromJson).toList(growable: false);
      if (_cache != null) {
        await _cache!.save('brands_list', {'items': data});
      }
      return list;
    } on AppException {
      if (_cache != null) {
        final cached = await _cache!.load('brands_list');
        if (cached != null) {
          final items = (cached['items'] as List<dynamic>? ?? const [])
              .whereType<Map<dynamic, dynamic>>()
              .map((r) => Brand.fromJson(Map<String, dynamic>.from(r)))
              .toList(growable: false);
          return items;
        }
      }
      return const [];
    }
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
    try {
      final data = await _listArray('/api/v1/price-lists');
      if (_cache != null) {
        await _cache!.save('price_lists', {'items': data});
      }
      for (final raw in data) {
        final list = PriceList.fromJson(raw);
        if (list.isDefault) {
          return list;
        }
      }
      return null;
    } on AppException {
      if (_cache != null) {
        final cached = await _cache!.load('price_lists');
        if (cached != null) {
          final items = (cached['items'] as List<dynamic>? ?? const [])
              .whereType<Map<dynamic, dynamic>>()
              .map((raw) => PriceList.fromJson(Map<String, dynamic>.from(raw)));
          for (final list in items) {
            if (list.isDefault) return list;
          }
          if (items.isNotEmpty) return items.first;
        }
      }
      return const PriceList(
        id: 'default-price-list',
        name: 'Retail',
        currency: 'TZS',
        isDefault: true,
      );
    }
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
    bool remoteOnly = false,
  }) async {
    try {
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
    } on AppException {
      if (remoteOnly) rethrow;

      final tenantId = _tenantIdOf != null
          ? (await _tenantIdOf!()) ?? 'unknown'
          : 'unknown';
      final branchId =
          _branchIdOf != null ? (await _branchIdOf!()) ?? tenantId : tenantId;
      final deviceId = _deviceIdOf != null ? await _deviceIdOf!() : '';

      if (_queue != null) {
        await _queue!.enqueue(
          operationId: _uuid.v4(),
          tenantId: tenantId,
          branchId: branchId,
          deviceId: deviceId,
          operationType: 'product.price_set',
          aggregateType: 'product',
          aggregateId: productId,
          payload: jsonEncode({
            'priceListId': priceList.id,
            'productId': productId,
            'price': price,
            'priceType': priceType,
          }),
        );
      }
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
