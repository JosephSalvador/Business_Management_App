enum SubscriptionStatus {
  trial(0),
  active(1),
  debt(2);

  const SubscriptionStatus(this.code);

  final int code;

  static SubscriptionStatus fromCode(Object? value) {
    final code = _requiredInt(value, 'status');
    return values.firstWhere(
      (status) => status.code == code,
      orElse: () => throw FormatException('Unknown subscription status: $code'),
    );
  }
}

enum BillingAccessLevel {
  full(0),
  posAndInventory(1);

  const BillingAccessLevel(this.code);

  final int code;

  static BillingAccessLevel fromCode(Object? value) {
    final code = _requiredInt(value, 'accessLevel');
    return values.firstWhere(
      (level) => level.code == code,
      orElse: () =>
          throw FormatException('Unknown billing access level: $code'),
    );
  }
}

enum BillingInvoiceStatus {
  open(0),
  paid(1),
  cancelled(2);

  const BillingInvoiceStatus(this.code);

  final int code;

  static BillingInvoiceStatus fromCode(Object? value) {
    final code = _requiredInt(value, 'status');
    return values.firstWhere(
      (status) => status.code == code,
      orElse: () => throw FormatException('Unknown invoice status: $code'),
    );
  }
}

abstract final class BillingFeatureKeys {
  static const pos = 'pos.enabled';
  static const inventory = 'inventory.enabled';
  static const purchasing = 'purchasing.enabled';
  static const accounting = 'accounting.enabled';
  static const finance = 'finance.enabled';
  static const crm = 'crm.enabled';
  static const credit = 'credit.enabled';
  static const reports = 'reports.enabled';
  static const multiBranch = 'multi-branch.enabled';
  static const pricing = 'pricing.enabled';
  static const invoicing = 'invoicing.enabled';
}

class SubscriptionEntitlement {
  const SubscriptionEntitlement({
    required this.status,
    required this.accessLevel,
    required this.planCode,
    required this.effectiveFeatureKeys,
    required this.nextDueUtc,
    required this.hasOpenInvoice,
    required this.maxBranches,
    required this.maxUsers,
    required this.maxProducts,
    required this.evaluatedAtUtc,
    this.planFeatureKeys = const {},
    this.packages = const [],
    this.validOfflineUntil,
  });

  final SubscriptionStatus status;
  final BillingAccessLevel accessLevel;
  final String? planCode;
  final Set<String> effectiveFeatureKeys;

  final Set<String> planFeatureKeys;

  final List<String> packages;

  final DateTime? nextDueUtc;
  final bool hasOpenInvoice;
  final int? maxBranches;
  final int? maxUsers;
  final int? maxProducts;
  final DateTime evaluatedAtUtc;

  final DateTime? validOfflineUntil;

  bool get hasFullAccess => accessLevel == BillingAccessLevel.full;
  bool get isInDebt => status == SubscriptionStatus.debt;

  bool hasFeature(String key) => effectiveFeatureKeys.contains(key);

  bool isOfflineValid(DateTime now) {
    final until = validOfflineUntil;
    if (until == null) return false;
    return now.toUtc().isBefore(until.toUtc());
  }

  factory SubscriptionEntitlement.fromJson(Map<String, dynamic> json) {
    final rawKeys = _requiredList(json, 'effectiveFeatureKeys');
    if (rawKeys.any((value) => value is! String)) {
      throw const FormatException('Feature keys must be strings.');
    }
    final planKeys = json['planFeatureKeys'] is List
        ? (json['planFeatureKeys'] as List).whereType<String>()
        : const <String>[];
    final packages = json['packages'] is List
        ? (json['packages'] as List).whereType<String>().toList(growable: false)
        : const <String>[];
    return SubscriptionEntitlement(
      status: SubscriptionStatus.fromCode(json['status']),
      accessLevel: BillingAccessLevel.fromCode(json['accessLevel']),
      planCode: _optionalString(json, 'planCode'),
      effectiveFeatureKeys: Set.unmodifiable(rawKeys.cast<String>()),
      planFeatureKeys: Set.unmodifiable(planKeys),
      packages: packages,
      nextDueUtc: _optionalDateTime(json, 'nextDueUtc'),
      hasOpenInvoice: _requiredBool(json, 'hasOpenInvoice'),
      maxBranches: _optionalInt(json, 'maxBranches'),
      maxUsers: _optionalInt(json, 'maxUsers'),
      maxProducts: _optionalInt(json, 'maxProducts'),
      evaluatedAtUtc: _requiredDateTime(json, 'evaluatedAtUtc'),
      validOfflineUntil: _optionalDateTime(json, 'validOfflineUntil'),
    );
  }

