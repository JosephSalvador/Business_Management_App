import '../../../core/network/api_client.dart';

class DashboardSummary {
  const DashboardSummary({
    required this.branchName,
    required this.revenueToday,
    required this.totalProducts,
  });

  final String branchName;
  final num revenueToday;
  final int totalProducts;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final catalog = json['catalog'] as Map<String, dynamic>? ?? {};
    return DashboardSummary(
      branchName: json['branchName'] as String? ?? '',
      revenueToday: json['revenueToday'] as num? ?? 0,
      totalProducts: (catalog['totalProducts'] as num?)?.toInt() ?? 0,
    );
  }
}

class DashboardRepository {
  DashboardRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<DashboardSummary> summary() async {
    final response = await _apiClient.get<dynamic>(
      '/api/v1/dashboard/summary',
    );
    return DashboardSummary.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<List<Map<String, dynamic>>> lowStock({int limit = 5}) async {
    final response = await _apiClient.get<dynamic>(
      '/api/v1/dashboard/low-stock',
      query: {'limit': limit},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return (data['items'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> recentActivity({int limit = 5}) async {
    final response = await _apiClient.get<dynamic>(
      '/api/v1/dashboard/recent-activity',
      query: {'limit': limit},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return (data['items'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> salesTrend({int days = 7}) async {
    final response = await _apiClient.get<dynamic>(
      '/api/v1/reports/sales-trend',
      query: {'days': days},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return (data['dataPoints'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> topProducts({
    int limit = 5,
    DateTime? from,
    DateTime? to,
  }) async {
    final now = DateTime.now();
    final response = await _apiClient.get<dynamic>(
      '/api/v1/reports/top-products',
      query: {
        'from':
            (from ?? now.subtract(const Duration(days: 30))).toIso8601String(),
        'to': (to ?? now).toIso8601String(),
        'limit': limit,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }
}
