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
    final catalog =
        json['catalog'] is Map ? (json['catalog'] as Map) : const {};
    num parsedRevenue = 0;
    if (json['revenueToday'] is num) {
      parsedRevenue = json['revenueToday'] as num;
    } else if (json['revenueToday'] is String) {
      parsedRevenue = num.tryParse(json['revenueToday'] as String) ?? 0;
    }

    int parsedTotalProducts = 0;
    final rawProducts = catalog['totalProducts'] ?? json['totalProducts'];
    if (rawProducts is num) {
      parsedTotalProducts = rawProducts.toInt();
    } else if (rawProducts is String) {
      parsedTotalProducts = int.tryParse(rawProducts) ?? 0;
    }

    return DashboardSummary(
      branchName: json['branchName'] as String? ?? '',
      revenueToday: parsedRevenue,
      totalProducts: parsedTotalProducts,
    );
  }

  Map<String, dynamic> toJson() => {
        'branchName': branchName,
        'revenueToday': revenueToday,
        'catalog': {'totalProducts': totalProducts},
      };
}

class DashboardRepository {
  DashboardRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<DashboardSummary> summary() async {
    final response = await _apiClient.get<dynamic>(
      '/api/v1/dashboard/summary',
    );
    if (response.data is! Map) {
      return const DashboardSummary(
        branchName: '',
        revenueToday: 0,
        totalProducts: 0,
      );
    }
    return DashboardSummary.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<List<Map<String, dynamic>>> lowStock({int limit = 5}) async {
    final response = await _apiClient.get<dynamic>(
      '/api/v1/dashboard/low-stock',
      query: {'limit': limit},
    );
    if (response.data is! Map) return const [];
    final data = Map<String, dynamic>.from(response.data as Map);
    final rawItems = data['items'] as List<dynamic>? ?? [];
    return rawItems
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> recentActivity({int limit = 5}) async {
    final response = await _apiClient.get<dynamic>(
      '/api/v1/dashboard/recent-activity',
      query: {'limit': limit},
    );
    if (response.data is! Map) return const [];
    final data = Map<String, dynamic>.from(response.data as Map);
    final rawItems = data['items'] as List<dynamic>? ?? [];
    return rawItems
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> salesTrend({int days = 7}) async {
    final response = await _apiClient.get<dynamic>(
      '/api/v1/reports/sales-trend',
      query: {'days': days},
    );
    if (response.data is! Map) return const [];
    final data = Map<String, dynamic>.from(response.data as Map);
    final rawPoints = data['dataPoints'] as List<dynamic>? ?? [];
    return rawPoints
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
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
    if (response.data is! Map) return const {};
    return Map<String, dynamic>.from(response.data as Map);
  }
}
