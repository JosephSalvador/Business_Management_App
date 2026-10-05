import '../../../core/network/api_client.dart';
import '../../../core/network/api_routes.dart';
import '../../../core/network/app_exception.dart';
import '../domain/billing.dart';

class BillingRepository {
  const BillingRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<SubscriptionEntitlement> getSubscription() async {
    final response = await _apiClient.get<dynamic>(
      ApiRoutes.v1('/billing/subscription'),
    );
    return _parse(
      response,
      SubscriptionEntitlement.fromJson,
      'Jibu la mfumo halijui muundo sahihi.',
    );
  }

  Future<SubscriptionEntitlement> evaluateSubscription() async {
    final response = await _apiClient.post<dynamic>(
      ApiRoutes.v1('/billing/subscription/evaluate'),
    );
    return _parse(
      response,
      SubscriptionEntitlement.fromJson,
      'Jibu la mfumo halijui muundo sahihi.',
    );
  }

  Future<List<BillingPlan>> listPlans() async {
    final response = await _apiClient.get<dynamic>(
      ApiRoutes.v1('/billing/plans'),
    );
    if (response.statusCode != 200) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    if (response.data is! List<dynamic>) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    try {
      return (response.data as List<dynamic>)
          .map((value) => BillingPlan.fromJson(_asMap(value)))
          .toList(growable: false);
    } on Object {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
  }

  Future<List<BillingInvoice>> listInvoices() async {
    final response = await _apiClient.get<dynamic>(
      ApiRoutes.v1('/billing/invoices'),
    );
    if (response.statusCode != 200 || response.data is! List<dynamic>) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    try {
      return (response.data as List<dynamic>)
          .map((value) => BillingInvoice.fromJson(_asMap(value)))
          .toList(growable: false);
    } on Object {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
  }

  Future<BillingInvoice> getInvoice(String invoiceId) async {
    final response = await _apiClient.get<dynamic>(
      ApiRoutes.v1('/billing/invoices/$invoiceId'),
    );
    return _parse(
      response,
      BillingInvoice.fromJson,
      'Risiti haipatikani.',
    );
  }

  Future<SubscriptionEntitlement> redeemVoucher(String code) async {
    final response = await _apiClient.post<dynamic>(
      ApiRoutes.v1('/billing/vouchers/redeem'),
      body: {'code': code},
    );
    return _parse(
      response,
      SubscriptionEntitlement.fromJson,
      'Jibu la mfumo halijui muundo sahihi.',
    );
  }

  Future<List<String>> activatePackage(String planCode) async {
    final response = await _apiClient.post<dynamic>(
      ApiRoutes.v1('/billing/packages/$planCode'),
    );
    return _packageCodes(response);
  }

  Future<List<String>> removePackage(String planCode) async {
    final response = await _apiClient.delete<dynamic>(
      ApiRoutes.v1('/billing/packages/$planCode'),
    );
    return _packageCodes(response);
  }

  List<String> _packageCodes(dynamic response) {
    if (response.statusCode != 200 || response.data is! List<dynamic>) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return (response.data as List<dynamic>)
        .whereType<String>()
        .toList(growable: false);
  }

  T _parse<T>(
    dynamic response,
    T Function(Map<String, dynamic>) decoder,
    String errorMessage,
  ) {
    if (response.statusCode != 200) {
      throw ServerException(errorMessage);
    }
    try {
      return decoder(_asMap(response.data));
    } on Object {
      throw ServerException(errorMessage);
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<dynamic, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    throw const FormatException('Expected an object.');
  }
}
