import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_routes.dart';
import '../../../core/network/app_exception.dart';

class SupplierRepository {
  SupplierRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<PagedSuppliers> list({
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
      ApiRoutes.v1('/suppliers'),
      query: query,
    );
    return _decodePage(response);
  }

  Future<Map<String, dynamic>> getById(String id) async {
    final response = await _apiClient.get<dynamic>(
      ApiRoutes.v1('/suppliers/$id'),
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final response = await _apiClient.post<dynamic>(
      ApiRoutes.v1('/suppliers'),
      body: body,
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> update(
    String id,
    Map<String, dynamic> body,
  ) async {
    final response = await _apiClient.put<dynamic>(
      ApiRoutes.v1('/suppliers/$id'),
      body: body,
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  PagedSuppliers _decodePage(Response<dynamic> response) {
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

class PagedSuppliers {
  const PagedSuppliers({required this.items, required this.total});

  final List<Map<String, dynamic>> items;
  final int total;
}
