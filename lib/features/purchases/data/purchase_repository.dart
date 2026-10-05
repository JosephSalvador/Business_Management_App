import '../../../core/network/api_client.dart';
import '../../../core/network/api_routes.dart';
import '../../../core/network/app_exception.dart';

class PurchaseRepository {
  PurchaseRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<PagedPurchases> list({
    int page = 1,
    int pageSize = 20,
    String? search,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    };
    final response = await _apiClient.get<dynamic>(
      ApiRoutes.v1('/purchase-orders'),
      query: query,
    );
    return _decodePage(response);
  }

  Future<Map<String, dynamic>> getById(String id) async {
    final response = await _apiClient.get<dynamic>(
      ApiRoutes.v1('/purchase-orders/$id'),
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> create(Map<String, dynamic> body) async {
    await _apiClient.post<dynamic>(
      ApiRoutes.v1('/purchase-orders'),
      body: body,
    );
  }

  Future<void> submit(String id) async {
    await _apiClient.post<dynamic>(
      ApiRoutes.v1('/purchase-orders/$id/submit'),
    );
  }

  Future<void> cancel(String id) async {
    await _apiClient.post<dynamic>(
      ApiRoutes.v1('/purchase-orders/$id/cancel'),
    );
  }

  Future<PagedSuppliers> suppliers({
    int page = 1,
    int pageSize = 100,
  }) async {
    final response = await _apiClient.get<dynamic>(
      ApiRoutes.v1('/suppliers'),
      query: {'page': page, 'pageSize': pageSize},
    );
    return _decodeSuppliers(response);
  }

  Future<List<Map<String, dynamic>>> warehouses() async {
    final response = await _apiClient.get<dynamic>(
      ApiRoutes.v1('/warehouses'),
    );
    if (response.statusCode != 200 || response.data is! List) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return (response.data as List<dynamic>)
        .whereType<Map<dynamic, dynamic>>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .toList(growable: false);
  }

  PagedPurchases _decodePage(dynamic response) {
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    final doc = Map<String, dynamic>.from(response.data as Map);
    final items = (doc['items'] as List<dynamic>? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .toList(growable: false);
    return PagedPurchases(
      items: items,
      total: (doc['total'] as num?)?.toInt() ?? items.length,
    );
  }

  PagedSuppliers _decodeSuppliers(dynamic response) {
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    final doc = Map<String, dynamic>.from(response.data as Map);
    final items = (doc['items'] as List<dynamic>? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .toList(growable: false);
    return PagedSuppliers(
      items: items,
      total: (doc['total'] as num?)?.toInt() ?? items.length,
    );
  }
}

class PagedPurchases {
  const PagedPurchases({required this.items, required this.total});

  final List<Map<String, dynamic>> items;
  final int total;
}

class PagedSuppliers {
  const PagedSuppliers({required this.items, required this.total});

  final List<Map<String, dynamic>> items;
  final int total;
}
