import 'dart:convert';

import 'package:drift/drift.dart';

import 'local_database.dart';
import 'tables.dart';

export 'tables.dart' show SyncOperationStatus;

/// One operation pulled from the queue for delivery.
class QueuedOperation {
  const QueuedOperation({
    required this.operationId,
    required this.operationType,
    required this.aggregateType,
    required this.aggregateId,
    required this.tenantId,
    required this.branchId,
    required this.deviceId,
    required this.payload,
    required this.attemptCount,
  });

  final String operationId;
  final String operationType;
  final String aggregateType;
  final String aggregateId;
  final String tenantId;
  final String branchId;
  final String deviceId;
  final String payload;
  final int attemptCount;

  Map<String, dynamic> get decodedPayload =>
      jsonDecode(payload) as Map<String, dynamic>;
}

/// Persistent sync queue (M5.6). Failed and conflicted rows are never
/// deleted; retry uses exponential backoff via nextAttemptAt.
class SyncQueueDao {
  SyncQueueDao(this._db);

  static const baseBackoff = Duration(seconds: 5);
  static const maxBackoff = Duration(minutes: 30);
  static const maxAttemptsBeforeFailed = 12;

  final LocalDatabase _db;

  /// Claims the oldest due pending operation, marking it syncing. Returns
  /// null when nothing is due. Single-claim semantics support one worker.
  /// [ignoreSchedule] bypasses the backoff window (manual sync).
  Future<QueuedOperation?> claimNext({
    required DateTime now,
    String? tenantId,
    bool ignoreSchedule = false,
  }) {
    return _db.transaction(() async {
      final dueFilter = Expression.and([
        _db.syncQueue.status.equals(SyncOperationStatus.pending),
        if (!ignoreSchedule)
          _db.syncQueue.nextAttemptAt.isNull() |
              _db.syncQueue.nextAttemptAt.isSmallerOrEqualValue(now),
        if (tenantId != null) _db.syncQueue.tenantId.equals(tenantId),
      ]);
      final row = await (_db.select(_db.syncQueue)
            ..where((t) => dueFilter)
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt)])
            ..limit(1))
          .getSingleOrNull();
      if (row == null) {
        return null;
      }
      await (_db.update(_db.syncQueue)
            ..where((t) => t.operationId.equals(row.operationId)))
          .write(const SyncQueueCompanion(
        status: Value(SyncOperationStatus.syncing),
      ));
      return QueuedOperation(
        operationId: row.operationId,
        operationType: row.operationType,
        aggregateType: row.aggregateType,
        aggregateId: row.aggregateId,
        tenantId: row.tenantId,
        branchId: row.branchId,
        deviceId: row.deviceId,
        payload: row.payload,
        attemptCount: row.attemptCount,
      );
    });
  }

  /// Returns an in-flight operation to pending unchanged — used when the
  /// engine stops before attempting delivery (session paused, offline).
  Future<void> releaseUnattempted(String operationId) {
    return (_db.update(_db.syncQueue)
          ..where((t) => t.operationId.equals(operationId)))
        .write(const SyncQueueCompanion(
      status: Value(SyncOperationStatus.pending),
    ));
  }

  /// Releases a claimed op back to pending with exponential backoff.
  Future<void> releaseForRetry(    String operationId, {
    required int attemptCount,
    String? errorCode,
    String? errorMessage,
  }) async {
    final attempts = attemptCount + 1;
    final backoff = baseBackoff * (1 << attempts.clamp(0, 12));
    final delay =
        backoff > maxBackoff ? maxBackoff : backoff;
    final now = DateTime.now().toUtc();
    await (_db.update(_db.syncQueue)
          ..where((t) => t.operationId.equals(operationId)))
        .write(SyncQueueCompanion(
      status: const Value(SyncOperationStatus.pending),
      attemptCount: Value(attempts),
      lastAttemptAt: Value(now),
      nextAttemptAt:
          Value(attempts >= maxAttemptsBeforeFailed ? null : now.add(delay)),
      errorCode: Value(errorCode),
      errorMessage: Value(errorMessage),
      updatedAt: Value(now),
    ));
  }

  Future<void> markSynced(String operationId, String serverReference) async {
    final now = DateTime.now().toUtc();
    await (_db.update(_db.syncQueue)
          ..where((t) => t.operationId.equals(operationId)))
        .write(SyncQueueCompanion(
      status: const Value(SyncOperationStatus.synced),
      serverReference: Value(serverReference),
      lastAttemptAt: Value(now),
      updatedAt: Value(now),
    ));
  }

  /// Terminal states — kept forever for auditability (M5 rule 9).
  Future<void> markConflict(
    String operationId, {
    required String errorCode,
    required String errorMessage,
  }) =>
      _markTerminal(
        operationId,
        status: SyncOperationStatus.conflict,
        errorCode: errorCode,
        errorMessage: errorMessage,
      );

  Future<void> markFailed(
    String operationId, {
    required String errorCode,
    required String errorMessage,
  }) =>
      _markTerminal(
        operationId,
        status: SyncOperationStatus.failed,
        errorCode: errorCode,
        errorMessage: errorMessage,
      );

  Future<void> _markTerminal(
    String operationId, {
    required int status,
    required String errorCode,
    required String errorMessage,
  }) async {
    final now = DateTime.now().toUtc();
    await (_db.update(_db.syncQueue)
          ..where((t) => t.operationId.equals(operationId)))
        .write(SyncQueueCompanion(
      status: Value(status),
      lastAttemptAt: Value(now),
      errorCode: Value(errorCode),
      errorMessage: Value(errorMessage),
      updatedAt: Value(now),
    ));
  }

  Future<int> countByStatus(int status) async {
    final countExpr = _db.syncQueue.operationId.count();
    final query = _db.selectOnly(_db.syncQueue)
      ..addColumns([countExpr])
      ..where(_db.syncQueue.status.equals(status));
    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }

  /// Resets ops stuck in `syncing` (e.g. after an app crash mid-flight)
  /// back to pending so they are retried on next start.
  Future<int> recoverStaleSyncing() {
    return (_db.update(_db.syncQueue)
          ..where((t) => t.status.equals(SyncOperationStatus.syncing)))
        .write(const SyncQueueCompanion(
      status: Value(SyncOperationStatus.pending),
    ));
  }
}
