import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:business_management_system/core/local/local_database.dart';
import 'package:business_management_system/core/local/tables.dart';
import 'package:business_management_system/core/network/app_exception.dart';
import 'package:business_management_system/core/local/local_sales_dao.dart' show OfflineSaleLineInput;
import 'package:business_management_system/features/sales/application/local_sales_service.dart';
import 'package:business_management_system/features/sales/application/sync_engine.dart';
import 'package:business_management_system/features/sales/data/sale_repository.dart';
import 'package:business_management_system/features/sales/domain/sale.dart';

/// Simulates the backend's contract: exactly-once per Idempotency-Key.
/// Accepts the sale, records it, and replays the original on any later
/// delivery of the same key — regardless of what error the client saw.
class ServerSimulatingRepository implements SaleRepository {
  final Map<String, SaleDto> accepted = {};
  final List<String> attempts = [];

  /// Errors to throw on successive NEW deliveries (replays never fail,
  /// mirroring the server where the replay path runs first).
  final List<AppException> failuresOnNewKey = [];

  @override
  Future<SaleDto> create({
    required Map<String, dynamic> body,
    required String idempotencyKey,
  }) async {
    final priorAttempts =
        attempts.where((k) => k == idempotencyKey).length;
    attempts.add(idempotencyKey);

    // Replay path runs first on the real backend.
    final existing = accepted[idempotencyKey];
    if (existing != null && priorAttempts > 0) {
      return existing;
    }

    if (priorAttempts == 0 && failuresOnNewKey.isNotEmpty) {
      final error = failuresOnNewKey.removeAt(0);
      if (error is TimeoutException || error is NetworkException) {
        // The request DID reach the server and was saved — only the
        // response was lost. This is exactly-once's hardest case.
        accepted[idempotencyKey] = _dto(body['clientSaleId'] as String);
      }
      throw error;
    }

    final dto = _dto(body['clientSaleId'] as String);
    accepted[idempotencyKey] = dto;
    return dto;
  }

