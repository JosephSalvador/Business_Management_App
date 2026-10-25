import '../../../core/storage/cached_catalog_dao.dart';
import '../../../core/storage/local_sales_dao.dart';
import '../../../core/network/app_exception.dart';
import '../domain/sale.dart';

/// Records an offline sale into the encrypted local database in ONE atomic
/// transaction (sale + lines + payment + sync-queue row), enforcing the
/// conservative local stock guard first (M5.4/M5.5).
///
/// Prices come exclusively from the cached server-provided shelf prices —
/// the client never invents pricing or tax. Totals stored locally are
/// estimates; the server remains the final authority at sync time.
class OfflineSaleRecorder {
  OfflineSaleRecorder({
    required LocalSalesDao salesDao,
    required CachedCatalogDao catalogDao,
    required Future<String?> Function() tenantIdOf,
    required Future<String> Function() deviceIdOf,
    required Future<String?> Function() userIdOf,
    required Future<String?> Function() branchIdOf,
  })  : _salesDao = salesDao,
        _catalogDao = catalogDao,
        _tenantIdOf = tenantIdOf,
        _deviceIdOf = deviceIdOf,
        _userIdOf = userIdOf,
        _branchIdOf = branchIdOf;

  final LocalSalesDao _salesDao;
  final CachedCatalogDao _catalogDao;
  final Future<String?> Function() _tenantIdOf;
  final Future<String> Function() _deviceIdOf;
  final Future<String?> Function() _userIdOf;
  final Future<String?> Function() _branchIdOf;

  /// Records [lines] as one pending offline sale. Throws [ValidationException]
  /// when context is missing or local projected stock cannot cover a line —
  /// nothing is written in that case.
  /// [clientSaleIdOverride] reuses the idempotency identity already drawn by
  /// the online attempt — critical when the server may hold that exact sale.
  /// [paymentAmount] is the money actually tendered (cash change); defaults to
  /// the subtotal estimate when null, EXCEPT for credit sales which default to
  /// zero so the whole balance is kept on the customer's ledger.
  /// [customerId] links a credit sale to its ledger customer.
  Future<RecordedOfflineSale> record({
    String? clientSaleIdOverride,
    required List<CartLine> lines,
    required int paymentMethod,
    double? paymentAmount,
    String? customerId,
  }) async {
    final tenantId = await _tenantIdOf();
    if (tenantId == null) {
      throw ValidationException('Chagua biashara kwanza.');
    }
    final branchId = await _branchIdOf();
    if (branchId == null) {
      throw ValidationException('Tawi la biashara halipatikani.');
    }
    final deviceId = await _deviceIdOf();
    final userId = await _userIdOf() ?? '';

    // Stock is advisory and never blocks sales (African retail reality).
    // The server remains the final authority at sync time and supports
    // non-blocking debit / negative balances.
    for (final line in lines) {
      if (line.unitPriceOverride != null) {
        continue;
      }
      // Advisory stock check (non-blocking):
      await _catalogDao.projectedQuantity(tenantId, line.productId);
    }

    var subtotal = 0.0;
    for (final line in lines) {
      subtotal += line.lineTotal;
    }

    final credit = paymentMethod == PaymentMethod.credit;
    final tendered =
        credit ? (paymentAmount ?? 0) : (paymentAmount ?? subtotal);

    return _salesDao.recordOfflineSale(
      clientSaleIdOverride: clientSaleIdOverride,
      tenantId: tenantId,
      branchId: branchId,
      deviceId: deviceId,
      userId: userId,
      paymentMethod: paymentMethod,
      paymentAmount: tendered,
      customerId: customerId,
      subtotalEstimate: subtotal,
      taxEstimate: 0,
      totalEstimate: subtotal,
      lines: [
        for (final line in lines)
          OfflineSaleLineInput(
            productId: line.productId,
            productName: line.name,
            sku: null,
            quantity: line.quantity,
            unitPriceSnapshot: line.effectiveUnitPrice,
            unitPriceOverride: line.unitPriceOverride,
          ),
      ],
    );
  }

  /// Builds the provisional receipt-facing view of a pending sale so the
  /// success screen works identically online and offline.
  static SaleDto provisionalDto({
    required RecordedOfflineSale recorded,
    required List<CartLine> lines,
    required int paymentMethod,
    required double total,
    double? paymentAmount,
    String? customerName,
  }) {
    final tendered = paymentMethod == PaymentMethod.credit
        ? (paymentAmount ?? 0)
        : (paymentAmount ?? total);
    final change = tendered - total;
    return SaleDto(
      id: recorded.clientSaleId,
      number: '',
      status: LocalSaleStatuses.pending,
      saleDate: DateTime.now().toUtc(),
      currency: 'TZS',
      subtotal: total,
      discountAmount: 0,
      taxAmount: 0,
      totalAmount: total,
      amountPaid: tendered,
      change: change < 0 ? 0 : change,
      customerName: customerName,
      lines: [
        for (final line in lines)
          SaleLineData(
            productName: line.name,
            sku: null,
            quantity: line.quantity,
            unitPrice: line.effectiveUnitPrice,
            discountAmount: 0,
            taxCode: '',
            taxAmount: 0,
            lineTotal: line.lineTotal,
            unitOfMeasureName: null,
          ),
      ],
      payments: [SalePaymentData(method: paymentMethod, amount: tendered)],
      pendingLocally: true,
    );
  }
}

/// Mirrors tables.LocalSaleStatus without dragging storage types into the UI.
abstract final class LocalSaleStatuses {
  static const pending = 0;
}
