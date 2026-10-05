import '../../../core/network/api_client.dart';
import '../../../core/network/api_routes.dart';
import '../../../core/network/app_exception.dart';
import '../../billing/domain/billing.dart';
import 'capabilities_dao.dart';

class CapabilitiesRepository {
  CapabilitiesRepository({
    required ApiClient apiClient,
    required CapabilitiesDao dao,
  })  : _apiClient = apiClient,
        _dao = dao;

  final ApiClient _apiClient;
  final CapabilitiesDao _dao;

  Future<SubscriptionEntitlement> fetch() async {
    final response =
        await _apiClient.get<dynamic>(ApiRoutes.v1('/capabilities'));
    if (response.statusCode != 200) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    final data = response.data;
    if (data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    try {
      return SubscriptionEntitlement.fromCapabilitiesJson(
        Map<String, dynamic>.from(data),
      );
    } on Object {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
  }

  Future<SubscriptionEntitlement> fetchAndCache(String tenantId) async {
    final entitlement = await fetch();
    await _dao.save(tenantId, entitlement);
    return entitlement;
  }

  Future<SubscriptionEntitlement?> loadCached(String tenantId) =>
      _dao.load(tenantId);

  Future<void> clearCache(String tenantId) => _dao.clear(tenantId);
}