  @override
  Future<ResolvedPrice?> resolvePrice(
    String productId, {
    double quantity = 1,
    String? branchId,
  }) async =>
      const ResolvedPrice(price: 2500, currency: 'TZS');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SaleDto _dto(String id) => SaleDto(
      id: 'srv-$id',
      number: 'S-2026-00042',
      status: 0,
      saleDate: DateTime.now().toUtc(),
      currency: 'TZS',
      subtotal: 5000,
      discountAmount: 0,
      taxAmount: 762.71,
      totalAmount: 5000,
      amountPaid: 5000,
      change: 0,
      lines: const [],
      payments: const [],
    );

void main() {
  late LocalDatabase db;
  late LocalSalesService service;
  late ServerSimulatingRepository repository;
  late SyncEngine engine;

  setUp(() {
    db = LocalDatabase(NativeDatabase.memory());
    service = LocalSalesService(database: db);
    repository = ServerSimulatingRepository();
    engine = SyncEngine(salesService: service, repository: repository);
  });

  tearDown(() async => db.close());

  Future<String> recordOfflineSale({String? id}) async {
    final recorded = await service.sales.recordOfflineSale(
      clientSaleIdOverride: id,
      tenantId: 'tenant-1',
      branchId: 'branch-1',
      deviceId: 'device-1',
      userId: 'user-1',
      paymentMethod: 0,
      subtotalEstimate: 5000,
      taxEstimate: 0,
      totalEstimate: 5000,
      effectiveAt: DateTime.utc(2026, 8, 23, 10),
      lines: [
        const OfflineSaleLineInput(
          productId: 'p-1',
          productName: 'Mchele',
          quantity: 2,
          unitPriceSnapshot: 2500,
        ),
      ],
    );
    return recorded.clientSaleId;
  }

  group('happy paths', () {
    test('offline sale drains and is marked synced exactly once', () async {
      final id = await recordOfflineSale();

      final outcome = await engine.drain();

      expect(outcome.synced, 1);
      expect(repository.accepted.keys, [id]);
      expect(repository.attempts.length, 1);

      final local =
          await service.sales.byClientSaleId(id);
      expect(local!.status, LocalSaleStatus.synced);
      expect(local.serverNumber, 'S-2026-00042');
    });

    test('multiple offline sales drain FIFO', () async {
      final first = await recordOfflineSale();
      final second = await recordOfflineSale();

      await engine.drain();

      expect(repository.attempts, [first, second]);
    });

    test('drain after everything synced does nothing', () async {
      await recordOfflineSale();
      await engine.drain();
      final second = await engine.drain();

      expect(second.synced, 0);
      expect(repository.attempts.length, 1);
    });
  });

  group('transport failures retry safely (M5.7)', () {
    test('timeout AFTER server acceptance → retry replays original',
        () async {
      final id = await recordOfflineSale();
      // The server accepts, but the response is lost on the way back.
      // Model: accept first, then make the NEXT new-key delivery time out.
      repository.failuresOnNewKey.add(TimeoutException());
      repository.accepted[id] = _dto(id); // server already holds it

      final firstOutcome = await engine.drain();
      expect(firstOutcome.retriedLater, 1);

      // Op is pending again with a scheduled retry.
      final row = await _queueRow(db, id);
      expect(row.status, SyncOperationStatus.pending);
      expect(row.nextAttemptAt, isNotNull);

      // Reconnect: manual sync ignores backoff.
      final second = await engine.drain(forceRetryAll: true);
      expect(second.synced, 1);

      // Exactly ONE server sale despite two deliveries.
      expect(repository.attempts, [id, id]);
      expect(repository.accepted.length, 1);
      final local = await service.sales.byClientSaleId(id);
      expect(local!.status, LocalSaleStatus.synced);
    });

    test('network failure releases op and stops the drain', () async {
      final first = await recordOfflineSale();
      final second = await recordOfflineSale();
      repository.failuresOnNewKey.add(NetworkException());

      final outcome = await engine.drain();

      expect(outcome.retriedLater, 1);
      expect(outcome.synced, 0);
      expect(repository.attempts, [first],
          reason: 'drain stops on transport failure');

      // Second op untouched.
      final row = await _queueRow(db, second);
      expect(row.status, SyncOperationStatus.pending);
      expect(row.attemptCount, 0);
    });

    test('server 5xx retries without marking conflict', () async {
      final id = await recordOfflineSale();
      repository.failuresOnNewKey.add(ServerException());

      await engine.drain();

      var row = await _queueRow(db, id);
      expect(row.status, SyncOperationStatus.pending);
      expect(row.attemptCount, 1);

      await engine.drain(forceRetryAll: true);
      expect((await service.sales.byClientSaleId(id))!.status,
          LocalSaleStatus.synced);
    });
  });

  group('conflicts are terminal and preserved (M5.12)', () {
    test('insufficient stock at sync → CONFLICT / STOCK, kept for review',
        () async {
      final id = await recordOfflineSale();
      repository.failuresOnNewKey.add(
        ValidationException("Insufficient stock for 'Mchele'."),
      );

      final outcome = await engine.drain();

      expect(outcome.conflicted, 1);
      final local = await service.sales.byClientSaleId(id);
      expect(local!.status, LocalSaleStatus.conflict);
      expect(local.errorCode, 'STOCK');
      final queueRow = await _queueRow(db, id);
      expect(queueRow.status, SyncOperationStatus.conflict);

      // A later drain must NOT re-deliver or delete it.
      await engine.drain(forceRetryAll: true);
      expect(repository.attempts.length, 1);
    });

    test('product deleted while offline → conflict requiring review',
        () async {
      final id = await recordOfflineSale();

      // Price resolution 404s → the engine conflicts before sending.
      final repo = _NullPriceRepository();
      final customEngine =
          SyncEngine(salesService: service, repository: repo);

      final outcome = await customEngine.drain();

      expect(outcome.conflicted, 1);
      expect(repo.createCalls, 0);
      final local = await service.sales.byClientSaleId(id);
      expect(local!.errorCode, 'PRODUCT');
    });
  });

  group('auth problems pause or fail (M5.12 CASE 6-8)', () {
    test('401 pauses the engine without burning attempts', () async {
      final first = await recordOfflineSale();
      await recordOfflineSale();
      repository.failuresOnNewKey.add(UnauthorizedException());

      final outcome = await engine.drain();

      expect(outcome.pausedForSession, true);
      expect(repository.attempts, [first]);
      final row = await _queueRow(db, first);
      expect(row.status, SyncOperationStatus.pending);
      expect(row.attemptCount, 0, reason: 'session issues are not failures');

      // Session restored: both ops deliver (1 paused attempt + 2 fresh).
      await engine.drain();
      expect(repository.attempts.length, 3);
    });

    test('403 (user/branch disabled) fails terminally for that op', () async {
      final blocked = await recordOfflineSale();
      final healthy = await recordOfflineSale();
      repository.failuresOnNewKey.add(ForbiddenException());

      final outcome = await engine.drain();

      expect(outcome.failed, 1);
      expect(outcome.synced, 1);
      final failedRow = await _queueRow(db, blocked);
      expect(failedRow.status, SyncOperationStatus.failed);
      final okLocal = await service.sales.byClientSaleId(healthy);
      expect(okLocal!.status, LocalSaleStatus.synced);
    });
  });

  group('price drift protection (M5.12 CASE 5)', () {
    test('price changed at server → conflict PRICE, sale not sent',
        () async {
      final id = await recordOfflineSale(); // snapshot 2500 × 2 = 5000 paid
      final repo = _PricedRepository(3000);
      final customEngine =
          SyncEngine(salesService: service, repository: repo);

      final outcome = await customEngine.drain();

      expect(outcome.conflicted, 1);
      expect(repo.createCalls, 0,
          reason: 'must not silently charge the customer more');
      final local = await service.sales.byClientSaleId(id);
      expect(local!.errorCode, 'PRICE');
    });

    test('unchanged price sends normally', () async {
      await recordOfflineSale();
      final repo = _PricedRepository(2500);
      final customEngine =
          SyncEngine(salesService: service, repository: repo);

      final outcome = await customEngine.drain();

      expect(outcome.synced, 1);
      expect(repo.createCalls, 1);
    });
  });

  test('concurrent drains collapse into one worker (M5.18 #26)',
      () async {
    final id = await recordOfflineSale();

    // Gate the delivery so the first drain stays in flight.
    final gate = Completer<void>();
    var deliveries = 0;
    final gatingRepo = _GatedRepository(gate, () => deliveries++);
    final customEngine =
        SyncEngine(salesService: service, repository: gatingRepo);

    final first = customEngine.drain();
    await Future<void>.delayed(Duration.zero);
    expect(customEngine.isSyncing, true);

    // A second concurrent drain must not start a second worker.
    final second = customEngine.drain();
    gate.complete();
    await Future.wait([first, second]);

    expect(deliveries, 1);
    expect((await service.sales.byClientSaleId(id))!.status,
        LocalSaleStatus.synced);
  });

  test('stale syncing operations recover after crash (M5.18 #23)',
      () async {
    final id = await recordOfflineSale();
    // Simulate a crash mid-flight: op stuck in syncing.
    await service.queue.claimNext(now: DateTime.now().toUtc());
    expect((await _queueRow(db, id)).status, SyncOperationStatus.syncing);

    await service.recoverFromRestart();
    await engine.drain();

    expect((await service.sales.byClientSaleId(id))!.status,
        LocalSaleStatus.synced);
  });
}

class _GatedRepository extends ServerSimulatingRepository {
  _GatedRepository(this._gate, this._onDeliver);
  final Completer<void> _gate;
  final void Function() _onDeliver;

