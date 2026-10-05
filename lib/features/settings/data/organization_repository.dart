import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';

class Organization {
  const Organization({
    this.name,
    this.address,
    this.phone,
    this.email,
    this.taxId,
    this.countryCode,
    this.currency,
  });

  final String? name;
  final String? address;
  final String? phone;
  final String? email;
  final String? taxId;
  final String? countryCode;
  final String? currency;

  factory Organization.fromJson(Map<String, dynamic> json) => Organization(
        name: json['name'] as String?,
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        taxId: json['taxId'] as String?,
        countryCode: json['countryCode'] as String?,
        currency: json['currency'] as String?,
      );
}

class OrganizationRepository {
  OrganizationRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<Organization> get() async {
    final response = await _apiClient.get<dynamic>('/api/v1/organization');
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return Organization.fromJson(
      Map<String, dynamic>.from(response.data as Map<dynamic, dynamic>),
    );
  }

  Future<Organization> update(Map<String, dynamic> body) async {
    final response = await _apiClient.put<dynamic>(
      '/api/v1/organization',
      body: body,
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return Organization.fromJson(
      Map<String, dynamic>.from(response.data as Map<dynamic, dynamic>),
    );
  }
}
