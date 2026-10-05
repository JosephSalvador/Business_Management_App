import '../storage/cached_catalog_dao.dart';
import '../../features/sales/domain/sale.dart';
import '../storage/local_database.dart' show LocalDatabase;
import '../storage/local_sales_dao.dart';
import '../storage/quick_sale_memory.dart';
import '../storage/sync_queue_dao.dart';

/// Application-level facade over the local sale + queue storage. Controllers
/// and the sync engine talk to THIS, never to Drift directly.
class LocalSalesService {
  LocalSalesService({required LocalDatabase database})
      : sales = LocalSalesDao(database),
        queue = SyncQueueDao(database),
        catalog = CachedCatalogDao(database),
        quickMemory = QuickSaleMemoryDao(database);

  final LocalSalesDao sales;
  final SyncQueueDao queue;
  final CachedCatalogDao catalog;
  final QuickSaleMemoryDao quickMemory;

  Future<QueuedOperation?> claimNext({
    required DateTime now,
    bool ignoreSchedule = false,
    String? tenantId,
  }) =>
      // Manual "Sawazisha sasa" ignores backoff schedules so stuck-but-
      // recoverable operations can be pushed immediately.
      queue.claimNext(
        now: now,
        tenantId: tenantId,
        ignoreSchedule: ignoreSchedule,
      );

  /// Returns an in-flight operation to pending WITHOUT counting an attempt
  /// (session paused / engine stopped before any network try).
  Future<void> releaseUnattempted(String operationId) =>
      queue.releaseUnattempted(operationId);

  Future<void> releaseForRetry(
    String operationId, {
    required int attemptCount,
  }) =>
      queue.releaseForRetry(operationId, attemptCount: attemptCount);

  Future<void> markSaleSynced({
    required String clientSaleId,
    required String serverSaleId,
    required String serverNumber,
  }) async {
    await sales.markSynced(
      clientSaleId: clientSaleId,
      serverSaleId: serverSaleId,
      serverNumber: serverNumber,
    );
    await queue.markSynced(clientSaleId, serverSaleId);
  }

  Future<void> markSaleConflict({
    required String clientSaleId,
    required String errorCode,
    required String errorMessage,
  }) async {
    await sales.markConflict(
      clientSaleId: clientSaleId,
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
    await queue.markConflict(
      clientSaleId,
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
  }

  /// Marks only the local sale conflicted — used when the queue row already
  /// carries a different terminal state (e.g. PERMISSION failure).
  Future<void> markSaleConflictOnly({
    required String clientSaleId,
    required String errorCode,
    required String errorMessage,
  }) {
    return sales.markConflict(
      clientSaleId: clientSaleId,
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
  }

  Future<void> markQueueFailed(
    String operationId, {
    required String errorCode,
    required String errorMessage,
  }) {
    return queue.markFailed(
      operationId,
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
  }

  /// Called once at app start: anything caught mid-flight by a crash or kill
  /// goes back to pending so it is retried (M5.6 crash safety).
  Future<void> recoverFromRestart() => queue.recoverStaleSyncing();

  Future<int> pendingSaleCount() =>
      sales.countByStatus(LocalSaleStatus.pending);

  Future<int> conflictedSaleCount() =>
      sales.countByStatus(LocalSaleStatus.conflict);

  /// Builds a provisional [SaleDto] from the local pending sale, so receipts
  /// and detail pages work before (or without) server confirmation.
  /// Returns null when no local sale exists for the id.
  Future<SaleDto?> findProvisionalDto(String clientSaleId) async {
    final sale = await sales.byClientSaleId(clientSaleId);
    if (sale == null) {
      return null;
    }
    if (sale.status == LocalSaleStatus.synced) {
      // A confirmed sale must come from the server (authoritative totals).
      return null;
    }
    final lines = await sales.linesOf(clientSaleId);
    return SaleDto(
      id: sale.clientSaleId,
      number: sale.serverNumber ?? '',
      status: sale.status,
      saleDate: sale.effectiveAt,
      currency: sale.currency,
      subtotal: sale.subtotalEstimate,
      discountAmount: 0,
      taxAmount: sale.taxEstimate,
      totalAmount: sale.totalEstimate,
      amountPaid: sale.paymentAmount,
      change: 0,
      customerName: null,
      lines: [
        for (final line in lines)
          SaleLineData(
            productName: line.productName,
            sku: line.sku,
            quantity: line.quantity,
            unitPrice: line.unitPriceSnapshot,
            discountAmount: 0,
            taxCode: '',
            taxAmount: 0,
            lineTotal: line.lineTotalEstimate,
            unitOfMeasureName: null,
          ),
      ],
      payments: [
        SalePaymentData(method: sale.paymentMethod, amount: sale.paymentAmount),
      ],
      pendingLocally: sale.status == LocalSaleStatus.pending,
    );
  }
}
