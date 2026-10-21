import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/app/providers.dart';
import 'package:jolinx_app/core/storage/local_database.dart';
import 'package:jolinx_app/core/storage/local_sales_dao.dart';
import 'package:jolinx_app/core/sync/local_sales_service.dart';
import 'package:jolinx_app/features/sales/data/sales_providers.dart';

import 'sync_engine_test.dart' show ServerSimulatingRepository;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalDatabase db;
  late LocalSalesService service;
  late ServerSimulatingRepository repository;

  setUp(() {
    db = LocalDatabase(NativeDatabase.memory());
    service = LocalSalesService(database: db);
    repository = ServerSimulatingRepository();
  });

  tearDown(() async {
    await db.close();
  });

  Future<RecordedOfflineSale> recordTestSale({
    String? clientSaleId,
    double total = 5000,
  }) {
    return service.sales.recordOfflineSale(
      clientSaleIdOverride: clientSaleId,
      tenantId: 'tenant-1',
      branchId: 'branch-1',
      deviceId: 'dev-1',
      userId: 'usr-1',
      paymentMethod: 0,
      subtotalEstimate: total,
      taxEstimate: 0,
      totalEstimate: total,
      lines: [
        const OfflineSaleLineInput(
          productId: 'p-1',
          productName: 'Unga',
          quantity: 2,
          unitPriceSnapshot: 2500,
        ),
      ],
    );
  }

  test('SyncStatusController populates pending count and sales list', () async {
    await recordTestSale(clientSaleId: 'sale-001', total: 5000);
    await recordTestSale(clientSaleId: 'sale-002', total: 7500);

    final container = ProviderContainer(overrides: [
      localDatabaseProvider.overrideWithValue(db),
      localSalesServiceProvider.overrideWithValue(service),
      saleRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);

    final controller = container.read(syncStatusProvider.notifier);
    await controller.refresh();

    final state = container.read(syncStatusProvider);
    expect(state.pendingCount, 2);
    expect(state.conflictCount, 0);
    expect(state.pendingSales, hasLength(2));
    expect(state.pendingSales.first.clientSaleId, 'sale-001');
    expect(state.pendingSales.last.clientSaleId, 'sale-002');
  });

  test('SyncStatusController populates conflicts and triggers sync', () async {
    final sale = await recordTestSale(clientSaleId: 'sale-err', total: 3000);
    await service.markSaleConflict(
      clientSaleId: sale.clientSaleId,
      errorCode: 'INSUFFICIENT_STOCK',
      errorMessage: 'Kiasi cha bidhaa hakitoshi.',
    );

    final container = ProviderContainer(overrides: [
      localDatabaseProvider.overrideWithValue(db),
      localSalesServiceProvider.overrideWithValue(service),
      saleRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);

    final controller = container.read(syncStatusProvider.notifier);
    await controller.refresh();

    var state = container.read(syncStatusProvider);
    expect(state.conflictCount, 1);
    expect(state.conflictSales, hasLength(1));
    expect(state.conflictSales.single.errorMessage, 'Kiasi cha bidhaa hakitoshi.');

    // Trigger sync
    await controller.triggerSync();
    state = container.read(syncStatusProvider);
    expect(state.isSyncing, false);
  });
}
