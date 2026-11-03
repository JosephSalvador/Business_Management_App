import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/storage/offline_cache_dao.dart';

enum PaymentAccountType {
  bank,
  mobileMoney;

  String get label =>
      this == PaymentAccountType.bank ? 'Benki' : 'Simu / Lipa Namba';

  static PaymentAccountType fromString(String? value) {
    if (value == null) return PaymentAccountType.bank;
    final v = value.toLowerCase().trim();
    if (v.contains('mobile') ||
        v.contains('simu') ||
        v.contains('lipa') ||
        v.contains('mpesa') ||
        v.contains('m-pesa') ||
        v.contains('airtel') ||
        v.contains('tigo') ||
        v.contains('halo')) {
      return PaymentAccountType.mobileMoney;
    }
    return PaymentAccountType.bank;
  }
}

class PaymentAccount {
  const PaymentAccount({
    required this.id,
    required this.type,
    String? name,
    String? providerName,
    required this.accountNumber,
    this.accountName,
    this.branchOrSwift,
    this.currency,
    this.isDefault = false,
  }) : name = name ?? providerName ?? '';

  final String id;
  final PaymentAccountType type;
  final String name; // e.g. "CRDB Bank", "M-Pesa Lipa Namba"
  String get providerName => name;
  final String accountNumber; // e.g. "01528392019", "552233"
  final String? accountName; // e.g. "Acme Enterprises"
  final String? branchOrSwift; // e.g. "Kariakoo Branch / CORUTZTZ"
  final String? currency; // e.g. "TZS", "USD"
  final bool isDefault;

  bool get isBank => type == PaymentAccountType.bank;
  bool get isMobileMoney => type == PaymentAccountType.mobileMoney;

  String get formattedDisplay {
    final acctNameStr =
        (accountName != null && accountName!.trim().isNotEmpty)
            ? ' (${accountName!.trim()})'
            : '';
    final branchStr =
        (branchOrSwift != null && branchOrSwift!.trim().isNotEmpty)
            ? ' [${branchOrSwift!.trim()}]'
            : '';
    final currStr =
        (currency != null && currency!.trim().isNotEmpty)
            ? ' ($currency)'
            : '';
    final prefix = type == PaymentAccountType.bank ? 'Bank' : 'Mobile';
    return '$prefix: $name - $accountNumber$acctNameStr$currStr$branchStr';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type == PaymentAccountType.bank ? 'bank' : 'mobile_money',
        'name': name,
        'accountNumber': accountNumber,
        'accountName': accountName,
        'branchOrSwift': branchOrSwift,
        'currency': currency,
        'isDefault': isDefault,
      };

  factory PaymentAccount.fromJson(Map<String, dynamic> json) => PaymentAccount(
        id: (json['id'] as String?) ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        type: PaymentAccountType.fromString(json['type'] as String?),
        name: (json['name'] as String?) ?? '',
        accountNumber: (json['accountNumber'] as String?) ?? '',
        accountName: json['accountName'] as String?,
        branchOrSwift: json['branchOrSwift'] as String?,
        currency: json['currency'] as String?,
        isDefault: json['isDefault'] as bool? ?? false,
      );

  PaymentAccount copyWith({
    String? id,
    PaymentAccountType? type,
    String? name,
    String? accountNumber,
    String? accountName,
    String? branchOrSwift,
    String? currency,
    bool? isDefault,
  }) =>
      PaymentAccount(
        id: id ?? this.id,
        type: type ?? this.type,
        name: name ?? this.name,
        accountNumber: accountNumber ?? this.accountNumber,
        accountName: accountName ?? this.accountName,
        branchOrSwift: branchOrSwift ?? this.branchOrSwift,
        currency: currency ?? this.currency,
        isDefault: isDefault ?? this.isDefault,
      );
}

class Organization {
  const Organization({
    this.name,
    this.address,
    this.phone,
    this.email,
    this.website,
    this.taxId,
    this.countryCode,
    this.currency,
    this.logoBase64,
    this.signatureBase64,
    this.letterheadHeaderBase64,
    this.prePrintedTopMarginMm,
    this.hideHeaderForPrePrinted = false,
    this.bankName,
    this.bankAccountName,
    this.bankAccountNumber,
    this.bankBranchOrSwift,
    this.mobileMoneyDetails,
    this.invoiceTerms,
    this.authorizedSignatoryName,
    this.authorizedSignatoryTitle,
    this.paymentAccounts = const [],
  });

