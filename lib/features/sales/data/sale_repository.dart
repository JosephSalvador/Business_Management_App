import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../domain/sale.dart';

/// Resolved selling price from `/pricing/resolve`.
class ResolvedPrice {
  const ResolvedPrice({required this.price, required this.currency});

  factory ResolvedPrice.fromJson(Map<String, dynamic> json) => ResolvedPrice(
        price: (json['price'] as num).toDouble(),
        currency: json['currency'] as String? ?? '',
      );

  final double price;
  final String currency;
}

/// Talks to the backend sales APIs. The backend is the only authority on
/// totals, tax, stock and receipt numbering — this class only carries data.
class SaleRepository {
  SaleRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// Creates a sale. [idempotencyKey] must be a stable GUID per logical sale:
  /// replays (double tap, timeout retry, network resend) return the original
  /// sale instead of creating a duplicate.
  Future<SaleDto> create({
    required Map<String, dynamic> body,
    required String idempotencyKey,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/v1/sales',
      body: body,
      headers: {'Idempotency-Key': idempotencyKey},
    );
    return SaleDto.fromJson(response.data!);
  }

  Future<SaleDto> getById(String id) async {
    final response = await _api.get<Map<String, dynamic>>('/api/v1/sales/$id');
    return SaleDto.fromJson(response.data!);
  }

  /// Lists sales, newest first. Pass [from]/[to] for "today's sales".
  Future<PagedSales> list({
    int page = 1,
    int pageSize = 50,
    DateTime? from,
    DateTime? to,
    int? status,
    String? search,
  }) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/api/v1/sales',
      query: {
        'page': page,
        'pageSize': pageSize,
        if (from != null) 'from': from.toUtc().toIso8601String(),
        if (to != null) 'to': to.toUtc().toIso8601String(),
        if (status != null) 'status': status,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    return PagedSales.fromJson(response.data!);
  }

  /// Resolves the current selling price for one unit of [productId] against
  /// the tenant's default price list (Retail). Returns null when no price
  /// exists so callers can decide how to degrade.
  Future<ResolvedPrice?> resolvePrice(
    String productId, {
    double quantity = 1,
    String? branchId,
  }) async {
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/api/v1/pricing/resolve',
        query: {
          'productId': productId,
          'priceType': 0,
          'quantity': quantity,
          if (branchId != null) 'branchId': branchId,
        },
      );
      return ResolvedPrice.fromJson(response.data!);
    } on NotFoundException {
      return null;
    }
  }
}
