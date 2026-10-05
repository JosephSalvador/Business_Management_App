import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../network/app_exception.dart';
import '../../features/sales/data/sale_repository.dart';
import '../storage/sync_queue_dao.dart' show QueuedOperation;
import 'local_sales_service.dart';

/// What one drain pass achieved — feeds the UX summary, never shown raw.
class SyncOutcome {
  SyncOutcome({
    this.synced = 0,
    this.conflicted = 0,
    this.failed = 0,
    this.retriedLater = 0,
    this.pausedForSession = false,
    this.wentOffline = false,
    this.moduleDisabled = false,
    this.billingRequired = false,
  });

  int synced;
  int conflicted;
  int failed;
  int retriedLater;
  bool pausedForSession;
  bool wentOffline;
  bool moduleDisabled;
  bool billingRequired;

  bool get changed => synced > 0 || conflicted > 0 || failed > 0;
}

/// The single sync worker per device (M5.8).
///
/// Drains the persistent queue FIFO. Delivery is exactly-once by contract:
/// every attempt replays the operation's stable id as Idempotency-Key, so a
/// timeout after the server accepted the sale resolves to a replay of the
/// original on retry (M5.7). Conflicts are terminal states kept for review —
/// nothing is silently resolved or deleted (M5.12).
class SyncEngine {
  SyncEngine({
    required LocalSalesService salesService,
    required SaleRepository repository,
  })  : _salesService = salesService,
        _repository = repository;

  final LocalSalesService _salesService;
  final SaleRepository _repository;

  Future<void> Function(SyncOutcome)? onDrained;

  bool _draining = false;

  /// True while a drain is in flight — the UX shows "Nasawazisha mauzo...".
  bool get isSyncing => _draining;

  /// Processes all due operations. Safe to call concurrently: the second
  /// call returns immediately while the first keeps working.
  Future<SyncOutcome> drain({bool forceRetryAll = false}) async {
    if (_draining) {
      return SyncOutcome();
    }
    _draining = true;
    final outcome = SyncOutcome();
    try {
      while (true) {
        final op = await _salesService.claimNext(
          now: DateTime.now().toUtc(),
          ignoreSchedule: forceRetryAll,
        );
        if (op == null) {
          break;
        }

        // Price sanity before sending: the offline sale charged the cached
        // shelf price; if the server would resolve a different price now the
        // customer's transaction must NOT be silently altered (M5.12 CASE 5).
        if (!await _pricesStillMatch(op, outcome)) {
          continue;
        }

        final delivered = await _deliver(op, outcome);
        if (delivered == _DeliveryResult.stop) {
          break;
        }
      }
    } finally {
      _draining = false;
    }
    if (outcome.changed || forceRetryAll) {
      await onDrained?.call(outcome);
    }
    return outcome;
  }

  Future<bool> _pricesStillMatch(
      QueuedOperation op, SyncOutcome outcome) async {
    try {
      final payload = op.decodedPayload;
      final branchId = payload['branchId'] as String?;
      final paidAmount =
          ((payload['payments'] as List?)?.firstOrNull?['amount'] as num?)
              ?.toDouble();
      if (branchId == null || paidAmount == null) {
        return true; // Let the backend decide anything unusual.
      }
      var expected = 0.0;
      for (final raw in payload['lines'] as List? ?? []) {
        final line = raw as Map<String, dynamic>;
        final resolved = await _repository.resolvePrice(
          line['productId'] as String,
          quantity: (line['quantity'] as num).toDouble(),
          branchId: branchId,
        );
        if (resolved == null) {
          await _conflict(
              op, outcome, 'PRODUCT', 'Bidhaa haipatikani tena kwenye mfumo.');
          return false;
        }
        expected += resolved.price * (line['quantity'] as num).toDouble();
      }
      if ((expected - paidAmount).abs() > 0.01) {
        await _conflict(op, outcome, 'PRICE',
            'Bei imebadilika kwenye mfumo. Muamala unahitaji kuangaliwa.');
        return false;
      }
      return true;
    } on AppException {
      // Cannot verify right now (offline/timeout): send anyway — the
      // backend re-resolves and its validation has the final word.
      return true;
    }
  }

