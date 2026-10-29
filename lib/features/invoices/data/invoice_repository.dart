import '../../../core/network/api_client.dart';
import '../../../core/network/api_routes.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/storage/offline_cache_dao.dart';
import '../domain/invoice.dart';

class InvoiceRepository {
  InvoiceRepository({
    required ApiClient apiClient,
    OfflineCacheDao? cache,
  })  : _apiClient = apiClient,
        _cache = cache;

  final ApiClient _apiClient;
  final OfflineCacheDao? _cache;

  Future<InvoicePage> list({
    int page = 1,
    int pageSize = 20,
    InvoiceStatus? status,
    String? search,
  }) async {
    try {
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
      final invoicePage = InvoicePage(
        items: items,
        total: (doc['total'] as num?)?.toInt() ?? items.length,
        page: (doc['page'] as num?)?.toInt() ?? page,
      );
      if (_cache != null && page == 1 && search == null && status == null) {
        await _cache.save('invoices_list', {
          'items': items.map((i) => i.toJson()).toList(),
          'total': invoicePage.total,
        });
      }
      return invoicePage;
    } on AppException {
      if (_cache != null) {
        final cached = await _cache.load('invoices_list');
        if (cached != null && cached['items'] is List) {
          final items = (cached['items'] as List)
              .whereType<Map<dynamic, dynamic>>()
              .map((raw) => CustomerInvoiceSummary.fromJson(
                  Map<String, dynamic>.from(raw)))
              .toList(growable: false);
          return InvoicePage(items: items, total: items.length, page: 1);
        }
      }
      return const InvoicePage(items: [], total: 0, page: 1);
    }
  }

  Future<CustomerInvoice> getById(String id) async {
    try {
      final response =
          await _apiClient.get<dynamic>(ApiRoutes.v1('/invoices/$id'));
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Ankara hazipatikani.');
      }
      final invoice = CustomerInvoice.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      if (_cache != null) {
        await _cache.save('invoice_$id', invoice.toJson());
      }
      return invoice;
    } on AppException {
      if (_cache != null) {
        final cached = await _cache.load('invoice_$id');
        if (cached != null) {
          return CustomerInvoice.fromJson(cached);
        }
      }
      rethrow;
    }
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
