
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:business_management_system/core/local/local_database.dart';
import 'package:business_management_system/core/local/tables.dart';
import 'package:business_management_system/core/network/app_exception.dart';
import 'package:business_management_system/features/sales/application/checkout_controller.dart';
import 'package:business_management_system/features/sales/application/local_sales_service.dart';
import 'package:business_management_system/features/sales/application/offline_sale_recorder.dart';
import 'package:business_management_system/features/sales/domain/sale.dart';

import 'checkout_controller_test.dart' show FakeSaleRepository;

void main() {
  late LocalDatabase db;
  late LocalSalesService service;

  setUp(() {
    db = LocalDatabase(NativeDatabase.memory());
    service = LocalSalesService(database: db);
  });

  /// Seeds cached stock so the conservative guard lets normal sales through.
  Future<void> seedStock(double qty) async {
    await service.catalog.replaceCatalog(
      tenantId: 'tenant-1',
      products: const [],
      stock: [
        CachedStockCompanion.insert(
          tenantId: 'tenant-1',
          productId: 'p-1',
          warehouseId: '*',
          quantity: qty,
          fetchedAt: DateTime.now().toUtc(),
        ),
      ],
    );
  }

  tearDown(() async => db.close());

  OfflineSaleRecorder recorder({
    bool windowOpen = true,
    Future<String?> Function()? branch,
  }) =>
      OfflineSaleRecorder(
        salesDao: service.sales,
        catalogDao: service.catalog,
        tenantIdOf: () async => 'tenant-1',
        deviceIdOf: () async => 'device-1',
        userIdOf: () async => 'user-1',
        branchIdOf: branch ?? (() async => 'branch-1'),
      );

  CartLine line({double quantity = 1}) => CartLine(
        productId: 'p-1',
        name: 'Mchele',
        unitPrice: 2500,
        quantity: quantity,
      );

  CheckoutController buildController({
    required FakeSaleRepository sales,
    required OfflineSaleRecorder offline,
    bool windowOpen = true,
  }) =>
      CheckoutController(
        sales,
        () async => 'branch-1',
        offlineRecorder: offline,
        offlineWindowOpen: () async => windowOpen,
      );

  test('network failure records the SAME id locally and succeeds', () async {
    await seedStock(50);
    final sales = FakeSaleRepository(createError: NetworkException());
    final offline = recorder();
    final controller =
        buildController(sales: sales, offline: offline);

    final result = await controller.submit(
      lines: [line()],
      paymentMethod: 0,
    );

    expect(result, isNotNull);
    expect(result!.pendingLocally, true);
    // The attempted online key equals the recorded local key.
    expect(sales.idempotencyKeys.single, result.id);

    final pending = await service.sales.byStatus(LocalSaleStatus.pending);
    expect(pending, hasLength(1));
    expect(pending.single.clientSaleId, result.id);
    expect(pending.single.deviceId, 'device-1');
    expect(pending.single.userId, 'user-1');
  });

  test('timeout mid-submit also falls back to the local queue', () async {
    await seedStock(50);
    final sales = FakeSaleRepository(createError: TimeoutException());
    final offline = recorder();
    final controller =
        buildController(sales: sales, offline: offline);

    final result = await controller.submit(
      lines: [line()],
      paymentMethod: 1,
    );

    expect(result!.pendingLocally, true);
    expect(sales.idempotencyKeys.single, result.id,
        reason:
            'server may hold this exact sale; replay must dedupe at sync');
  });

  test('expired offline window blocks selling with a clear message',
      () async {
    final sales = FakeSaleRepository(createError: NetworkException());
    final offline = recorder(windowOpen: false);
    final controller = buildController(
      sales: sales,
      offline: offline,
      windowOpen: false,
    );

    final result = await controller.submit(
      lines: [line()],
      paymentMethod: 0,
    );

    expect(result, isNull);
    expect(await service.pendingSaleCount(), 0);
  });

  test('local stock guard refuses to oversell the projected balance',
      () async {
    await service.catalog.replaceCatalog(
      tenantId: 'tenant-1',
      products: const [],
      stock: [
        CachedStockCompanion.insert(
          tenantId: 'tenant-1',
          productId: 'p-1',
          warehouseId: '*',
          quantity: 5,
          fetchedAt: DateTime.now().toUtc(),
        ),
      ],
    );

    final sales = FakeSaleRepository(createError: NetworkException());
    final offline = recorder();
    final controller =
        buildController(sales: sales, offline: offline);

    final result = await controller.submit(
      lines: [line(quantity: 10)],
      paymentMethod: 0,
    );

    expect(result, isNull);
    expect(await service.pendingSaleCount(), 0,
        reason: 'nothing is written when the guard trips');
  });
}
