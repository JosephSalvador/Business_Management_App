import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';

class MoneyAccountRepository {
  MoneyAccountRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> listAccounts() async {
    final response = await _apiClient.get<dynamic>('/api/v1/money-accounts');
    if (response.statusCode != 200 || response.data is! List) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return (response.data as List)
        .whereType<Map<dynamic, dynamic>>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .toList();
  }

  Future<Map<String, dynamic>> getAccount(String id) async {
    final response =
        await _apiClient.get<dynamic>('/api/v1/money-accounts/$id');
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> createAccount(Map<String, dynamic> body) async {
    final response = await _apiClient.post<dynamic>(
      '/api/v1/money-accounts',
      body: body,
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<Map<String, dynamic>>> listTransactions(
    String accountId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiClient.get<dynamic>(
      '/api/v1/money-accounts/$accountId/transactions',
      query: {'page': page, 'pageSize': pageSize},
    );
    if (response.statusCode != 200 || response.data is! List) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return (response.data as List)
        .whereType<Map<dynamic, dynamic>>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .toList();
  }

  Future<Map<String, dynamic>> transfer(Map<String, dynamic> body) async {
    final response = await _apiClient.post<dynamic>(
      '/api/v1/money-accounts/transfer',
      body: body,
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> recordIncome(Map<String, dynamic> body) async {
    final response = await _apiClient.post<dynamic>(
      '/api/v1/money-accounts/income',
      body: body,
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> recordExpense(Map<String, dynamic> body) async {
    final response = await _apiClient.post<dynamic>(
      '/api/v1/money-accounts/expense',
      body: body,
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  // ── Cash Sessions ──────────────────────────────────────────────

  Future<Map<String, dynamic>?> getCurrentSession(String accountId) async {
    final response = await _apiClient.get<dynamic>(
      '/api/v1/cash-sessions/current',
      query: {'accountId': accountId},
    );
    if (response.statusCode == 404) return null;
    // Backend returns 200 with an EMPTY body when no session is open; treat that as "no session".
    if (response.data == null) return null;
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> openSession(Map<String, dynamic> body) async {
    final response = await _apiClient.post<dynamic>(
      '/api/v1/cash-sessions',
      body: body,
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> closeSession(
    String sessionId,
    Map<String, dynamic> body,
  ) async {
    final response = await _apiClient.post<dynamic>(
      '/api/v1/cash-sessions/$sessionId/close',
      body: body,
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }
}