  final String? name;
  final String? address;
  final String? phone;
  final String? email;
  final String? website;
  final String? taxId;
  final String? countryCode;
  final String? currency;
  final String? logoBase64;
  final String? signatureBase64;
  final String? letterheadHeaderBase64;
  final double? prePrintedTopMarginMm;
  final bool hideHeaderForPrePrinted;
  final String? bankName;
  final String? bankAccountName;
  final String? bankAccountNumber;
  final String? bankBranchOrSwift;
  final String? mobileMoneyDetails;
  final String? invoiceTerms;
  final String? authorizedSignatoryName;
  final String? authorizedSignatoryTitle;
  final List<PaymentAccount> paymentAccounts;

  bool get hasLogo => logoBase64 != null && logoBase64!.trim().isNotEmpty;
  bool get hasSignature =>
      signatureBase64 != null && signatureBase64!.trim().isNotEmpty;
  bool get hasLetterheadHeader =>
      letterheadHeaderBase64 != null &&
      letterheadHeaderBase64!.trim().isNotEmpty;

  String get formattedPaymentInstructions {
    if (paymentAccounts.isNotEmpty) {
      final lines = <String>[];
      for (final acc in paymentAccounts) {
        lines.add(acc.formattedDisplay);
      }
      return lines.join('\n');
    }

    final lines = <String>[];
    if (bankName != null && bankName!.trim().isNotEmpty) {
      final acctName =
          (bankAccountName != null && bankAccountName!.trim().isNotEmpty)
              ? ' (${bankAccountName!.trim()})'
              : '';
      final acctNo =
          (bankAccountNumber != null && bankAccountNumber!.trim().isNotEmpty)
              ? ' - A/C: ${bankAccountNumber!.trim()}'
              : '';
      final swift =
          (bankBranchOrSwift != null && bankBranchOrSwift!.trim().isNotEmpty)
              ? ' [${bankBranchOrSwift!.trim()}]'
              : '';
      lines.add('Bank: ${bankName!.trim()}$acctNo$acctName$swift');
    }
    if (mobileMoneyDetails != null && mobileMoneyDetails!.trim().isNotEmpty) {
      lines.add('Mobile Money: ${mobileMoneyDetails!.trim()}');
    }
    return lines.join('\n');
  }

  Map<String, dynamic> toJson() {
    final bankAcc = paymentAccounts.where((a) => a.type == PaymentAccountType.bank).firstOrNull;
    final mobAcc = paymentAccounts.where((a) => a.type == PaymentAccountType.mobileMoney).firstOrNull;

    return {
      'name': name,
      'address': address,
      'phone': phone,
      'contactPhone': phone,
      'email': email,
      'contactEmail': email,
      'website': website,
      'taxId': taxId,
      'countryCode': countryCode,
      'currency': currency,
      'logoBase64': logoBase64,
      'signatureBase64': signatureBase64,
      'letterheadHeaderBase64': letterheadHeaderBase64,
      'prePrintedTopMarginMm': prePrintedTopMarginMm,
      'hideHeaderForPrePrinted': hideHeaderForPrePrinted,
      'bankName': bankName ?? bankAcc?.name,
      'bankAccountName': bankAccountName ?? bankAcc?.accountName,
      'bankAccountNumber': bankAccountNumber ?? bankAcc?.accountNumber,
      'bankBranchOrSwift': bankBranchOrSwift ?? bankAcc?.branchOrSwift,
      'mobileMoneyDetails': mobileMoneyDetails ??
          (mobAcc != null ? '${mobAcc.name}: ${mobAcc.accountNumber}' : null),
      'invoiceTerms': invoiceTerms,
      'authorizedSignatoryName': authorizedSignatoryName,
      'authorizedSignatoryTitle': authorizedSignatoryTitle,
      'paymentAccounts': paymentAccounts.map((a) => a.toJson()).toList(),
      'paymentAccountsJson': jsonEncode(paymentAccounts.map((a) => a.toJson()).toList()),
    };
  }

