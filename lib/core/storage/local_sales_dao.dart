import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'local_database.dart';
import 'tables.dart';

export 'tables.dart' show SyncOperationStatus, LocalSaleStatus;

/// A pending sale as recorded locally, ready to be replayed to
/// POST /api/v1/sales verbatim.
class RecordedOfflineSale {
  const RecordedOfflineSale({
    required this.clientSaleId,
    required this.operationId,
    required this.payload,
  });

  /// Same GUID for both identities: body clientSaleId and Idempotency-Key.
  final String clientSaleId;

  /// Queue identity (= clientSaleId for 'sale.create' operations).
  final String operationId;

  /// Exact JSON body built by buildCreateSaleBody at record time.
  final String payload;
}

/// Writes offline sales atomically (M5.4): the sale, its lines, its payment,
/// and the sync-queue row succeed or fail together. There is never a partial
/// local sale.
class LocalSalesDao {
  LocalSalesDao(this._db, {Uuid uuid = const Uuid()}) : _uuid = uuid;

  final LocalDatabase _db;
  final Uuid _uuid;

  Future<RecordedOfflineSale> recordOfflineSale({
    String? clientSaleIdOverride,
    required String tenantId,
    required String branchId,
    required String deviceId,
    required String userId,
    required int paymentMethod,
    required double subtotalEstimate,
    required double taxEstimate,
    required double totalEstimate,
    double? paymentAmount,
    String? customerId,
    DateTime? effectiveAt,
    required List<OfflineSaleLineInput> lines,
  }) async {
    final clientSaleId = clientSaleIdOverride ?? _uuid.v4();
    final now = DateTime.now().toUtc();
    final effective = effectiveAt ?? now;
    final tendered = paymentAmount ?? totalEstimate;
    final payload = buildSalePayload(
      branchId: branchId,
      clientSaleId: clientSaleId,
      lines: lines,
      paymentMethod: paymentMethod,
      total: totalEstimate,
      paymentAmount: tendered,
      customerId: customerId,
      effectiveAt: effective,
    );

    await _db.transaction(() async {
      await _db.into(_db.localSales).insert(LocalSalesCompanion.insert(
            clientSaleId: clientSaleId,
            tenantId: tenantId,
            branchId: branchId,
            deviceId: deviceId,
            userId: userId,
            status: LocalSaleStatus.pending,
            currency: 'TZS',
            effectiveAt: effective,
            createdAt: now,
            totalEstimate: totalEstimate,
            paymentMethod: paymentMethod,
            paymentAmount: tendered,
            subtotalEstimate: Value(subtotalEstimate),
            taxEstimate: Value(taxEstimate),
          ));
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        await _db
            .into(_db.localSaleLines)
            .insert(LocalSaleLinesCompanion.insert(
              clientSaleId: clientSaleId,
              orderIndex: i,
              productId: line.productId,
              productName: line.productName,
              quantity: line.quantity,
              unitPriceSnapshot: line.unitPriceSnapshot,
              lineTotalEstimate: line.quantity * line.unitPriceSnapshot,
              sku: Value(line.sku),
            ));
      }
      await _db.into(_db.localPayments).insert(LocalPaymentsCompanion.insert(
            clientSaleId: clientSaleId,
            orderIndex: 0,
            method: paymentMethod,
            amount: tendered,
          ));
      await _db.into(_db.syncQueue).insert(SyncQueueCompanion.insert(
            operationId: clientSaleId,
            tenantId: tenantId,
            branchId: branchId,
            deviceId: deviceId,
            operationType: 'sale.create',
            aggregateType: 'sale',
            aggregateId: clientSaleId,
            payload: payload,
            status: SyncOperationStatus.pending,
            createdAt: now,
            updatedAt: now,
          ));
    });

    return RecordedOfflineSale(
      clientSaleId: clientSaleId,
      operationId: clientSaleId,
      payload: payload,
    );
  }

  /// Wire-exact body for POST /api/v1/sales. Kept beside the schema so a
  /// queued row can always be rebuilt from persisted data alone.
  static String buildSalePayload({
    required String branchId,
    required String clientSaleId,
    required List<OfflineSaleLineInput> lines,
    required int paymentMethod,
    required double total,
    double? paymentAmount,
    String? customerId,
    required DateTime effectiveAt,
  }) {
    return jsonEncode({
      'branchId': branchId,
      'clientSaleId': clientSaleId,
      'source': 0,
      if (customerId != null) 'customerId': customerId,
      'effectiveAt': effectiveAt.toIso8601String(),
      'isElectronicPayment': paymentMethod != PaymentCodes.cash &&
          paymentMethod != PaymentCodes.credit,
      'lines': [
        for (final line in lines)
          {
            'productId': line.productId,
            'quantity': line.quantity,
            if (line.unitPriceOverride != null) ...{
              'unitPrice': line.unitPriceOverride,
              'productName': line.productName,
            },
          },
      ],
      'payments': [
        {
          'method': paymentMethod,
          'amount': paymentAmount ?? total,
        },
      ],
    });
  }

  Future<LocalSale?> byClientSaleId(String clientSaleId) {
    return (_db.select(_db.localSales)
          ..where((t) => t.clientSaleId.equals(clientSaleId)))
        .getSingleOrNull();
  }

  Future<List<LocalSaleLine>> linesOf(String clientSaleId) {
    return (_db.select(_db.localSaleLines)
          ..where((t) => t.clientSaleId.equals(clientSaleId))
          ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
        .get();
  }

  Future<List<LocalSale>> byStatus(int status, {int limit = 100}) {
    return (_db.select(_db.localSales)
          ..where((t) => t.status.equals(status))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<int> countByStatus(int status) async {
    final countExpr = _db.localSales.clientSaleId.count();
    final query = _db.selectOnly(_db.localSales)
      ..addColumns([countExpr])
      ..where(_db.localSales.status.equals(status));
    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }

  Future<void> markSynced({
    required String clientSaleId,
    required String serverSaleId,
    required String serverNumber,
  }) {
    return (_db.update(_db.localSales)
          ..where((t) => t.clientSaleId.equals(clientSaleId)))
        .write(LocalSalesCompanion(
      status: const Value(LocalSaleStatus.synced),
      serverSaleId: Value(serverSaleId),
      serverNumber: Value(serverNumber),
      syncedAt: Value(DateTime.now().toUtc()),
    ));
  }

  Future<void> markConflict({
    required String clientSaleId,
    required String errorCode,
    required String errorMessage,
  }) {
    return (_db.update(_db.localSales)
          ..where((t) => t.clientSaleId.equals(clientSaleId)))
        .write(LocalSalesCompanion(
      status: const Value(LocalSaleStatus.conflict),
      errorCode: Value(errorCode),
      errorMessage: Value(errorMessage),
      lastAttemptAt: Value(DateTime.now().toUtc()),
    ));
  }
}

class OfflineSaleLineInput {
  const OfflineSaleLineInput({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPriceSnapshot,
    this.sku,
    this.unitPriceOverride,
  });

  final String productId;
  final String productName;
  final double quantity;
  final double unitPriceSnapshot;
  final String? sku;

  /// Client-fixed unit price for quick-sale lines (sent as `unitPrice`
  /// on the wire). Null for normal catalogue lines.
  final double? unitPriceOverride;
}

/// Wire-format payment method codes used when building the payload.
abstract final class PaymentCodes {
  static const cash = 0;
  static const credit = 4;
}
