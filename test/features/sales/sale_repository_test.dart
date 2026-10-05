import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/config/app_config.dart';
import 'package:jolinx_app/core/network/api_client.dart';
import 'package:jolinx_app/features/sales/data/sale_repository.dart';
import 'package:jolinx_app/features/sales/domain/sale.dart';
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

Map<String, dynamic> saleJson(String id, {String number = 'S-2026-000001'}) => {
      'id': id,
      'tenantId': 't1',
      'branchId': 'b1',
      'warehouseId': 'w1',
      'cashierId': 'u1',
      'number': number,
      'clientSaleId': '7af1e69a-1111-2222-3333-444455556666',
      'source': 0,
      'status': 0,
      'saleDate': '2026-08-23T10:00:00Z',
      'effectiveAt': '2026-08-23T10:00:00Z',
      'currency': 'TZS',
      'priceListId': null,
      'isPriceTaxInclusive': true,
      'isElectronicPayment': false,
      'customer': null,
      'subtotal': 8000,
      'discountAmount': 0,
      'taxAmount': 720,
      'totalAmount': 8720,
      'amountPaid': 8720,
      'change': 0,
      'lines': [
        {
          'id': 'l1',
          'productId': 'p1',
          'variantId': null,
          'productName': 'Mchele',
          'sku': null,
          'barcode': null,
          'unitOfMeasureId': 'u1',
          'unitOfMeasureName': 'Kipande',
          'quantity': 2,
          'unitPrice': 2500,
          'discountAmount': 0,
          'taxCode': 'A',
          'appliedRate': 0.18,
          'appliedRuleId': null,
          'baseAmount': 6779.66,
          'taxAmount': 720,
          'lineTotal': 5000,
          'orderIndex': 0,
        },
        {
          'id': 'l2',
          'productId': 'p2',
          'variantId': null,
          'productName': 'Sukari',
          'sku': null,
          'barcode': null,
          'unitOfMeasureId': 'u1',
          'unitOfMeasureName': 'Kipande',
          'quantity': 1,
          'unitPrice': 3000,
          'discountAmount': 0,
          'taxCode': 'A',
          'appliedRate': 0.18,
          'appliedRuleId': null,
          'baseAmount': 2542.37,
          'taxAmount': 457.63,
          'lineTotal': 3000,
          'orderIndex': 1,
        },
      ],
      'payments': [
        {
          'id': 'pay1',
          'method': 0,
          'amount': 8720,
          'provider': null,
          'phoneNumber': null,
          'reference': null,
          'orderIndex': 0,
        },
      ],
      'createdAt': '2026-08-23T10:00:00Z',
      'updatedAt': null,
    };

CartLine rice({double quantity = 2}) => CartLine(
      productId: 'p1',
      name: 'Mchele',
      unitPrice: 2500,
      quantity: quantity,
    );

