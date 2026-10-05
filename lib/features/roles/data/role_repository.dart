import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import 'role_models.dart';

class RoleRepository {
  RoleRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<Role>> list() async {
    final response = await _apiClient.get<dynamic>('/api/v1/roles');
    if (response.statusCode != 200 || response.data is! List) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return (response.data as List<dynamic>)
        .whereType<Map<dynamic, dynamic>>()
        .map((raw) => Role.fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }

  Future<Role> getById(String id) async {
    final response = await _apiClient.get<dynamic>('/api/v1/roles/$id');
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return Role.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<Role> create({required String name, String? description}) async {
    final response = await _apiClient.post<dynamic>(
      '/api/v1/roles',
      body: {
        'name': name,
        'description': description,
      },
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ServerException('Imeshindikana kuunda jukumu.');
    }
    return Role.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<void> update(String id,
      {required String name, String? description}) async {
    final response = await _apiClient.put<dynamic>(
      '/api/v1/roles/$id',
      body: {
        'name': name,
        'description': description,
      },
    );
    if (response.statusCode != 200) {
      throw ServerException('Imeshindikana kusasisha jukumu.');
    }
  }

  Future<void> delete(String id) async {
    final response = await _apiClient.delete<dynamic>('/api/v1/roles/$id');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw ServerException('Imeshindikana kufuta jukumu.');
    }
  }

  Future<List<Permission>> permissions() async {
    final response = await _apiClient.get<dynamic>('/api/v1/permissions');
    if (response.statusCode != 200 || response.data is! List) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return (response.data as List<dynamic>)
        .whereType<Map<dynamic, dynamic>>()
        .map((raw) => Permission.fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }

  Future<List<String>> rolePermissions(String roleId) async {
    final response = await _apiClient.get<dynamic>(
      '/api/v1/roles/$roleId/permissions',
    );
    if (response.statusCode != 200 || response.data is! List) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return (response.data as List<dynamic>).cast<String>().toList();
  }

  Future<void> setRolePermissions(
      String roleId, List<String> permissions) async {
    final response = await _apiClient.put<dynamic>(
      '/api/v1/roles/$roleId/permissions',
      body: {'permissionNames': permissions},
    );
    if (response.statusCode != 200) {
      throw ServerException('Imeshindikana kusasisha ruhusa za jukumu.');
    }
  }
}
