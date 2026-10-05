import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/config/app_config.dart';
import 'package:jolinx_app/core/network/api_client.dart';
import 'package:jolinx_app/features/sales/data/sale_repository.dart';

import '../../support/fakes.dart';

ApiClient _clientWith(ScriptedAdapter adapter) => ApiClient(
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

Map<String, dynamic> _saleJson(String id, {int status = 0}) => {
      'id': id,
      'tenantId': 't1',
      'branchId': 'b1',
      'cashierId': 'u1',
      'number': 'S-2026-000001',
      'clientSaleId': '7af1e69a-1111-2222-3333-444455556666',
      'source': 0,
      'status': status,
      'saleDate': '2026-08-23T10:00:00Z',
      'effectiveAt': '2026-08-23T10:00:00Z',
      'currency': 'TZS',
      'isElectronicPayment': false,
      'subtotal': 5000,
      'discountAmount': 0,
      'taxAmount': 0,
      'totalAmount': 5000,
      'amountPaid': 5000,
      'change': 0,
      'lines': <dynamic>[],
      'payments': <dynamic>[],
    };

void main() {
  test('voidSale posts the reason and parses voided status', () async {
    final voided = _saleJson('s1', status: 1);
    final adapter = ScriptedAdapter([
      ScriptedResponse(200, jsonEncode(voided)),
    ]);
    final repository = SaleRepository(apiClient: _clientWith(adapter));

    final sale = await repository.voidSale('s1', 'Wrong items');

    expect(adapter.requests.single.method, 'POST');
    expect(
      adapter.requests.single.path,
      'https://api.test.local/api/v1/sales/s1/void',
    );
    final sent =
        jsonDecode(adapter.requests.single.body!) as Map<String, dynamic>;
    expect(sent['reason'], 'Wrong items');
    expect(sale.isVoided, isTrue);
  });

  test('voidSale passes the sale id in the URL', () async {
    final adapter = ScriptedAdapter([
      ScriptedResponse(200, jsonEncode(_saleJson('s-abc', status: 1))),
    ]);
    final repository = SaleRepository(apiClient: _clientWith(adapter));

    await repository.voidSale('s-abc', 'Cashier mistake');

    expect(
      adapter.requests.single.path,
      contains('/api/v1/sales/s-abc/void'),
    );
  });

  test('voidSale throws when the backend rejects the reason', () async {
    final adapter = ScriptedAdapter([
      ScriptedResponse(
          422,
          jsonEncode({
            'message': 'A void reason is required.',
            'code': 'Validation',
          })),
    ]);
    final repository = SaleRepository(apiClient: _clientWith(adapter));

    expect(
      () => repository.voidSale('s1', ''),
      throwsA(isA<Exception>()),
    );
  });
}