  Future<_DeliveryResult> _deliver(
    QueuedOperation op,
    SyncOutcome outcome,
  ) async {
    switch (op.operationType) {
      case 'sale.create':
        return _deliverSale(op, outcome);
      default:
        await _salesService.markQueueFailed(
          op.operationId,
          errorCode: 'UNKNOWN_OP',
          errorMessage: 'Unknown operation type ${op.operationType}',
        );
        outcome.failed++;
        return _DeliveryResult.continue_;
    }
  }

  Future<_DeliveryResult> _deliverSale(
    QueuedOperation op,
    SyncOutcome outcome,
  ) async {
    try {
      final sale = await _repository.create(
        body: jsonDecode(op.payload) as Map<String, dynamic>,
        idempotencyKey: op.operationId,
      );
      await _salesService.markSaleSynced(
        clientSaleId: op.aggregateId,
        serverSaleId: sale.id,
        serverNumber: sale.number,
      );
      outcome.synced++;
      return _DeliveryResult.continue_;
    } on ValidationException catch (error) {
      final code =
          error.message.contains('Insufficient stock') ? 'STOCK' : 'VALIDATION';
      await _conflict(op, outcome, code, error.message);
      return _DeliveryResult.continue_;
    } on UnauthorizedException {
      // Session problem: pause the engine without burning an attempt.
      await _salesService.releaseUnattempted(op.operationId);
      outcome.pausedForSession = true;
      return _DeliveryResult.stop;
    } on ForbiddenException catch (error) {
      // User disabled / branch disabled / permission removed (M5.12 CASE 6-8).
      await _fail(op, outcome, 'PERMISSION', error.message);
      return _DeliveryResult.continue_;
    } on ModuleDisabledException catch (error) {
      await _fail(op, outcome, 'MODULE_DISABLED', error.message);
      outcome.moduleDisabled = true;
      return _DeliveryResult.continue_;
    } on PaymentRequiredException {
      await _salesService.releaseUnattempted(op.operationId);
      outcome.billingRequired = true;
      return _DeliveryResult.continue_;
    } on QuotaExceededException catch (error) {
      await _fail(op, outcome, 'QUOTA', error.message);
      return _DeliveryResult.continue_;
    } on ConflictException catch (error) {
      // Should not happen for well-formed keys (replay returns 200); keep
      // for review rather than guessing.
      await _fail(op, outcome, 'CONFLICT_409', error.message);
      return _DeliveryResult.continue_;
    } on NetworkException {
      await _retryLater(op, outcome);
      outcome.wentOffline = true;
      return _DeliveryResult.stop;
    } on TimeoutException {
      // CRITICAL: the server may have accepted the sale before the response
      // was lost. Retrying with the same key is safe either way (M5.7).
      await _retryLater(op, outcome);
      return _DeliveryResult.stop;
    } on ServerException {
      await _retryLater(op, outcome);
      return _DeliveryResult.stop;
    } on UnknownException {
      await _retryLater(op, outcome);
      return _DeliveryResult.stop;
    }
  }

  Future<void> _conflict(
    QueuedOperation op,
    SyncOutcome outcome,
    String code,
    String message,
  ) async {
    debugPrint('sync conflict ${op.operationId}: $code');
    await _salesService.markSaleConflict(
      clientSaleId: op.aggregateId,
      errorCode: code,
      errorMessage: message,
    );
    outcome.conflicted++;
  }

  Future<void> _fail(
    QueuedOperation op,
    SyncOutcome outcome,
    String code,
    String message,
  ) async {
    await _salesService.markQueueFailed(
      op.operationId,
      errorCode: code,
      errorMessage: message,
    );
    await _salesService.markSaleConflictOnly(
      clientSaleId: op.aggregateId,
      errorCode: code,
      errorMessage: message,
    );
    outcome.failed++;
  }

  Future<void> _retryLater(QueuedOperation op, SyncOutcome outcome) async {
    await _salesService.releaseForRetry(
      op.operationId,
      attemptCount: op.attemptCount,
    );
    outcome.retriedLater++;
  }
}

enum _DeliveryResult { continue_, stop }

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
