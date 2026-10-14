import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/config/app_config.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/core/network/api_client.dart';
import 'package:jolinx_app/features/reports/data/report_repository.dart';
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

void main() {
  group('ReportRepository HTTP contract', () {
    test('salesSummary parses totalSales, totalRevenue, averageSale', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode({
              'totalSales': 42,
              'totalRevenue': 150000,
              'totalTax': 15000,
              'totalDiscount': 0,
              'averageSale': 3571.43,
            })),
      ]);
      final repository = ReportRepository(apiClient: clientWith(adapter));

      final summary = await repository.salesSummary(
        from: DateTime.utc(2026, 1, 1),
        to: DateTime.utc(2026, 12, 31),
      );

      expect(
        adapter.requests.single.path,
        contains('/api/v1/reports/sales-summary'),
      );
      expect(summary.totalSales, 42);
      expect(summary.totalRevenue, 150000);
      expect(summary.averageSale, 3571.43);
    });

    test('salesSummary defaults to zero when fields are missing', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, jsonEncode(<String, dynamic>{})),
      ]);
      final repository = ReportRepository(apiClient: clientWith(adapter));

      final summary = await repository.salesSummary();

      expect(summary.totalSales, 0);
      expect(summary.totalRevenue, 0);
      expect(summary.averageSale, 0);
    });

    test('salesSummary sends the requested range', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, jsonEncode(<String, dynamic>{})),
      ]);
      final repository = ReportRepository(apiClient: clientWith(adapter));

      await repository.salesSummary(
        from: DateTime.utc(2026, 9, 1),
        to: DateTime.utc(2026, 9, 8),
      );

      final query = Uri.parse(adapter.requests.single.path).queryParameters;
      expect(query['from'], '2026-09-01T00:00:00.000Z');
      expect(query['to'], '2026-09-08T00:00:00.000Z');
    });

    test('topProducts parses items list with expected fields including profit', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode({
              'products': [
                {
                  'productName': 'Mchele',
                  'totalQuantity': 200,
                  'totalRevenue': 500000,
                  'totalCost': 350000,
                  'totalProfit': 150000,
                  'marginPercent': 30.0,
                },
                {
                  'productName': 'Sukari',
                  'totalQuantity': 80,
                  'totalRevenue': 160000,
                  'totalCost': 120000,
                  'totalProfit': 40000,
                  'marginPercent': 25.0,
                },
              ],
            })),
      ]);
      final repository = ReportRepository(apiClient: clientWith(adapter));

      final products = await repository.topProducts(limit: 10);

      expect(
        adapter.requests.single.path,
        contains('/api/v1/reports/top-products'),
      );
      expect(products, hasLength(2));
      expect(products[0].productName, 'Mchele');
      expect(products[0].totalQuantity, 200);
      expect(products[0].totalRevenue, 500000);
      expect(products[0].totalCost, 350000);
      expect(products[0].totalProfit, 150000);
      expect(products[0].marginPercent, 30.0);
      expect(products[1].productName, 'Sukari');
      expect(products[1].totalProfit, 40000);
    });

    test('topProducts returns empty list when items is absent', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, jsonEncode(<String, dynamic>{})),
      ]);
      final repository = ReportRepository(apiClient: clientWith(adapter));

      final products = await repository.topProducts();

      expect(products, isEmpty);
    });

    test('salesTrend requests the 7-day window and parses points', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode({
              'from': '2026-09-02T00:00:00.000Z',
              'to': '2026-09-09T00:00:00.000Z',
              'days': 7,
              'dataPoints': [
                {
                  'label': '2026-09-08',
                  'saleCount': 12,
                  'revenue': 120000,
                  'tax': 0
                },
                {
                  'label': '2026-09-07',
                  'saleCount': 5,
                  'revenue': 50000,
                  'tax': 0
                },
              ],
            })),
      ]);
      final repository = ReportRepository(apiClient: clientWith(adapter));

      final trend = await repository.salesTrend(days: 7);

      expect(
        adapter.requests.single.path,
        contains('/api/v1/reports/sales-trend'),
      );
      expect(
        Uri.parse(adapter.requests.single.path).queryParameters['days'],
        '7',
      );
      expect(trend, hasLength(2));
      expect(trend[0].label, '2026-09-08');
      expect(trend[0].revenue, 120000);
      expect(trend[1].label, '2026-09-07');
    });

    test('salesTrend returns empty list when dataPoints is absent', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, jsonEncode(<String, dynamic>{})),
      ]);
      final repository = ReportRepository(apiClient: clientWith(adapter));

      final trend = await repository.salesTrend();

      expect(trend, isEmpty);
    });

    test('bad response throws ServerException', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            500,
            jsonEncode({
              'title': 'Server',
              'detail': 'Internal error.',
              'code': 'Server',
            })),
      ]);
      final repository = ReportRepository(apiClient: clientWith(adapter));

      await expectLater(
        repository.salesSummary(),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
