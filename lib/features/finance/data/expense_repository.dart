import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/storage/offline_cache_dao.dart';
import 'offline_expense_service.dart';

class PagedExpenses {
  const PagedExpenses({required this.items, required this.total});

  final List<Map<String, dynamic>> items;
  final int total;
}

class ExpenseCategory {
  const ExpenseCategory({required this.id, required this.name});

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) =>
      ExpenseCategory(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
      );

  final String id;
  final String name;
}

class ExpenseCategoryTotal {
  const ExpenseCategoryTotal({
    this.categoryId,
    this.categoryName,
    required this.total,
  });

  factory ExpenseCategoryTotal.fromJson(Map<String, dynamic> json) =>
      ExpenseCategoryTotal(
        categoryId: json['categoryId'] as String?,
        categoryName: json['categoryName'] as String?,
        total: (json['total'] as num?)?.toDouble() ?? 0,
      );

  final String? categoryId;
  final String? categoryName;
  final double total;
}

class ExpenseSummary {
  const ExpenseSummary({required this.total, required this.byCategory});

  factory ExpenseSummary.fromJson(Map<String, dynamic> json) => ExpenseSummary(
        total: (json['total'] as num?)?.toDouble() ?? 0,
        byCategory: (json['byCategory'] as List<dynamic>? ?? const [])
            .whereType<Map<dynamic, dynamic>>()
            .map((raw) =>
                ExpenseCategoryTotal.fromJson(Map<String, dynamic>.from(raw)))
            .toList(growable: false),
      );

  final double total;
  final List<ExpenseCategoryTotal> byCategory;

  bool get isEmpty => byCategory.isEmpty && total == 0;
}

class ExpenseRepository {
  ExpenseRepository({
    required ApiClient apiClient,
    OfflineCacheDao? cache,
    OfflineExpenseService? offlineService,
  })  : _apiClient = apiClient,
        _cache = cache,
        _offlineService = offlineService;

  final ApiClient _apiClient;
  final OfflineCacheDao? _cache;
  final OfflineExpenseService? _offlineService;

  static const _uuid = Uuid();
  static const _cacheKey = 'expenses_list';
  static const _summaryCacheKey = 'expenses_summary';