  @override
  Future<SaleDto> create({
    required Map<String, dynamic> body,
    required String idempotencyKey,
  }) async {
    _onDeliver();
    await _gate.future;
    return super.create(body: body, idempotencyKey: idempotencyKey);
  }
}

class _NullPriceRepository extends ServerSimulatingRepository {
  int createCalls = 0;

  @override
  Future<ResolvedPrice?> resolvePrice(
    String productId, {
    double quantity = 1,
    String? branchId,
  }) async =>
      null;

  @override
  Future<SaleDto> create({
    required Map<String, dynamic> body,
    required String idempotencyKey,
  }) async {
    createCalls++;
    return super.create(body: body, idempotencyKey: idempotencyKey);
  }
}

class _PricedRepository extends ServerSimulatingRepository {
  _PricedRepository(this.price);
  final double price;
  int createCalls = 0;

  @override
  Future<ResolvedPrice?> resolvePrice(
    String productId, {
    double quantity = 1,
    String? branchId,
  }) async =>
      ResolvedPrice(price: price, currency: 'TZS');

  @override
  Future<SaleDto> create({
    required Map<String, dynamic> body,
    required String idempotencyKey,
  }) async {
    createCalls++;
    return super.create(body: body, idempotencyKey: idempotencyKey);
  }
}

Future<dynamic> _queueRow(LocalDatabase db, String operationId) async {
  final rows = await db.select(db.syncQueue).get();
  return rows.firstWhere((r) => r.operationId == operationId);
}
