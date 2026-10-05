import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/config/app_config.dart';
import 'package:jolinx_app/core/network/api_client.dart';
import 'package:jolinx_app/features/dashboard/data/dashboard_repository.dart';
import '../../support/fakes.dart';

ApiClient clientWith(ScriptedAdapter adapter) => ApiClient(
      config: AppConfig.forTest(
        apiBaseUrl: Uri.parse('https://api.test.local'),
        environment: AppEnvironment.dev,
      ),
      tokenStore: InMemoryTokenStore(),
      refresher: (_) async => throw UnimplementedError(),
      dio: Dio(BaseOptions(baseUrl: 'https://api.test.local'))
        ..httpClientAdapter = adapter,
    );

void main() {
  group('DashboardRepository HTTP contract', () {
    test('summary parses branchName, revenueToday, totalProducts', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode({
              'branchName': 'Dar es Salaam',
              'revenueToday': 125000,
              'catalog': {
                'totalProducts': 42,
              },
            })),
      ]);
      final repository = DashboardRepository(apiClient: clientWith(adapter));

      final summary = await repository.summary();

      expect(adapter.requests.single.path,
          'https://api.test.local/api/v1/dashboard/summary');
      expect(summary.branchName, 'Dar es Salaam');
      expect(summary.revenueToday, 125000);
      expect(summary.totalProducts, 42);
    });

    test('lowStock parses items list', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode({
              'items': [
                {'id': 'p1', 'name': 'Mchele', 'quantity': 2},
                {'id': 'p2', 'name': 'Sukari', 'quantity': 0},
              ],
            })),
      ]);
      final repository = DashboardRepository(apiClient: clientWith(adapter));

      final items = await repository.lowStock(limit: 5);

      expect(adapter.requests.single.path, contains('limit=5'));
      expect(items, hasLength(2));
      expect(items[0]['name'], 'Mchele');
      expect(items[1]['quantity'], 0);
    });

    test('recentActivity parses items list', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode({
              'items': [
                {'id': 'a1', 'type': 'sale', 'amount': 5000},
                {'id': 'a2', 'type': 'purchase', 'amount': 12000},
              ],
            })),
      ]);
      final repository = DashboardRepository(apiClient: clientWith(adapter));

      final items = await repository.recentActivity(limit: 3);

      expect(adapter.requests.single.path, contains('limit=3'));
      expect(items, hasLength(2));
      expect(items[0]['type'], 'sale');
      expect(items[1]['amount'], 12000);
    });

    test('salesTrend parses dataPoints list', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode({
              'dataPoints': [
                {'date': '2026-08-25', 'revenue': 10000, 'count': 5},
                {'date': '2026-08-26', 'revenue': 15000, 'count': 8},
              ],
            })),
      ]);
      final repository = DashboardRepository(apiClient: clientWith(adapter));

      final points = await repository.salesTrend(days: 7);

      expect(adapter.requests.single.path, contains('days=7'));
      expect(points, hasLength(2));
      expect(points[0]['date'], '2026-08-25');
      expect(points[1]['revenue'], 15000);
    });
  });
}
