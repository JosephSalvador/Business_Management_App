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
        await _cache!.save(_cacheKey, {
          'items': items,
          'total': doc['total'] ?? items.length,
        });
      }

      return PagedExpenses(
        items: items,
        total: (doc['total'] as num?)?.toInt() ?? items.length,
      );
    } on AppException {
      // Offline fallback: load from local cache
      if (_cache != null) {
        final cached = await _cache!.load(_cacheKey);
        var items = (cached?['items'] as List<dynamic>? ?? const [])
            .whereType<Map<dynamic, dynamic>>()
            .map((raw) => Map<String, dynamic>.from(raw))
            .toList();

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
      rethrow;
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
      if (_cache != null) {
        final listCached = await _cache!.load(_cacheKey);
        if (listCached != null) {
          final items = (listCached['items'] as List<dynamic>? ?? const [])
              .whereType<Map<dynamic, dynamic>>()
              .map((raw) => Map<String, dynamic>.from(raw));
          final found = items.where((e) => e['id']?.toString() == id);
          if (found.isNotEmpty) return found.first;
        }
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    try {
      final response = await _apiClient.post<dynamic>(
        '/api/v1/expenses',
        body: body,
      );
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      final created = Map<String, dynamic>.from(response.data as Map);
      if (_cache != null) {
        await _appendExpenseToCache(created);
      }
      return created;
    } on AppException catch (e) {
      if (_offlineService != null &&
          (e is NetworkException ||
              e is TimeoutException ||
              e is ServerException)) {
        final offlineExpense = await _offlineService!.recordOffline(body);
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
      final listCached = await _cache!.load(_cacheKey);
      final items = (listCached?['items'] as List<dynamic>? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((raw) => Map<String, dynamic>.from(raw))
          .toList();
      items.removeWhere((e) => e['id'] == expense['id']);
      items.insert(0, expense); // Latest first!
      await _cache!.save(_cacheKey, {
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
        final listCached = await _cache!.load(_cacheKey);
        final items = (listCached?['items'] as List<dynamic>? ?? const [])
            .whereType<Map<dynamic, dynamic>>()
            .map((raw) => Map<String, dynamic>.from(raw))
            .toList();
        items.removeWhere((e) => e['id'] == id);
        await _cache!.save(_cacheKey, {
          'items': items,
          'total': items.length,
        });
      } catch (_) {}
    }
  }

  Future<List<ExpenseCategory>> listCategories() async {
    final response =
        await _apiClient.get<dynamic>('/api/v1/expenses/categories');
    if (response.statusCode != 200 || response.data is! List) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return (response.data as List)
        .whereType<Map<dynamic, dynamic>>()
        .map((raw) => ExpenseCategory.fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }

  Future<ExpenseCategory> createCategory(String name) async {
    final response = await _apiClient.post<dynamic>(
      '/api/v1/expenses/categories',
      body: {'name': name},
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return ExpenseCategory.fromJson(
        Map<String, dynamic>.from(response.data as Map));
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
        await _cache!.save(_summaryCacheKey, {
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
        final cached = await _cache!.load(_summaryCacheKey);
        if (cached != null) {
          return ExpenseSummary.fromJson(cached);
        }
      }
      return const ExpenseSummary(total: 0, byCategory: []);
    }
  }
}