  factory Organization.fromJson(Map<String, dynamic> json) {
    var accounts = <PaymentAccount>[];
    if (json['paymentAccounts'] is List) {
      accounts = (json['paymentAccounts'] as List)
          .whereType<Map<dynamic, dynamic>>()
          .map((item) =>
              PaymentAccount.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } else if (json['paymentAccountsJson'] is String &&
        (json['paymentAccountsJson'] as String).trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(json['paymentAccountsJson'] as String);
        if (decoded is List) {
          accounts = decoded
              .whereType<Map<dynamic, dynamic>>()
              .map((item) =>
                  PaymentAccount.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
      } catch (_) {}
    }

    final bankName = json['bankName'] as String?;
    final bankAccountName = json['bankAccountName'] as String?;
    final bankAccountNumber = json['bankAccountNumber'] as String?;
    final bankBranchOrSwift = json['bankBranchOrSwift'] as String?;
    final mobileMoneyDetails = json['mobileMoneyDetails'] as String?;

    // Auto-synthesize payment accounts from legacy fields if accounts list is empty
    if (accounts.isEmpty) {
      if ((bankName != null && bankName.trim().isNotEmpty) ||
          (bankAccountNumber != null && bankAccountNumber.trim().isNotEmpty)) {
        accounts.add(PaymentAccount(
          id: 'legacy_bank_1',
          type: PaymentAccountType.bank,
          name: (bankName != null && bankName.trim().isNotEmpty)
              ? bankName.trim()
              : 'Bank Account',
          accountNumber: bankAccountNumber?.trim() ?? '',
          accountName: bankAccountName?.trim(),
          branchOrSwift: bankBranchOrSwift?.trim(),
          isDefault: true,
        ));
      }
      if (mobileMoneyDetails != null &&
          mobileMoneyDetails.trim().isNotEmpty) {
        accounts.add(PaymentAccount(
          id: 'legacy_mobile_1',
          type: PaymentAccountType.mobileMoney,
          name: 'Mobile Money',
          accountNumber: mobileMoneyDetails.trim(),
          isDefault: accounts.isEmpty,
        ));
      }
    }

    return Organization(
      name: json['name'] as String?,
      address: json['address'] as String?,
      phone: (json['phone'] as String?) ?? (json['contactPhone'] as String?),
      email: (json['email'] as String?) ?? (json['contactEmail'] as String?),
      website: json['website'] as String?,
      taxId: json['taxId'] as String?,
      countryCode: json['countryCode'] as String?,
      currency: json['currency'] as String?,
      logoBase64: json['logoBase64'] as String?,
      signatureBase64: json['signatureBase64'] as String?,
      letterheadHeaderBase64: json['letterheadHeaderBase64'] as String?,
      prePrintedTopMarginMm:
          (json['prePrintedTopMarginMm'] as num?)?.toDouble(),
      hideHeaderForPrePrinted:
          json['hideHeaderForPrePrinted'] as bool? ?? false,
      bankName: bankName,
      bankAccountName: bankAccountName,
      bankAccountNumber: bankAccountNumber,
      bankBranchOrSwift: bankBranchOrSwift,
      mobileMoneyDetails: mobileMoneyDetails,
      invoiceTerms: json['invoiceTerms'] as String?,
      authorizedSignatoryName: json['authorizedSignatoryName'] as String?,
      authorizedSignatoryTitle: json['authorizedSignatoryTitle'] as String?,
      paymentAccounts: accounts,
    );
  }

  Organization copyWith({
    String? name,
    String? address,
    String? phone,
    String? email,
    String? website,
    String? taxId,
    String? countryCode,
    String? currency,
    String? logoBase64,
    String? signatureBase64,
    String? letterheadHeaderBase64,
    double? prePrintedTopMarginMm,
    bool? hideHeaderForPrePrinted,
    String? bankName,
    String? bankAccountName,
    String? bankAccountNumber,
    String? bankBranchOrSwift,
    String? mobileMoneyDetails,
    String? invoiceTerms,
    String? authorizedSignatoryName,
    String? authorizedSignatoryTitle,
    List<PaymentAccount>? paymentAccounts,
  }) =>
      Organization(
        name: name ?? this.name,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        website: website ?? this.website,
        taxId: taxId ?? this.taxId,
        countryCode: countryCode ?? this.countryCode,
        currency: currency ?? this.currency,
        logoBase64: logoBase64 ?? this.logoBase64,
        signatureBase64: signatureBase64 ?? this.signatureBase64,
        letterheadHeaderBase64:
            letterheadHeaderBase64 ?? this.letterheadHeaderBase64,
        prePrintedTopMarginMm:
            prePrintedTopMarginMm ?? this.prePrintedTopMarginMm,
        hideHeaderForPrePrinted:
            hideHeaderForPrePrinted ?? this.hideHeaderForPrePrinted,
        bankName: bankName ?? this.bankName,
        bankAccountName: bankAccountName ?? this.bankAccountName,
        bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
        bankBranchOrSwift: bankBranchOrSwift ?? this.bankBranchOrSwift,
        mobileMoneyDetails: mobileMoneyDetails ?? this.mobileMoneyDetails,
        invoiceTerms: invoiceTerms ?? this.invoiceTerms,
        authorizedSignatoryName:
            authorizedSignatoryName ?? this.authorizedSignatoryName,
        authorizedSignatoryTitle:
            authorizedSignatoryTitle ?? this.authorizedSignatoryTitle,
        paymentAccounts: paymentAccounts ?? this.paymentAccounts,
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
    Organization? cachedOrg;
    if (_cache != null) {
      final cached = await _cache.load(_cacheKey);
      if (cached != null) {
        cachedOrg = Organization.fromJson(cached);
      }
    }
    final current = cachedOrg ?? const Organization();
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
      website: body.containsKey('website')
          ? body['website'] as String?
          : current.website,
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
      signatureBase64: body.containsKey('signatureBase64')
          ? body['signatureBase64'] as String?
          : current.signatureBase64,
      letterheadHeaderBase64: body.containsKey('letterheadHeaderBase64')
          ? body['letterheadHeaderBase64'] as String?
          : current.letterheadHeaderBase64,
      prePrintedTopMarginMm: body.containsKey('prePrintedTopMarginMm')
          ? (body['prePrintedTopMarginMm'] as num?)?.toDouble()
          : current.prePrintedTopMarginMm,
      hideHeaderForPrePrinted: body.containsKey('hideHeaderForPrePrinted')
          ? (body['hideHeaderForPrePrinted'] as bool? ?? false)
          : current.hideHeaderForPrePrinted,
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
      paymentAccounts: body.containsKey('paymentAccounts') &&
              body['paymentAccounts'] is List
          ? (body['paymentAccounts'] as List)
              .whereType<Map<dynamic, dynamic>>()
              .map((item) =>
                  PaymentAccount.fromJson(Map<String, dynamic>.from(item)))
              .toList()
          : current.paymentAccounts,
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
        'website': optimistic.website,
        'taxId': optimistic.taxId,
        'countryCode': optimistic.countryCode ?? 'TZ',
        'currency': optimistic.currency ?? 'TZS',
        'logoBase64': optimistic.logoBase64,
        'signatureBase64': optimistic.signatureBase64,
        'letterheadHeaderBase64': optimistic.letterheadHeaderBase64,
        'prePrintedTopMarginMm': optimistic.prePrintedTopMarginMm,
        'hideHeaderForPrePrinted': optimistic.hideHeaderForPrePrinted,
        'bankName': optimistic.bankName,
        'bankAccountName': optimistic.bankAccountName,
        'bankAccountNumber': optimistic.bankAccountNumber,
        'bankBranchOrSwift': optimistic.bankBranchOrSwift,
        'mobileMoneyDetails': optimistic.mobileMoneyDetails,
        'invoiceTerms': optimistic.invoiceTerms,
        'authorizedSignatoryName': optimistic.authorizedSignatoryName,
        'authorizedSignatoryTitle': optimistic.authorizedSignatoryTitle,
        'paymentAccountsJson': jsonEncode(
            optimistic.paymentAccounts.map((a) => a.toJson()).toList()),
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
      website: primary.website ?? fallback.website,
      taxId: primary.taxId ?? fallback.taxId,
      countryCode: primary.countryCode ?? fallback.countryCode,
      currency: primary.currency ?? fallback.currency,
      logoBase64: primary.logoBase64 ?? fallback.logoBase64,
      signatureBase64: primary.signatureBase64 ?? fallback.signatureBase64,
      letterheadHeaderBase64:
          primary.letterheadHeaderBase64 ?? fallback.letterheadHeaderBase64,
      prePrintedTopMarginMm:
          primary.prePrintedTopMarginMm ?? fallback.prePrintedTopMarginMm,
      hideHeaderForPrePrinted:
          primary.hideHeaderForPrePrinted || fallback.hideHeaderForPrePrinted,
      bankName: primary.bankName ?? fallback.bankName,
      bankAccountName: primary.bankAccountName ?? fallback.bankAccountName,
      bankAccountNumber:
          primary.bankAccountNumber ?? fallback.bankAccountNumber,
      bankBranchOrSwift:
          primary.bankBranchOrSwift ?? fallback.bankBranchOrSwift,
      mobileMoneyDetails:
          primary.mobileMoneyDetails ?? fallback.mobileMoneyDetails,
      invoiceTerms: primary.invoiceTerms ?? fallback.invoiceTerms,
      authorizedSignatoryName:
          primary.authorizedSignatoryName ?? fallback.authorizedSignatoryName,
      authorizedSignatoryTitle:
          primary.authorizedSignatoryTitle ?? fallback.authorizedSignatoryTitle,
      paymentAccounts: primary.paymentAccounts.isNotEmpty
          ? primary.paymentAccounts
          : fallback.paymentAccounts,
    );
  }
}