  factory SubscriptionEntitlement.fromCapabilitiesJson(
    Map<String, dynamic> json,
  ) {
    final rawKeys = _requiredList(json, 'featureKeys');
    if (rawKeys.any((value) => value is! String)) {
      throw const FormatException('Feature keys must be strings.');
    }
    final planKeys = json['planFeatureKeys'] is List
        ? (json['planFeatureKeys'] as List).whereType<String>()
        : const <String>[];
    final packages = json['packages'] is List
        ? (json['packages'] as List).whereType<String>().toList(growable: false)
        : const <String>[];
    return SubscriptionEntitlement(
      status: SubscriptionStatus.fromCode(json['status']),
      accessLevel: BillingAccessLevel.fromCode(json['accessLevel']),
      planCode: _optionalString(json, 'planCode'),
      effectiveFeatureKeys: Set.unmodifiable(rawKeys.cast<String>()),
      planFeatureKeys: Set.unmodifiable(planKeys),
      packages: packages,
      nextDueUtc: _optionalDateTime(json, 'nextDueUtc'),
      hasOpenInvoice: _requiredBool(json, 'hasOpenInvoice'),
      maxBranches: _optionalInt(json, 'maxBranches'),
      maxUsers: _optionalInt(json, 'maxUsers'),
      maxProducts: _optionalInt(json, 'maxProducts'),
      evaluatedAtUtc: _requiredDateTime(json, 'evaluatedAtUtc'),
      validOfflineUntil: _optionalDateTime(json, 'validOfflineUntil'),
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status.code,
        'accessLevel': accessLevel.code,
        'planCode': planCode,
        'featureKeys': effectiveFeatureKeys.toList()..sort(),
        'planFeatureKeys': planFeatureKeys.toList()..sort(),
        'packages': packages,
        'nextDueUtc': nextDueUtc?.toIso8601String(),
        'hasOpenInvoice': hasOpenInvoice,
        'maxBranches': maxBranches,
        'maxUsers': maxUsers,
        'maxProducts': maxProducts,
        'evaluatedAtUtc': evaluatedAtUtc.toIso8601String(),
        'validOfflineUntil': validOfflineUntil?.toIso8601String(),
      };
}

class BillingPlan {
  const BillingPlan({
    required this.id,
    required this.code,
    required this.name,
    required this.monthlyPrice,
    required this.currency,
    required this.featureKeys,
    required this.maxBranches,
    required this.maxUsers,
    required this.maxProducts,
    this.isPackage = false,
  });

  final String id;
  final String code;
  final String name;
  final double monthlyPrice;
  final String currency;
  final Set<String> featureKeys;
  final int? maxBranches;
  final int? maxUsers;
  final int? maxProducts;
  final bool isPackage;

