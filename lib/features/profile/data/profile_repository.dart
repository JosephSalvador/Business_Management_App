import '../../../core/network/api_client.dart';
import '../../../core/network/api_routes.dart';
import '../../../core/network/app_exception.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.tenantName,
    required this.roleNames,
    required this.permissions,
  });

  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String tenantName;
  final List<String> roleNames;
  final List<String> permissions;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String? ?? '',
        fullName: json['fullName'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String?,
        tenantName: json['tenantName'] as String? ?? '',
        roleNames:
            (json['roleNames'] as List<dynamic>?)?.cast<String>() ?? const [],
        permissions:
            (json['permissions'] as List<dynamic>?)?.cast<String>() ?? const [],
      );
}

class ProfileRepository {
  ProfileRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<UserProfile> get() async {
    final response = await _apiClient.get<dynamic>(ApiRoutes.v1('/users/me'));
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return UserProfile.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<UserProfile> updateProfile({
    String? fullName,
    String? phone,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['fullName'] = fullName;
    if (phone != null) body['phone'] = phone;
    final response = await _apiClient.put<dynamic>(
      ApiRoutes.v1('/users/me'),
      body: body,
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Imeshindikana kusasisha wasifu.');
    }
    return UserProfile.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _apiClient.put<dynamic>(
      ApiRoutes.v1('/users/me/password'),
      body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
    if (response.statusCode != 200) {
      throw ServerException('Imeshindikana kubadilisha nenosiri.');
    }
  }
}
