import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/config/app_config.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/core/network/api_client.dart';
import 'package:jolinx_app/features/products/data/product_repository.dart';
import 'package:jolinx_app/features/products/domain/catalog.dart';
import 'package:jolinx_app/features/products/domain/product.dart';
import '../../support/fakes.dart';

ApiClient clientWith(ScriptedAdapter adapter) => ApiClient(
      config: AppConfig.forTest(
        apiBaseUrl: Uri.parse('https://api.test.local'),
        environment: AppEnvironment.dev,
      ),
      tokenStore: InMemoryTokenStore(),
      refresher: (_) async => TokenPair(
        accessToken: 'a',
        refreshToken: 'r',
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 15)),
      ),
      dio: Dio(BaseOptions(baseUrl: 'https://api.test.local'))
        ..httpClientAdapter = adapter,
    );

Map<String, dynamic> productJson(String id, {String name = 'Mchele'}) => {
      'id': id,
      'tenantId': 't1',
      'name': name,
      'description': null,
      'sku': 'SKU-$id',
      'barcode': null,
      'categoryId': null,
      'brandId': null,
      'unitOfMeasureId': 'u1',
      'productType': 0,
      'status': 1,
      'variants': [],
      'taxCategoryId': null,
      'createdAt': '2026-08-23T10:00:00Z',
      'updatedAt': null,
    };

