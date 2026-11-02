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
    this.logoBase64,
    this.bankName,
    this.bankAccountName,
    this.bankAccountNumber,
    this.bankBranchOrSwift,
    this.mobileMoneyDetails,
    this.invoiceTerms,
    this.authorizedSignatoryName,
    this.authorizedSignatoryTitle,
  });

  final String? name;
  final String? address;
  final String? phone;
  final String? email;
  final String? taxId;
  final String? countryCode;
  final String? currency;
  final String? logoBase64;
  final String? bankName;
  final String? bankAccountName;
  final String? bankAccountNumber;
  final String? bankBranchOrSwift;
  final String? mobileMoneyDetails;
  final String? invoiceTerms;
  final String? authorizedSignatoryName;
  final String? authorizedSignatoryTitle;

  bool get hasLogo => logoBase64 != null && logoBase64!.trim().isNotEmpty;

  String get formattedPaymentInstructions {
    final lines = <String>[];
    if (bankName != null && bankName!.trim().isNotEmpty) {
      final acctName = (bankAccountName != null && bankAccountName!.trim().isNotEmpty)
          ? ' (${bankAccountName!.trim()})'
          : '';
      final acctNo = (bankAccountNumber != null && bankAccountNumber!.trim().isNotEmpty)
          ? ' - A/C: ${bankAccountNumber!.trim()}'
          : '';
      final swift = (bankBranchOrSwift != null && bankBranchOrSwift!.trim().isNotEmpty)
          ? ' [${bankBranchOrSwift!.trim()}]'
          : '';
      lines.add('Bank: ${bankName!.trim()}$acctNo$acctName$swift');
    }
    if (mobileMoneyDetails != null && mobileMoneyDetails!.trim().isNotEmpty) {
      lines.add('Mobile Money: ${mobileMoneyDetails!.trim()}');
    }
    return lines.join('\n');
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'phone': phone,
        'contactPhone': phone,
        'email': email,
        'contactEmail': email,
        'taxId': taxId,
        'countryCode': countryCode,
        'currency': currency,
        'logoBase64': logoBase64,
        'bankName': bankName,
        'bankAccountName': bankAccountName,
        'bankAccountNumber': bankAccountNumber,
        'bankBranchOrSwift': bankBranchOrSwift,
        'mobileMoneyDetails': mobileMoneyDetails,
        'invoiceTerms': invoiceTerms,
        'authorizedSignatoryName': authorizedSignatoryName,
        'authorizedSignatoryTitle': authorizedSignatoryTitle,
      };

  factory Organization.fromJson(Map<String, dynamic> json) => Organization(
        name: json['name'] as String?,
        address: json['address'] as String?,
        phone: (json['phone'] as String?) ?? (json['contactPhone'] as String?),
        email: (json['email'] as String?) ?? (json['contactEmail'] as String?),
        taxId: json['taxId'] as String?,
        countryCode: json['countryCode'] as String?,
        currency: json['currency'] as String?,
        logoBase64: json['logoBase64'] as String?,
        bankName: json['bankName'] as String?,
        bankAccountName: json['bankAccountName'] as String?,
        bankAccountNumber: json['bankAccountNumber'] as String?,
        bankBranchOrSwift: json['bankBranchOrSwift'] as String?,
        mobileMoneyDetails: json['mobileMoneyDetails'] as String?,
        invoiceTerms: json['invoiceTerms'] as String?,
        authorizedSignatoryName: json['authorizedSignatoryName'] as String?,
        authorizedSignatoryTitle: json['authorizedSignatoryTitle'] as String?,
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
    Organization? cachedOrg;
    if (_cache != null) {
      final cached = await _cache.load(_cacheKey);
      if (cached != null) {
        cachedOrg = Organization.fromJson(cached);
      }
    }
    try {
      final response = await _apiClient.get<dynamic>('/api/v1/organization');
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      final serverOrg = Organization.fromJson(
        Map<String, dynamic>.from(response.data as Map<dynamic, dynamic>),
      );
      final merged = _mergeWithLocalFallback(serverOrg, cachedOrg);
      if (_cache != null) {
        await _cache.save(_cacheKey, merged.toJson());
      }
      return merged;
    } on AppException {
      if (_cache == null) rethrow;
      if (cachedOrg != null) {
        return cachedOrg;
      }
      return const Organization(
        name: 'Biashara Yangu',
        countryCode: 'TZ',
        currency: 'TZS',
      );
    }
  }

  Future<Organization> update(Map<String, dynamic> body) async {
    final current = await get();
    final optimistic = Organization(
      name: body.containsKey('name') ? body['name'] as String? : current.name,
      address: body.containsKey('address')
          ? body['address'] as String?
          : current.address,
      phone: body.containsKey('phone')
          ? body['phone'] as String?
          : (body.containsKey('contactPhone')
              ? body['contactPhone'] as String?
              : current.phone),
      email: body.containsKey('email')
          ? body['email'] as String?
          : (body.containsKey('contactEmail')
              ? body['contactEmail'] as String?
              : current.email),
      taxId:
          body.containsKey('taxId') ? body['taxId'] as String? : current.taxId,
      countryCode: body.containsKey('countryCode')
          ? body['countryCode'] as String?
          : current.countryCode,
      currency: body.containsKey('currency')
          ? body['currency'] as String?
          : current.currency,
      logoBase64: body.containsKey('logoBase64')
          ? body['logoBase64'] as String?
          : current.logoBase64,
      bankName: body.containsKey('bankName')
          ? body['bankName'] as String?
          : current.bankName,
      bankAccountName: body.containsKey('bankAccountName')
          ? body['bankAccountName'] as String?
          : current.bankAccountName,
      bankAccountNumber: body.containsKey('bankAccountNumber')
          ? body['bankAccountNumber'] as String?
          : current.bankAccountNumber,
      bankBranchOrSwift: body.containsKey('bankBranchOrSwift')
          ? body['bankBranchOrSwift'] as String?
          : current.bankBranchOrSwift,
      mobileMoneyDetails: body.containsKey('mobileMoneyDetails')
          ? body['mobileMoneyDetails'] as String?
          : current.mobileMoneyDetails,
      invoiceTerms: body.containsKey('invoiceTerms')
          ? body['invoiceTerms'] as String?
          : current.invoiceTerms,
      authorizedSignatoryName: body.containsKey('authorizedSignatoryName')
          ? body['authorizedSignatoryName'] as String?
          : current.authorizedSignatoryName,
      authorizedSignatoryTitle: body.containsKey('authorizedSignatoryTitle')
          ? body['authorizedSignatoryTitle'] as String?
          : current.authorizedSignatoryTitle,
    );

    if (_cache != null) {
      await _cache.save(_cacheKey, optimistic.toJson());
    }

    try {
      final payload = <String, dynamic>{
        'name': optimistic.name ?? 'Biashara Yangu',
        'address': optimistic.address,
        'phone': optimistic.phone,
        'contactPhone': optimistic.phone,
        'email': optimistic.email,
        'contactEmail': optimistic.email,
        'taxId': optimistic.taxId,
        'countryCode': optimistic.countryCode ?? 'TZ',
        'currency': optimistic.currency ?? 'TZS',
        'logoBase64': optimistic.logoBase64,
        'bankName': optimistic.bankName,
        'bankAccountName': optimistic.bankAccountName,
        'bankAccountNumber': optimistic.bankAccountNumber,
        'bankBranchOrSwift': optimistic.bankBranchOrSwift,
        'mobileMoneyDetails': optimistic.mobileMoneyDetails,
        'invoiceTerms': optimistic.invoiceTerms,
        'authorizedSignatoryName': optimistic.authorizedSignatoryName,
        'authorizedSignatoryTitle': optimistic.authorizedSignatoryTitle,
      };
      final response = await _apiClient.put<dynamic>(
        '/api/v1/organization',
        body: payload,
      );
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      final serverUpdated = Organization.fromJson(
        Map<String, dynamic>.from(response.data as Map<dynamic, dynamic>),
      );
      final finalOrg = _mergeWithLocalFallback(serverUpdated, optimistic);
      if (_cache != null) {
        await _cache.save(_cacheKey, finalOrg.toJson());
      }
      return finalOrg;
    } on AppException {
      if (_cache == null) rethrow;
      return optimistic;
    }
  }

  Organization _mergeWithLocalFallback(
    Organization primary,
    Organization? fallback,
  ) {
    if (fallback == null) return primary;
    return Organization(
      name: primary.name ?? fallback.name,
      address: primary.address ?? fallback.address,
      phone: primary.phone ?? fallback.phone,
      email: primary.email ?? fallback.email,
      taxId: primary.taxId ?? fallback.taxId,
      countryCode: primary.countryCode ?? fallback.countryCode,
      currency: primary.currency ?? fallback.currency,
      logoBase64: primary.logoBase64 ?? fallback.logoBase64,
      bankName: primary.bankName ?? fallback.bankName,
      bankAccountName: primary.bankAccountName ?? fallback.bankAccountName,
      bankAccountNumber: primary.bankAccountNumber ?? fallback.bankAccountNumber,
      bankBranchOrSwift: primary.bankBranchOrSwift ?? fallback.bankBranchOrSwift,
      mobileMoneyDetails:
          primary.mobileMoneyDetails ?? fallback.mobileMoneyDetails,
      invoiceTerms: primary.invoiceTerms ?? fallback.invoiceTerms,
      authorizedSignatoryName:
          primary.authorizedSignatoryName ?? fallback.authorizedSignatoryName,
      authorizedSignatoryTitle:
          primary.authorizedSignatoryTitle ?? fallback.authorizedSignatoryTitle,
    );
  }
}