  factory BillingPlan.fromJson(Map<String, dynamic> json) {
    final rawKeys = _requiredList(json, 'featureKeys');
    if (rawKeys.any((value) => value is! String)) {
      throw const FormatException('Plan feature keys must be strings.');
    }
    return BillingPlan(
      id: _requiredString(json, 'id'),
      code: _requiredString(json, 'code'),
      name: _requiredString(json, 'name'),
      monthlyPrice: _requiredDouble(json, 'monthlyPrice'),
      currency: _requiredString(json, 'currency'),
      featureKeys: Set.unmodifiable(rawKeys.cast<String>()),
      maxBranches: _optionalInt(json, 'maxBranches'),
      maxUsers: _optionalInt(json, 'maxUsers'),
      maxProducts: _optionalInt(json, 'maxProducts'),
      isPackage: json['isPackage'] == true,
    );
  }
}

class BillingInvoice {
  const BillingInvoice({
    required this.id,
    required this.number,
    required this.description,
    required this.amount,
    required this.currency,
    required this.subscriptionId,
    required this.periodStartUtc,
    required this.periodEndUtc,
    required this.issuedAtUtc,
    required this.status,
    required this.reference,
    required this.confirmedByUserId,
    required this.paidAtUtc,
  });

  final String id;
  final String number;
  final String description;
  final double amount;
  final String currency;
  final String subscriptionId;
  final DateTime periodStartUtc;
  final DateTime periodEndUtc;
  final DateTime issuedAtUtc;
  final BillingInvoiceStatus status;
  final String? reference;
  final String? confirmedByUserId;
  final DateTime? paidAtUtc;

  factory BillingInvoice.fromJson(Map<String, dynamic> json) {
    return BillingInvoice(
      id: _requiredString(json, 'id'),
      number: _requiredString(json, 'number'),
      description: _requiredString(json, 'description'),
      amount: _requiredDouble(json, 'amount'),
      currency: _requiredString(json, 'currency'),
      subscriptionId: _requiredString(json, 'subscriptionId'),
      periodStartUtc: _requiredDateTime(json, 'periodStartUtc'),
      periodEndUtc: _requiredDateTime(json, 'periodEndUtc'),
      issuedAtUtc: _requiredDateTime(json, 'issuedAtUtc'),
      status: BillingInvoiceStatus.fromCode(json['status']),
      reference: _optionalString(json, 'reference'),
      confirmedByUserId: _optionalString(json, 'confirmedByUserId'),
      paidAtUtc: _optionalDateTime(json, 'paidAtUtc'),
    );
  }
}

abstract final class VoucherCode {
  static String normalize(String value) => value.trim().toUpperCase();

  static bool isValidFormat(String value) {
    final clean = normalize(value);
    return clean.length >= 6;
  }
}

int _requiredInt(Object? value, String field) {
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  throw FormatException('$field must be an integer.');
}

String _requiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('$field must be a non-empty string.');
}

String? _optionalString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null || value is String) return value as String?;
  throw FormatException('$field must be a string.');
}

double _requiredDouble(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is num && value.isFinite) return value.toDouble();
  throw FormatException('$field must be a number.');
}

int? _optionalInt(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null) return null;
  return _requiredInt(value, field);
}

bool _requiredBool(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is bool) return value;
  throw FormatException('$field must be a boolean.');
}

List<dynamic> _requiredList(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is List<dynamic>) return value;
  throw FormatException('$field must be a list.');
}

DateTime _requiredDateTime(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! String) throw FormatException('$field must be a date.');
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('$field must be a date.');
  return parsed.toUtc();
}

DateTime? _optionalDateTime(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null) return null;
  return _requiredDateTime(json, field);
}

class PaymentInstructions {
  const PaymentInstructions({
    required this.mpesaTill,
    required this.airtelMoney,
    required this.bankName,
    required this.bankAccountNumber,
    required this.bankAccountName,
    required this.whatsAppContact,
    required this.notes,
  });

  final String mpesaTill;
  final String airtelMoney;
  final String bankName;
  final String bankAccountNumber;
  final String bankAccountName;
  final String whatsAppContact;
  final String notes;

  factory PaymentInstructions.fromJson(Map<String, dynamic> json) =>
      PaymentInstructions(
        mpesaTill: json['mpesaTill'] as String? ?? '',
        airtelMoney: json['airtelMoney'] as String? ?? '',
        bankName: json['bankName'] as String? ?? '',
        bankAccountNumber: json['bankAccountNumber'] as String? ?? '',
        bankAccountName: json['bankAccountName'] as String? ?? '',
        whatsAppContact: json['whatsAppContact'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
      );
}
