import '../../../core/network/api_client.dart';
import '../../../core/network/api_routes.dart';
import '../../../core/network/app_exception.dart';
import '../domain/invoice.dart';

class InvoiceRepository {
  InvoiceRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<InvoicePage> list({
    int page = 1,
    int pageSize = 20,
    InvoiceStatus? status,
    String? search,
  }) async {
    final response = await _apiClient.get<dynamic>(
      ApiRoutes.v1('/invoices'),
      query: <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
        if (status != null) 'status': status.code,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Jibu la mfumo halijui muundo sahihi.');
    }
    final doc = Map<String, dynamic>.from(response.data as Map);
    final rawItems = doc['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map<dynamic, dynamic>>()
            .map((raw) =>
                CustomerInvoiceSummary.fromJson(Map<String, dynamic>.from(raw)))
            .toList(growable: false)
        : <CustomerInvoiceSummary>[];
    return InvoicePage(
      items: items,
      total: (doc['total'] as num?)?.toInt() ?? items.length,
      page: (doc['page'] as num?)?.toInt() ?? page,
    );
  }

  Future<CustomerInvoice> getById(String id) async {
    final response =
        await _apiClient.get<dynamic>(ApiRoutes.v1('/invoices/$id'));
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Ankara hazipatikani.');
    }
    return CustomerInvoice.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<CustomerInvoice> create({
    required List<InvoiceDraftLine> lines,
    String? customerId,
    String currency = 'TZS',
    DateTime? dueDate,
    String? notes,
  }) async {
    final response = await _apiClient.post<dynamic>(
      ApiRoutes.v1('/invoices'),
      body: <String, dynamic>{
        'lines': [for (final line in lines) line.toJson()],
        if (customerId != null && customerId.isNotEmpty)
          'customerId': customerId,
        'currency': currency,
        if (dueDate != null) 'dueDate': dueDate.toIso8601String(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Ankara haikuweza kuhifadhiwa.');
    }
    return CustomerInvoice.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<CustomerInvoice> recordPayment(
    String id, {
    required double amount,
    String? method,
    String? reference,
  }) async {
    final response = await _apiClient.post<dynamic>(
      ApiRoutes.v1('/invoices/$id/payments'),
      body: <String, dynamic>{
        'amount': amount,
        if (method != null && method.isNotEmpty) 'method': method,
        if (reference != null && reference.isNotEmpty) 'reference': reference,
      },
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Malipo hayakuweza kurekodiwa.');
    }
    return CustomerInvoice.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<CustomerInvoice> voidInvoice(String id) async {
    final response = await _apiClient.post<dynamic>(
      ApiRoutes.v1('/invoices/$id/void'),
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw ServerException('Ankara haikuweza kufutwa.');
    }
    return CustomerInvoice.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}
