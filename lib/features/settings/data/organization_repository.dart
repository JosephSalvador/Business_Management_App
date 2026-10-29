import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/storage/offline_cache_dao.dart';

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

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'phone': phone,
        'email': email,
        'taxId': taxId,
        'countryCode': countryCode,
        'currency': currency,
      };

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
  OrganizationRepository({
    required ApiClient apiClient,
    OfflineCacheDao? cache,
  })  : _apiClient = apiClient,
        _cache = cache;

  final ApiClient _apiClient;
  final OfflineCacheDao? _cache;

  static const _cacheKey = 'organization_profile';

  Future<Organization> get() async {
    try {
      final response = await _apiClient.get<dynamic>('/api/v1/organization');
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      final org = Organization.fromJson(
        Map<String, dynamic>.from(response.data as Map<dynamic, dynamic>),
      );
      if (_cache != null) {
        await _cache.save(_cacheKey, org.toJson());
      }
      return org;
    } on AppException {
      if (_cache == null) rethrow;
      final cached = await _cache.load(_cacheKey);
      if (cached != null) {
        return Organization.fromJson(cached);
      }
      return const Organization(
        name: 'Biashara Yangu',
        countryCode: 'TZ',
        currency: 'TZS',
      );
    }
  }

  Future<Organization> update(Map<String, dynamic> body) async {
    try {
      final response = await _apiClient.put<dynamic>(
        '/api/v1/organization',
        body: body,
      );
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      final updated = Organization.fromJson(
        Map<String, dynamic>.from(response.data as Map<dynamic, dynamic>),
      );
      if (_cache != null) {
        await _cache.save(_cacheKey, updated.toJson());
      }
      return updated;
    } on AppException {
      if (_cache == null) rethrow;
      final current = await get();
      final updated = Organization(
        name: body['name'] as String? ?? current.name,
        address: body['address'] as String? ?? current.address,
        phone: body['phone'] as String? ?? current.phone,
        email: body['email'] as String? ?? current.email,
        taxId: body['taxId'] as String? ?? current.taxId,
        countryCode: body['countryCode'] as String? ?? current.countryCode,
        currency: body['currency'] as String? ?? current.currency,
      );
      await _cache.save(_cacheKey, updated.toJson());
      return updated;
    }
  }
}
