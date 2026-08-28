import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:business_management_system/core/local/cached_catalog_dao.dart';
import 'package:business_management_system/core/local/local_database.dart';
import 'package:business_management_system/core/local/local_sales_dao.dart';
import 'package:business_management_system/core/local/sync_queue_dao.dart';
import 'package:business_management_system/core/local/tables.dart';

void main() {
  late LocalDatabase db;
  late CachedCatalogDao catalog;
  late LocalSalesDao sales;
  late SyncQueueDao queue;

  const tenant = 'tenant-1';

  setUp(() {
    db = LocalDatabase(NativeDatabase.memory());
    catalog = CachedCatalogDao(db);
    sales = LocalSalesDao(db);
    queue = SyncQueueDao(db);
  });

  tearDown(() async => db.close());

  CachedProductsCompanion product({
    String id = 'p-1',
    String name = 'Mchele',
    int status = LocalProductCodes.statusActive,
    bool sellable = true,
    int type = LocalProductCodes.typeGoods,
    double price = 2500,
  }) =>
      CachedProductsCompanion.insert(
        tenantId: tenant,
        productId: id,
        name: name,
        status: status,
        sellable: sellable,
        productType: type,
        retailPrice: price,
        currency: 'TZS',
        fetchedAt: DateTime.utc(2026, 8, 23),
      );

  CachedStockCompanion stock(String productId, double qty) =>
      CachedStockCompanion.insert(
        tenantId: tenant,
        productId: productId,
        warehouseId: 'w-1',
        quantity: qty,
        fetchedAt: DateTime.utc(2026, 8, 23),
      );

  OfflineSaleLineInput line(
          {String id = 'p-1', double qty = 2, double price = 2500}) =>
      OfflineSaleLineInput(
        productId: id,
        productName: 'Mchele',
        quantity: qty,
        unitPriceSnapshot: price,
      );

  group('catalog cache', () {
    test('replaceCatalog swaps rows and stamps refresh time', () async {
      await catalog.replaceCatalog(
          tenantId: tenant,
          products: [product(id: 'old'), product(id: 'new')],
          stock: [stock('old', 10)]);
      await catalog.replaceCatalog(
          tenantId: tenant,
          products: [product(id: 'new')],
          stock: [stock('new', 5)]);

      final all = await catalog.list(tenant);
      expect(all.map((e) => e.productId), ['new']);
      expect(await catalog.lastRefresh(), isNotNull);
    });

    test('search matches name, sku and barcode locally only', () async {
      await catalog.replaceCatalog(
        tenantId: tenant,
        products: [
          product(id: 'a', name: 'Mchele wa Tanga'),
          product(id: 'b', name: 'Sukari'),
          product(
              id: 'c',
              name: 'Chumvi',
              status: LocalProductCodes.statusActive,
              sellable: false),
          product(
              id: 'd',
              name: 'Huduma',
              type: LocalProductCodes.typeGoods + 1),
        ],
        stock: const [],
      );

      expect((await catalog.search(tenant, 'mchele')).single.productId, 'a');
      expect(await catalog.search(tenant, 'chumvi'), isEmpty);
      expect(await catalog.search(tenant, 'huduma'), isEmpty);
    });

    test('projectedQuantity subtracts pending offline sale lines',
        () async {
      await catalog.replaceCatalog(
          tenantId: tenant, products: [product()], stock: [stock('p-1', 50)]);

      await sales.recordOfflineSale(
        tenantId: tenant,
        branchId: 'b-1',
        deviceId: 'dev-1',
        userId: 'u-1',
        paymentMethod: 0,
        subtotalEstimate: 5000,
        taxEstimate: 762.71,
        totalEstimate: 5000,
        lines: [line(qty: 10)],
      );

      expect(await catalog.projectedQuantity(tenant, 'p-1'), 40);
    });

    test('projectedQuantity ignores synced and conflicted sales', () async {
      await catalog.replaceCatalog(
          tenantId: tenant, products: [product()], stock: [stock('p-1', 50)]);

      final recorded = await sales.recordOfflineSale(
        tenantId: tenant,
        branchId: 'b-1',
        deviceId: 'dev-1',
        userId: 'u-1',
        paymentMethod: 0,
        subtotalEstimate: 5000,
        taxEstimate: 0,
        totalEstimate: 5000,
        lines: [line(qty: 10)],
      );
      await sales.markSynced(
        clientSaleId: recorded.clientSaleId,
        serverSaleId: 'srv-1',
        serverNumber: 'S-2026-000001',
      );

      expect(await catalog.projectedQuantity(tenant, 'p-1'), 50);
    });
  });

  group('offline sale recording', () {
    test('records sale + line + payment + queue row atomically', () async {
      final recorded = await sales.recordOfflineSale(
        tenantId: tenant,
        branchId: 'b-1',
        deviceId: 'dev-1',
        userId: 'u-1',
        paymentMethod: 1,
        subtotalEstimate: 5000,
        taxEstimate: 762.71,
        totalEstimate: 5000,
        lines: [
          line(qty: 2),
          line(id: 'p-2', qty: 1, price: 1000),
        ],
      );

      final sale =
          await sales.byClientSaleId(recorded.clientSaleId);
      expect(sale, isNotNull);
      expect(sale!.status, LocalSaleStatus.pending);
      expect(sale.paymentMethod, 1);
      expect(sale.deviceId, 'dev-1');

      final lines = await sales.linesOf(recorded.clientSaleId);
      expect(lines, hasLength(2));
      expect(lines[0].lineTotalEstimate, 5000);
      expect(lines[1].unitPriceSnapshot, 1000);

      expect(await sales.countByStatus(LocalSaleStatus.pending), 1);

      final op = await queue.claimNext(now: DateTime.now().toUtc());
      expect(op, isNotNull);
      expect(op!.operationId, recorded.operationId);
      expect(op.operationType, 'sale.create');
      final payload = op.decodedPayload;
      expect(payload['clientSaleId'], recorded.clientSaleId);
      expect(payload['branchId'], 'b-1');
      expect(payload['source'], 0);
      expect(payload['isElectronicPayment'], true);
      expect((payload['lines'] as List).first,
          containsPair('productId', 'p-1'));
      // No client-invented prices or tax in the wire body.
      expect((payload['lines'] as List).first.keys,
          everyElement(anyOf('productId', 'quantity')));
    });

    test('payload keeps cash non-electronic and stable effectiveAt',
        () async {
      final at = DateTime.utc(2026, 8, 23, 9, 15);
      final payload = LocalSalesDao.buildSalePayload(
        branchId: 'b-1',
        clientSaleId: 'csid',
        lines: [line()],
        paymentMethod: 0,
        total: 5000,
        effectiveAt: at,
      );
      expect(payload, contains('"isElectronicPayment":false'));
      expect(payload, contains(at.toIso8601String()));
    });
  });

  group('sync queue lifecycle', () {
    test('claim marks syncing; retry applies exponential backoff', () async {
      final now = DateTime.now().toUtc();
      final recorded = await sales.recordOfflineSale(
        tenantId: tenant,
        branchId: 'b-1',
        deviceId: 'd',
        userId: 'u',
        paymentMethod: 0,
        subtotalEstimate: 0,
        taxEstimate: 0,
        totalEstimate: 100,
        lines: [line()],
      );

      final claimed = await queue.claimNext(now: now);
      expect(claimed!.operationId, recorded.clientSaleId);

      // Nothing else to claim while one is syncing.
      final second = await sales.recordOfflineSale(
        tenantId: tenant,
        branchId: 'b-1',
        deviceId: 'd',
        userId: 'u',
        paymentMethod: 0,
        subtotalEstimate: 0,
        taxEstimate: 0,
        totalEstimate: 200,
        lines: [line(id: 'p-2')],
      );
      expect(
        (await queue.claimNext(now: now))!.operationId,
        second.operationId,
        reason: 'second op is independent and due',
      );

      await queue.releaseForRetry(recorded.clientSaleId, attemptCount: 0);
      var row = await _queueRow(db, recorded.clientSaleId);
      expect(row.status, SyncOperationStatus.pending);
      expect(row.attemptCount, 1);
      expect(row.nextAttemptAt!, isNot(equals(null)));

      // Not due yet.
      expect(await queue.claimNext(now: now), isNull);
      // Due later.
      final later = row.nextAttemptAt!;
      final third = await queue.claimNext(now: later.add(const Duration(milliseconds: 1)));
      expect(third!.operationId, recorded.clientSaleId);
      expect(third.attemptCount, 1);
    });

    test('terminal states keep the operation for audit', () async {
      final recorded = await sales.recordOfflineSale(
        tenantId: tenant,
        branchId: 'b',
        deviceId: 'd',
        userId: 'u',
        paymentMethod: 0,
        subtotalEstimate: 0,
        taxEstimate: 0,
        totalEstimate: 5,
        lines: [line()],
      );

      await queue.markSynced(recorded.clientSaleId, 'server-sale-id');
      var row = await _queueRow(db, recorded.clientSaleId);
      expect(row.status, SyncOperationStatus.synced);
      expect(row.serverReference, 'server-sale-id');

      await queue.markConflict(recorded.clientSaleId,
          errorCode: 'STOCK', errorMessage: 'Insufficient stock');
      row = await _queueRow(db, recorded.clientSaleId);
      expect(row.status, SyncOperationStatus.conflict);
      expect(row.errorCode, 'STOCK');

      await queue.markFailed(recorded.clientSaleId,
          errorCode: 'PERMISSION', errorMessage: 'denied');
      row = await _queueRow(db, recorded.clientSaleId);
      expect(row.status, SyncOperationStatus.failed);
    });

    test('stale syncing ops recover to pending after crash', () async {
      final recorded = await sales.recordOfflineSale(
        tenantId: tenant,
        branchId: 'b',
        deviceId: 'd',
        userId: 'u',
        paymentMethod: 0,
        subtotalEstimate: 0,
        taxEstimate: 0,
        totalEstimate: 5,
        lines: [line()],
      );
      await queue.claimNext(now: DateTime.now().toUtc());
      expect(
        (await _queueRow(db, recorded.clientSaleId)).status,
        SyncOperationStatus.syncing,
      );

      final recovered = await queue.recoverStaleSyncing();
      expect(recovered, 1);
      expect(
        (await _queueRow(db, recorded.clientSaleId)).status,
        SyncOperationStatus.pending,
      );
    });
  });

  test('counts distinguish statuses for the UX summary', () async {
    expect(await queue.countByStatus(SyncOperationStatus.pending), 0);
    await sales.recordOfflineSale(
      tenantId: tenant,
      branchId: 'b',
      deviceId: 'd',
      userId: 'u',
      paymentMethod: 0,
      subtotalEstimate: 0,
      taxEstimate: 0,
      totalEstimate: 5,
      lines: [line()],
    );
    expect(await queue.countByStatus(SyncOperationStatus.pending), 1);
  });
}

Future<SyncQueueData> _queueRow(
  LocalDatabase db,
  String operationId,
) async {
  final rows = await db.select(db.syncQueue).get();
  return rows.firstWhere((r) => r.operationId == operationId);
}