void main() {
  group('SaleRepository HTTP contract', () {
    test('create posts the exact backend contract with idempotency key',
        () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, jsonEncode(saleJson('s1'))),
      ]);
      final repository = SaleRepository(apiClient: clientWith(adapter));

      final body = buildCreateSaleBody(
        branchId: 'branch-1',
        clientSaleId: '7af1e69a-1111-2222-3333-444455556666',
        lines: [rice(), rice(quantity: 3)],
        paymentMethod: PaymentMethod.mobileMoney,
        total: 8720,
        effectiveAt: DateTime.utc(2026, 8, 23, 10),
      );
      final sale = await repository.create(
        body: body,
        idempotencyKey: '7af1e69a-1111-2222-3333-444455556666',
      );

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, 'https://api.test.local/api/v1/sales');
      final idempotency = request.headers.entries
          .firstWhere((entry) => entry.key.toLowerCase() == 'idempotency-key')
          .value;
      expect(idempotency, '7af1e69a-1111-2222-3333-444455556666');

      final sent = jsonDecode(request.body!) as Map<String, dynamic>;
      expect(sent['branchId'], 'branch-1');
      expect(sent['clientSaleId'], '7af1e69a-1111-2222-3333-444455556666');
      expect(sent['source'], 0);
      expect(sent['isElectronicPayment'], isTrue,
          reason: 'Mobile Money counts as electronic for tax rate selection');
      expect(sent['lines'], [
        {'productId': 'p1', 'quantity': 2},
        {'productId': 'p1', 'quantity': 3},
      ]);
      expect(sent['payments'], [
        {'method': 1, 'amount': 8720},
      ]);

      expect(sale.number, 'S-2026-000001');
      expect(sale.totalAmount, 8720);
      expect(sale.taxAmount, 720);
      expect(sale.lines.length, 2);
      expect(sale.payments.single.label, 'Cash');
    });

    test('cash payments are not electronic and methods bind as ints', () async {
      final adapter = ScriptedAdapter([const ScriptedResponse(200, '{}')]);
      final body = buildCreateSaleBody(
        branchId: 'b',
        clientSaleId: 'x',
        lines: [rice()],
        paymentMethod: PaymentMethod.cash,
        total: 2500,
      );
      await clientWith(adapter)
          .post<Map<String, dynamic>>('/sales', body: body);

      final sent =
          jsonDecode(adapter.requests.single.body!) as Map<String, dynamic>;
      expect(sent['isElectronicPayment'], isFalse);
      expect((sent['payments'] as List).single['method'], 0);
    });

    test('quick-sale line sends a client-fixed unit price override', () async {
      final adapter = ScriptedAdapter([const ScriptedResponse(200, '{}')]);
      final body = buildCreateSaleBody(
        branchId: 'b',
        clientSaleId: 'x',
        lines: [
          CartLine(
            productId: 'p-quick',
            name: 'Uza Haraka',
            unitPrice: 15000,
            unitPriceOverride: 15000,
            key: 'quick-1',
          ),
        ],
        paymentMethod: PaymentMethod.cash,
        total: 15000,
      );
      await clientWith(adapter)
          .post<Map<String, dynamic>>('/sales', body: body);

      final sent =
          jsonDecode(adapter.requests.single.body!) as Map<String, dynamic>;
      expect(sent['lines'], [
        {
          'productId': 'p-quick',
          'quantity': 1.0,
          'unitPrice': 15000.0,
          'productName': 'Uza Haraka',
        },
      ]);
    });

    test('getOrCreateQuickSaleProduct posts and returns the product id',
        () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode({
              'id': 'p-quick',
              'name': 'Uza Haraka',
              'sku': 'QS-BILA-JINA',
            })),
      ]);
      final repository = SaleRepository(apiClient: clientWith(adapter));

      final id = await repository.getOrCreateQuickSaleProduct();

      expect(adapter.requests.single.method, 'POST');
      expect(
        adapter.requests.single.path,
        'https://api.test.local/api/v1/products/quick-sale',
      );
      expect(id, 'p-quick');
    });

    test('getById fetches one sale', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, jsonEncode(saleJson('s9'))),
      ]);
      final repository = SaleRepository(apiClient: clientWith(adapter));

      final sale = await repository.getById('s9');

      expect(
        adapter.requests.single.path,
        'https://api.test.local/api/v1/sales/s9',
      );
      expect(sale.id, 's9');
    });

    test('list sends today window and status filter', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode({
              'items': [saleJson('s1')],
              'page': 1,
              'pageSize': 100,
              'total': 1,
            })),
      ]);
      final repository = SaleRepository(apiClient: clientWith(adapter));

      final page = await repository.list(
        from: DateTime.utc(2026, 8, 23),
        to: DateTime.utc(2026, 8, 24),
        pageSize: 100,
      );

      final path = adapter.requests.single.path;
      expect(path, contains('/api/v1/sales?'));
      expect(path, contains('from=2026-08-23T00%3A00%3A00.000Z'));
      expect(path, contains('to=2026-08-24T00%3A00%3A00.000Z'));
      expect(page.items.single.number, 'S-2026-000001');
    });

    test('resolvePrice returns the resolved retail price', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode({
              'price': 2500,
              'currency': 'TZS',
              'priceListId': 'pl1',
              'priceType': 0,
              'minQuantity': 1,
            })),
      ]);
      final repository = SaleRepository(apiClient: clientWith(adapter));

      final price = await repository.resolvePrice('p1', branchId: 'b1');

      expect(
        adapter.requests.single.path,
        contains('/api/v1/pricing/resolve?productId=p1&'),
      );
      expect(price!.price, 2500);
    });

    test('resolvePrices prices many lines in ONE request', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode([
              {
                'productId': 'p1',
                'price': 2500,
                'currency': 'TZS',
              },
              {
                'productId': 'p2',
                'price': null,
                'currency': null,
                'errorMessage':
                    'No price could be resolved for the given product.',
              },
            ])),
      ]);
      final repository = SaleRepository(apiClient: clientWith(adapter));

      final prices = await repository.resolvePrices(
        productIds: ['p1', 'p2'],
        quantities: [1, 2],
        branchId: 'b1',
      );

      expect(adapter.requests.single.method, 'POST');
      expect(
        adapter.requests.single.path,
        'https://api.test.local/api/v1/pricing/resolve-many',
      );
      final sent =
          jsonDecode(adapter.requests.single.body!) as Map<String, dynamic>;
      expect(sent['priceType'], 0);
      expect(sent['branchId'], 'b1');
      expect(sent['lines'], [
        {'productId': 'p1', 'quantity': 1},
        {'productId': 'p2', 'quantity': 2},
      ]);
      expect(prices, {'p1': 2500.0},
          reason: 'unresolvable lines are absent so callers keep cart prices');
    });

    test('voidSale posts the reason and returns the voided sale', () async {
      final voided = saleJson('s9');
      voided['status'] = 1;
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, jsonEncode(voided)),
      ]);
      final repository = SaleRepository(apiClient: clientWith(adapter));

      final sale = await repository.voidSale('s9', 'Mmuhudumu alikosea');

      expect(adapter.requests.single.method, 'POST');
      expect(
        adapter.requests.single.path,
        'https://api.test.local/api/v1/sales/s9/void',
      );
      final sent =
          jsonDecode(adapter.requests.single.body!) as Map<String, dynamic>;
      expect(sent['reason'], 'Mmuhudumu alikosea');
      expect(sale.isVoided, isTrue);
    });
  });
}
