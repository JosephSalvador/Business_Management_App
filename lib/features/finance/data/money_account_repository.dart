import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/storage/offline_cache_dao.dart';
import '../../../core/storage/sync_queue_dao.dart';

class MoneyAccountRepository {
  MoneyAccountRepository({
    required ApiClient apiClient,
    OfflineCacheDao? cache,
    SyncQueueDao? queue,
    Future<String?> Function()? tenantIdOf,
    Future<String?> Function()? branchIdOf,
    Future<String> Function()? deviceIdOf,
    Uuid uuid = const Uuid(),
  })  : _apiClient = apiClient,
        _cache = cache,
        _queue = queue,
        _tenantIdOf = tenantIdOf,
        _branchIdOf = branchIdOf,
        _deviceIdOf = deviceIdOf,
        _uuid = uuid;

  final ApiClient _apiClient;
  final OfflineCacheDao? _cache;
  final SyncQueueDao? _queue;
  final Future<String?> Function()? _tenantIdOf;
  final Future<String?> Function()? _branchIdOf;
  final Future<String> Function()? _deviceIdOf;
  final Uuid _uuid;

  static const _accountsCacheKey = 'money_accounts_list';

  Future<List<Map<String, dynamic>>> listAccounts() async {
    try {
      final response = await _apiClient.get<dynamic>('/api/v1/money-accounts');
      if (response.statusCode != 200 || response.data is! List) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      final list = (response.data as List)
          .whereType<Map<dynamic, dynamic>>()
          .map((raw) => Map<String, dynamic>.from(raw))
          .toList();
      if (_cache != null) {
        await _cache!.save(_accountsCacheKey, {'items': list});
      }
      return list;
    } on AppException {
      if (_cache != null) {
        final cached = await _cache!.load(_accountsCacheKey);
        if (cached != null) {
          return (cached['items'] as List<dynamic>? ?? const [])
              .whereType<Map<dynamic, dynamic>>()
              .map((raw) => Map<String, dynamic>.from(raw))
              .toList();
        }
      }
      // Return default cash drawer fallback account when offline
      return [
        {
          'id': 'local-cash-drawer',
          'name': 'Droo ya Pesa (Cash Drawer)',
          'type': 0, // Cash
          'balance': 0.0,
          'currency': 'TZS',
          'isDefault': true,
        }
      ];
    }
  }

  Future<Map<String, dynamic>> getAccount(String id) async {
    try {
      final response =
          await _apiClient.get<dynamic>('/api/v1/money-accounts/$id');
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      return Map<String, dynamic>.from(response.data as Map);
    } on AppException {
      final accounts = await listAccounts();
      final found = accounts.where((a) => a['id'] == id);
      if (found.isNotEmpty) return found.first;
      rethrow;
    }
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
    try {
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
    } on AppException {
      return const [];
    }
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
    try {
      final response = await _apiClient.get<dynamic>(
        '/api/v1/cash-sessions/current',
        query: {'accountId': accountId},
      );
      if (response.statusCode == 404) return null;
      if (response.data == null) return null;
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      final session = Map<String, dynamic>.from(response.data as Map);
      if (_cache != null) {
        await _cache!.save('cash_session_$accountId', session);
      }
      return session;
    } on AppException {
      if (_cache != null) {
        final cached = await _cache!.load('cash_session_$accountId');
        if (cached != null) return cached;
      }
      return null;
    }
  }

  Future<Map<String, dynamic>> openSession(
    Map<String, dynamic> body, {
    bool remoteOnly = false,
  }) async {
    try {
      final response = await _apiClient.post<dynamic>(
        '/api/v1/cash-sessions',
        body: body,
      );
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      final session = Map<String, dynamic>.from(response.data as Map);
      if (_cache != null) {
        await _cache!.save('cash_session_${body['accountId']}', session);
      }
      return session;
    } on AppException {
      if (remoteOnly) rethrow;
      // Offline cash session open
      final sessionId = _uuid.v4();
      final accountId = body['accountId']?.toString() ?? 'default';
      final openingCash = (body['openingCash'] as num?)?.toDouble() ?? 0.0;
      final localSession = {
        'id': sessionId,
        'accountId': accountId,
        'openingCash': openingCash,
        'status': 0, // open
        'openedAt': DateTime.now().toUtc().toIso8601String(),
        'isOfflinePending': true,
      };

      if (_cache != null) {
        await _cache!.save('cash_session_$accountId', localSession);
      }

      if (_queue != null) {
        final tenantId = _tenantIdOf != null
            ? (await _tenantIdOf!()) ?? 'unknown'
            : 'unknown';
        final branchId =
            _branchIdOf != null ? (await _branchIdOf!()) ?? tenantId : tenantId;
        final deviceId = _deviceIdOf != null ? await _deviceIdOf!() : '';

        await _queue!.enqueue(
          operationId: sessionId,
          tenantId: tenantId,
          branchId: branchId,
          deviceId: deviceId,
          operationType: 'cash_session.open',
          aggregateType: 'cash_session',
          aggregateId: sessionId,
          payload: jsonEncode(body),
        );
      }

      return localSession;
    }
  }

  Future<Map<String, dynamic>> closeSession(
    String sessionId,
    Map<String, dynamic> body, {
    bool remoteOnly = false,
  }) async {
    try {
      final response = await _apiClient.post<dynamic>(
        '/api/v1/cash-sessions/$sessionId/close',
        body: body,
      );
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      final session = Map<String, dynamic>.from(response.data as Map);
      if (_cache != null) {
        final accountId = session['accountId']?.toString();
        if (accountId != null) {
          await _cache!.clear('cash_session_$accountId');
        }
      }
      return session;
    } on AppException {
      if (remoteOnly) rethrow;
      // Offline cash session close
      final closingCash = (body['closingCash'] as num?)?.toDouble() ?? 0.0;
      final expectedCash = (body['expectedCash'] as num?)?.toDouble();
      final variance =
          expectedCash != null ? (closingCash - expectedCash) : 0.0;
      final closedSession = {
        'id': sessionId,
        'closingCash': closingCash,
        if (expectedCash != null) 'expectedCash': expectedCash,
        'variance': variance,
        'notes': body['notes'],
        'status': 1, // closed
        'closedAt': DateTime.now().toUtc().toIso8601String(),
        'isOfflinePending': true,
      };

      if (_cache != null) {
        final accountId = body['accountId']?.toString();
        if (accountId != null) {
          await _cache!.clear('cash_session_$accountId');
        }
        await _cache!.save('cash_session_closed_$sessionId', closedSession);
      }

      if (_queue != null) {
        final tenantId = _tenantIdOf != null
            ? (await _tenantIdOf!()) ?? 'unknown'
            : 'unknown';
        final branchId =
            _branchIdOf != null ? (await _branchIdOf!()) ?? tenantId : tenantId;
        final deviceId = _deviceIdOf != null ? await _deviceIdOf!() : '';

        await _queue!.enqueue(
          operationId: _uuid.v4(),
          tenantId: tenantId,
          branchId: branchId,
          deviceId: deviceId,
          operationType: 'cash_session.close',
          aggregateType: 'cash_session',
          aggregateId: sessionId,
          payload: jsonEncode({'sessionId': sessionId, ...body}),
        );
      }

      return closedSession;
    }
  }
}
