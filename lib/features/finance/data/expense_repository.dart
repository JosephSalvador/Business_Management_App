import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';

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
  ExpenseRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

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
    return PagedExpenses(
      items: items,
      total: (doc['total'] as num?)?.toInt() ?? items.length,
    );
  }

  Future<Map<String, dynamic>> getById(String id) async {
    final response = await _apiClient.get<dynamic>('/api/v1/expenses/$id');
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final response = await _apiClient.post<dynamic>(
      '/api/v1/expenses',
      body: body,
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return Map<String, dynamic>.from(response.data as Map);
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
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> delete(String id) async {
    final response = await _apiClient.delete<dynamic>('/api/v1/expenses/$id');
    if (response.statusCode != 200) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
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
    final response = await _apiClient.get<dynamic>(
      '/api/v1/expenses/summary',
      query: query,
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    return ExpenseSummary.fromJson(
        Map<String, dynamic>.from(response.data as Map));
  }
}
