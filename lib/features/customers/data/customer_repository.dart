import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';

class PagedCustomers {
  const PagedCustomers({required this.items, required this.total});

  final List<Map<String, dynamic>> items;
  final int total;
}

class CustomerRepository {
  CustomerRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<PagedCustomers> list({
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
      '/api/v1/customers',
      query: query,
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    final doc = Map<String, dynamic>.from(response.data as Map);
    final items = (doc['items'] as List<dynamic>? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .toList(growable: false);
    return PagedCustomers(
      items: items,
      total: (doc['total'] as num?)?.toInt() ?? items.length,
    );
  }

  Future<Map<String, dynamic>> getById(String id) async {
    final response = await _apiClient.get<dynamic>('/api/v1/customers/$id');
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final response = await _apiClient.post<dynamic>(
      '/api/v1/customers',
      body: body,
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> update(
      String id, Map<String, dynamic> body) async {
    final response = await _apiClient.put<dynamic>(
      '/api/v1/customers/$id',
      body: body,
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>?> getCredit(String customerId) async {
    final response = await _apiClient.get<dynamic>(
      '/api/v1/customers/$customerId/credit',
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<Map<String, dynamic>>> getOutstandingCredit() async {
    final response = await _apiClient.get<dynamic>(
      '/api/v1/credit/outstanding',
    );
    if (response.statusCode != 200 || response.data is! List) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return (response.data as List)
        .whereType<Map<dynamic, dynamic>>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .toList();
  }

  Future<Map<String, dynamic>> recordPayment(
      String customerId, double amount, String description) async {
    final response = await _apiClient.post<dynamic>(
      '/api/v1/customers/$customerId/credit/payment',
      body: {'amount': amount, 'description': description},
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }
}