  Future<PagedExpenses> list({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? fromDate,
    String? toDate,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (fromDate != null) 'fromDate': fromDate,
      if (toDate != null) 'toDate': toDate,
    };

    try {
      final response = await _apiClient.get<dynamic>(
        '/api/v1/expenses',
        query: query,
      );
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      final doc = Map<String, dynamic>.from(response.data as Map);
      final items = (doc['items'] as List<dynamic>? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((raw) => Map<String, dynamic>.from(raw))
          .toList(growable: false);

      // Cache online page 1 for offline resilience
      if (_cache != null && page == 1 && search == null && fromDate == null) {
        await _cache.save(_cacheKey, {
          'items': items,
          'total': doc['total'] ?? items.length,
        });
      }

      return PagedExpenses(
        items: items,
        total: (doc['total'] as num?)?.toInt() ?? items.length,
      );
    } on AppException {
      // 100% Local-first offline fallback
      var items = <Map<String, dynamic>>[];
      if (_cache != null) {
        final cached = await _cache.load(_cacheKey);
        items = (cached?['items'] as List<dynamic>? ?? const [])
            .whereType<Map<dynamic, dynamic>>()
            .map((raw) => Map<String, dynamic>.from(raw))
            .toList();
      }

      if (_offlineService != null) {
        try {
          final pending = await _offlineService.listPendingExpenses();
          final existingIds = items.map((e) => e['id']?.toString()).toSet();
          for (final p in pending) {
            final id = p['id']?.toString();
            if (id != null && !existingIds.contains(id)) {
              items.insert(0, p);
              existingIds.add(id);
            }
          }
        } catch (_) {}
      }

      if (fromDate != null || toDate != null) {
        final fromDt = fromDate != null ? DateTime.tryParse(fromDate) : null;
        final toDt = toDate != null ? DateTime.tryParse(toDate) : null;
        items = items.where((e) {
          final dtStr = e['expenseDate'] ?? e['createdAt'];
          if (dtStr == null) return true;
          final dt = DateTime.tryParse(dtStr.toString());
          if (dt == null) return true;
          if (fromDt != null && dt.isBefore(fromDt)) return false;
          if (toDt != null && dt.isAfter(toDt)) return false;
          return true;
        }).toList();
      }

      if (search != null && search.trim().isNotEmpty) {
        final term = search.trim().toLowerCase();
        items = items.where((e) {
          final desc = (e['description'] ?? '').toString().toLowerCase();
          final ref = (e['reference'] ?? '').toString().toLowerCase();
          return desc.contains(term) || ref.contains(term);
        }).toList();
      }

      return PagedExpenses(
        items: items,
        total: items.length,
      );
    }
  }

  Future<Map<String, dynamic>> getById(String id) async {
    try {
      final response = await _apiClient.get<dynamic>('/api/v1/expenses/$id');
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      return Map<String, dynamic>.from(response.data as Map);
    } on AppException {
      if (_offlineService != null) {
        final pending = await _offlineService.listPendingExpenses();
        final localMatch = pending.where((e) => e['id'] == id).firstOrNull;
        if (localMatch != null) return localMatch;
      }
      if (_cache != null) {
        final listCached = await _cache.load(_cacheKey);
        if (listCached != null) {
          final items = (listCached['items'] as List<dynamic>? ?? const [])
              .whereType<Map<dynamic, dynamic>>()
              .map((raw) => Map<String, dynamic>.from(raw));
          final found = items.where((e) => e['id']?.toString() == id);
          if (found.isNotEmpty) return found.first;
        }
      }
      return {'id': id, 'description': 'Matumizi', 'amount': 0.0, 'pendingLocally': true};
    }
  }

  Future<Map<String, dynamic>> create(
    Map<String, dynamic> body, {
    bool remoteOnly = false,
    String? idempotencyKey,
  }) async {
    final expenseId = (body['id'] as String?) ?? idempotencyKey ?? _uuid.v4();
    final enrichedBody = Map<String, dynamic>.from(body);
    enrichedBody['id'] = expenseId;

    try {
      final response = await _apiClient.post<dynamic>(
        '/api/v1/expenses',
        body: enrichedBody,
        headers: {
          if (idempotencyKey != null || expenseId.isNotEmpty)
            'Idempotency-Key': idempotencyKey ?? expenseId,
        },
      );
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      final created = Map<String, dynamic>.from(response.data as Map);
      if (_cache != null) {
        await _appendExpenseToCache(created);
      }
      return created;
    } on AppException {
      if (remoteOnly) rethrow;
      if (_offlineService != null) {
        final offlineExpense = await _offlineService.recordOffline(enrichedBody);
        if (_cache != null) {
          await _appendExpenseToCache(offlineExpense);
        }
        return offlineExpense;
      }
      rethrow;
    }
  }

  Future<void> _appendExpenseToCache(Map<String, dynamic> expense) async {
    if (_cache == null) return;
    try {
      final listCached = await _cache.load(_cacheKey);
      final items = (listCached?['items'] as List<dynamic>? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((raw) => Map<String, dynamic>.from(raw))
          .toList();
      items.removeWhere((e) => e['id'] == expense['id']);
      items.insert(0, expense); // Latest first!
      await _cache.save(_cacheKey, {
        'items': items,
        'total': items.length,
      });
    } catch (_) {}
  }

  Future<Map<String, dynamic>> update(
      String id, Map<String, dynamic> body) async {
    final response = await _apiClient.put<dynamic>(
      '/api/v1/expenses/$id',
      body: body,
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    final updated = Map<String, dynamic>.from(response.data as Map);
    if (_cache != null) {
      await _appendExpenseToCache(updated);
    }
    return updated;
  }

  Future<void> delete(String id) async {
    final response = await _apiClient.delete<dynamic>('/api/v1/expenses/$id');
    if (response.statusCode != 200) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    if (_cache != null) {
      try {
        final listCached = await _cache.load(_cacheKey);
        final items = (listCached?['items'] as List<dynamic>? ?? const [])
            .whereType<Map<dynamic, dynamic>>()
            .map((raw) => Map<String, dynamic>.from(raw))
            .toList();
        items.removeWhere((e) => e['id'] == id);
        await _cache.save(_cacheKey, {
          'items': items,
          'total': items.length,
        });
      } catch (_) {}
    }
  }

  static const _defaultExpenseCategories = [
    ExpenseCategory(id: 'cat_general', name: 'Matumizi ya Jumla'),
    ExpenseCategory(id: 'cat_rent', name: 'Kodi ya Pango'),
    ExpenseCategory(id: 'cat_electricity', name: 'Umeme / Luku'),
    ExpenseCategory(id: 'cat_water', name: 'Maji'),
    ExpenseCategory(id: 'cat_transport', name: 'Usafiri / Nauli'),
    ExpenseCategory(id: 'cat_food', name: 'Chakula cha Wafanyakazi'),
    ExpenseCategory(id: 'cat_comm', name: 'Mawasiliano / Vocha'),
    ExpenseCategory(id: 'cat_repair', name: 'Ukarabati / Matengenezo'),
  ];

  Future<List<ExpenseCategory>> listCategories() async {
    try {
      final response =
          await _apiClient.get<dynamic>('/api/v1/expenses/categories');
      if (response.statusCode != 200 || response.data is! List) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      final list = (response.data as List)
          .whereType<Map<dynamic, dynamic>>()
          .map((raw) => ExpenseCategory.fromJson(Map<String, dynamic>.from(raw)))
          .toList(growable: false);
      if (_cache != null) {
        await _cache.save('expense_categories', {
          'items': list.map((c) => {'id': c.id, 'name': c.name}).toList(),
        });
      }
      return list;
    } on AppException {
      if (_cache != null) {
        final cached = await _cache.load('expense_categories');
        if (cached != null && cached['items'] is List) {
          final items = (cached['items'] as List)
              .whereType<Map<dynamic, dynamic>>()
              .map((raw) =>
                  ExpenseCategory.fromJson(Map<String, dynamic>.from(raw)))
              .toList(growable: false);
          if (items.isNotEmpty) return items;
        }
      }
      return _defaultExpenseCategories;
    }
  }

  Future<ExpenseCategory> createCategory(String name) async {
    try {
      final response = await _apiClient.post<dynamic>(
        '/api/v1/expenses/categories',
        body: {'name': name},
      );
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      final created = ExpenseCategory.fromJson(
          Map<String, dynamic>.from(response.data as Map));
      if (_cache != null) {
        try {
          final cached = await _cache.load('expense_categories');
          final items = (cached?['items'] as List<dynamic>? ?? const [])
              .whereType<Map<dynamic, dynamic>>()
              .map((r) => Map<String, dynamic>.from(r))
              .toList();
          items.add({'id': created.id, 'name': created.name});
          await _cache.save('expense_categories', {'items': items});
        } catch (_) {}
      }
      return created;
    } on AppException {
      final localCategory = ExpenseCategory(
        id: _uuid.v4(),
        name: name.trim(),
      );
      if (_cache != null) {
        try {
          final cached = await _cache.load('expense_categories');
          final items = (cached?['items'] as List<dynamic>? ?? const [])
              .whereType<Map<dynamic, dynamic>>()
              .map((r) => Map<String, dynamic>.from(r))
              .toList();
          items.add({'id': localCategory.id, 'name': localCategory.name});
          await _cache.save('expense_categories', {'items': items});
        } catch (_) {}
      }
      return localCategory;
    }
  }

  Future<ExpenseSummary> getSummary({String? fromDate, String? toDate}) async {
    final query = <String, dynamic>{
      if (fromDate != null) 'fromDate': fromDate,
      if (toDate != null) 'toDate': toDate,
    };
    try {
      final response = await _apiClient.get<dynamic>(
        '/api/v1/expenses/summary',
        query: query,
      );
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      final summary = ExpenseSummary.fromJson(
          Map<String, dynamic>.from(response.data as Map));
      if (_cache != null && fromDate == null && toDate == null) {
        await _cache.save(_summaryCacheKey, {
          'total': summary.total,
          'byCategory': summary.byCategory
              .map((c) => {
                    'categoryId': c.categoryId,
                    'categoryName': c.categoryName,
                    'total': c.total,
                  })
              .toList(),
        });
      }
      return summary;
    } on AppException {
      if (_cache != null) {
        final cached = await _cache.load(_summaryCacheKey);
        if (cached != null) {
          return ExpenseSummary.fromJson(cached);
        }
      }
      return const ExpenseSummary(total: 0, byCategory: []);
    }
  }
}
