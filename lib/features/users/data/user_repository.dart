import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../../roles/data/role_models.dart';
import 'user_models.dart';

class PagedUsers {
  const PagedUsers({required this.items, required this.total});

  final List<IdentityUser> items;
  final int total;
}

class UserRepository {
  UserRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<PagedUsers> list({int page = 1, int pageSize = 50}) async {
    final response = await _apiClient.get<dynamic>(
      '/api/v1/users',
      query: {'page': page, 'pageSize': pageSize},
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    final doc = Map<String, dynamic>.from(response.data as Map);
    final items = (doc['items'] as List<dynamic>? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((raw) => IdentityUser.fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
    return PagedUsers(
      items: items,
      total: (doc['total'] as num?)?.toInt() ?? items.length,
    );
  }

  Future<IdentityUser> getById(String id) async {
    final response = await _apiClient.get<dynamic>('/api/v1/users/$id');
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return IdentityUser.fromJson(
        Map<String, dynamic>.from(response.data as Map));
  }

  Future<void> create(Map<String, dynamic> body) async {
    final response = await _apiClient.post<dynamic>(
      '/api/v1/users',
      body: body,
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ServerException('Imeshindikana kuunda mtumiaji.');
    }
  }

  Future<void> update(String id, Map<String, dynamic> body) async {
    final response = await _apiClient.put<dynamic>(
      '/api/v1/users/$id',
      body: body,
    );
    if (response.statusCode != 200) {
      throw ServerException('Imeshindikana kusasisha mtumiaji.');
    }
  }

  Future<void> setStatus(String id, bool isActive) async {
    final response = await _apiClient.patch<dynamic>(
      '/api/v1/users/$id/status',
      body: {'isActive': isActive},
    );
    if (response.statusCode != 200) {
      throw ServerException('Imeshindikana kubadilisha hali ya mtumiaji.');
    }
  }

  Future<void> delete(String id) async {
    final response = await _apiClient.delete<dynamic>('/api/v1/users/$id');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw ServerException('Imeshindikana kufuta mtumiaji.');
    }
  }

  Future<void> setRoles(String userId, List<String> roleIds) async {
    final response = await _apiClient.put<dynamic>(
      '/api/v1/users/$userId/roles',
      body: {'roleIds': roleIds},
    );
    if (response.statusCode != 200) {
      throw ServerException('Imeshindikana kusasisha majukumu ya mtumiaji.');
    }
  }

  Future<List<Role>> roles() async {
    final response = await _apiClient.get<dynamic>('/api/v1/roles');
    if (response.statusCode != 200 || response.data is! List) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return (response.data as List<dynamic>)
        .whereType<Map<dynamic, dynamic>>()
        .map((raw) => Role.fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }
}