void main() {
  group('ProductRepository HTTP contract', () {
    test('list parses the paged envelope', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode({
              'items': [productJson('p1'), productJson('p2', name: 'Sukari')],
              'page': 1,
              'pageSize': 50,
              'total': 2,
            })),
      ]);
      final repository = ProductRepository(apiClient: clientWith(adapter));

      final page = await repository.list(search: 'mchele');

      expect(
        adapter.requests.single.path,
        'https://api.test.local/api/v1/products?page=1&pageSize=50&search=mchele',
      );
      expect(page.total, 2);
      expect(page.items[1].name, 'Sukari');
    });

    test('create sends Active status and omits blank identifiers', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, jsonEncode(productJson('p9'))),
      ]);
      final repository = ProductRepository(apiClient: clientWith(adapter));

      await repository.create(const ProductDraft(
        name: ' Mchele ',
        unitOfMeasureId: 'u1',
        sku: '  ',
        taxCategoryId: 'tax1',
      ));

      final body =
          jsonDecode(adapter.requests.single.body!) as Map<String, dynamic>;
      expect(body['name'], 'Mchele');
      expect(body['status'], ProductStatus.active);
      expect(body.containsKey('sku'), isFalse);
      expect(body['taxCategoryId'], 'tax1');
      expect(body['productType'], ProductType.goods);
    });

    test('create sends category, brand and description when provided',
        () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, jsonEncode(productJson('p9'))),
      ]);
      final repository = ProductRepository(apiClient: clientWith(adapter));

      await repository.create(const ProductDraft(
        name: 'Mchele',
        unitOfMeasureId: 'u1',
        description: 'Mchele mweupe',
        categoryId: 'c1',
        brandId: 'b1',
      ));

      final body =
          jsonDecode(adapter.requests.single.body!) as Map<String, dynamic>;
      expect(body['categoryId'], 'c1');
      expect(body['brandId'], 'b1');
      expect(body['description'], 'Mchele mweupe');
    });

    test('update does not send status or productType (ownership is read-only)',
        () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, jsonEncode(productJson('p1'))),
      ]);
      final repository = ProductRepository(apiClient: clientWith(adapter));

      await repository.update(
        'p1',
        const ProductDraft(
          name: 'Mchele',
          unitOfMeasureId: 'u1',
          productType: ProductType.service,
        ),
      );

      final body =
          jsonDecode(adapter.requests.single.body!) as Map<String, dynamic>;
      expect(body.containsKey('status'), isFalse);
      expect(body.containsKey('productType'), isFalse);
    });

    test('categories returns the parsed tenant categories', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode([
              {'id': 'c1', 'name': 'Pamba', 'parentId': null},
              {'id': 'c2', 'name': 'Vinywaji', 'parentId': 'c1'},
            ])),
      ]);
      final repository = ProductRepository(apiClient: clientWith(adapter));

      final categories = await repository.categories();

      expect(
        adapter.requests.single.path,
        'https://api.test.local/api/v1/categories',
      );
      expect(categories, hasLength(2));
      expect(categories[1].parentId, 'c1');
    });

    test('brands returns the parsed tenant brands', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode([
              {'id': 'b1', 'name': 'Jamaa'},
            ])),
      ]);
      final repository = ProductRepository(apiClient: clientWith(adapter));

      final brands = await repository.brands();

      expect(
        adapter.requests.single.path,
        'https://api.test.local/api/v1/brands',
      );
      expect(brands.single.name, 'Jamaa');
    });

    test('setSellingPrice merges — never wipes other products prices',
        () async {
      final adapter = ScriptedAdapter([
        // GET existing prices: two rows for other products plus our own.
        ScriptedResponse(
            200,
            jsonEncode([
              {
                'id': 'row1',
                'priceListId': 'pl1',
                'productId': 'other-a',
                'variantId': null,
                'branchId': null,
                'priceType': 0,
                'price': 1000,
                'currency': 'TZS',
                'minQuantity': 1,
                'effectiveFrom': null,
                'effectiveTo': null,
                'isActive': true,
              },
              {
                'id': 'row2',
                'priceListId': 'pl1',
                'productId': 'other-b',
                'variantId': null,
                'branchId': null,
                'priceType': 0,
                'price': 2500.5,
                'currency': 'TZS',
                'minQuantity': 1,
                'effectiveFrom': null,
                'effectiveTo': null,
                'isActive': true,
              },
              {
                'id': 'mine-old',
                'priceListId': 'pl1',
                'productId': 'p1',
                'variantId': null,
                'branchId': null,
                'priceType': 0,
                'price': 5,
                'currency': 'TZS',
                'minQuantity': 1,
                'effectiveFrom': null,
                'effectiveTo': null,
                'isActive': true,
              },
            ])),
        ScriptedResponse(200, jsonEncode([])),
      ]);
      final repository = ProductRepository(apiClient: clientWith(adapter));

      await repository.setSellingPrice(
        priceList: const PriceList(
          id: 'pl1',
          name: 'Retail Prices',
          currency: 'TZS',
          isDefault: true,
        ),
        productId: 'p1',
        price: 3200,
      );

      expect(adapter.requests.length, 2);
      final put = adapter.requests[1];
      expect(put.method, 'PUT');
      expect(
        put.path,
        'https://api.test.local/api/v1/price-lists/pl1/prices',
      );
      final body = jsonDecode(put.body!) as Map<String, dynamic>;
      final prices = body['prices'] as List<dynamic>;
      expect(prices, hasLength(3));
      // The old row keeps its id so the backend upserts in place.
      final mine = prices.singleWhere((row) => row['productId'] == 'p1');
      expect(mine['id'], 'mine-old');
      expect((mine['price'] as num).toDouble(), 3200);
      expect(prices.any((row) => row['productId'] == 'other-a'), isTrue);
      expect(prices.any((row) => row['productId'] == 'other-b'), isTrue);
    });

    test('recordOpeningStock posts to the opening endpoint with defaults',
        () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode({
              'warehouseId': 'w1',
              'stockLocationId': 'l1',
              'productId': 'p1',
              'variantId': null,
              'quantity': 50,
            })),
      ]);
      final repository = ProductRepository(apiClient: clientWith(adapter));

      final balance = await repository.recordOpeningStock(
        const OpeningStockEntry(
          warehouseId: 'w1',
          productId: 'p1',
          quantity: 50,
          unitOfMeasureId: 'u1',
        ),
      );

      expect(balance.quantity, 50);
      final body =
          jsonDecode(adapter.requests.single.body!) as Map<String, dynamic>;
      expect(body['warehouseId'], 'w1');
      expect(body['quantity'], 50);
      expect(body['unitOfMeasureId'], 'u1');
      expect(body.containsKey('locationId'), isFalse);
      expect((body['effectiveAt'] as String), isNotEmpty);
    });

    test('adjustStock posts a delta to the adjustments endpoint', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode({
              'warehouseId': 'w1',
              'stockLocationId': 'l1',
              'productId': 'p1',
              'variantId': null,
              'quantity': 80,
            })),
      ]);
      final repository = ProductRepository(apiClient: clientWith(adapter));

      final balance = await repository.adjustStock(
        const AdjustStockEntry(
          warehouseId: 'w1',
          productId: 'p1',
          quantityDelta: 30,
          reason: 'Ongeza stock',
        ),
      );

      expect(balance.quantity, 80);
      expect(
        adapter.requests.single.path,
        'https://api.test.local/api/v1/inventory/stock/adjustments',
      );
      final body =
          jsonDecode(adapter.requests.single.body!) as Map<String, dynamic>;
      expect(body['quantityDelta'], 30);
      expect(body['reason'], 'Ongeza stock');
      expect(body.containsKey('locationId'), isFalse);
      expect((body['effectiveAt'] as String), isNotEmpty);
    });

    test('adjustStock sends the Idempotency-Key header when a key is provided',
        () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode({
              'warehouseId': 'w1',
              'stockLocationId': 'l1',
              'productId': 'p1',
              'variantId': null,
              'quantity': 80,
            })),
      ]);
      final repository = ProductRepository(apiClient: clientWith(adapter));

      await repository.adjustStock(
        const AdjustStockEntry(
          warehouseId: 'w1',
          productId: 'p1',
          quantityDelta: 30,
          reason: 'Ongeza stock',
          idempotencyKey: '00000000-0000-0000-0000-0000000000ab',
        ),
      );

      expect(
        adapter.requests.single.headers['Idempotency-Key'],
        '00000000-0000-0000-0000-0000000000ab',
      );
    });

    test('adjustStock omits the Idempotency-Key header without a key',
        () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode({
              'warehouseId': 'w1',
              'stockLocationId': 'l1',
              'productId': 'p1',
              'variantId': null,
              'quantity': 80,
            })),
      ]);
      final repository = ProductRepository(apiClient: clientWith(adapter));

      await repository.adjustStock(
        const AdjustStockEntry(
          warehouseId: 'w1',
          productId: 'p1',
          quantityDelta: 30,
        ),
      );

      expect(
        adapter.requests.single.headers.containsKey('Idempotency-Key'),
        isFalse,
      );
    });

    test('backend ProblemDetails surface as typed exceptions', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
          409,
          jsonEncode({
            'title': 'Conflict',
            'detail': 'SKU already exists.',
            'code': 'Conflict',
          }),
        ),
      ]);
      final repository = ProductRepository(apiClient: clientWith(adapter));

      await expectLater(
        repository.create(
          const ProductDraft(name: 'X', unitOfMeasureId: 'u1'),
        ),
        throwsA(isA<ConflictException>()),
      );
    });
  });
}
