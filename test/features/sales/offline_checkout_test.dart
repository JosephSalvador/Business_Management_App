import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jolinx_app/app/providers.dart';
import 'package:jolinx_app/core/storage/local_database.dart';
import 'package:jolinx_app/core/storage/session_journal.dart';
import 'package:jolinx_app/core/storage/tables.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/core/sync/local_sales_service.dart';
import 'package:jolinx_app/features/authentication/application/auth_controller.dart';
import 'package:jolinx_app/features/authentication/domain/session.dart';
import 'package:jolinx_app/features/sales/data/branch_cache.dart';
import 'package:jolinx_app/features/sales/data/offline_sale_recorder.dart';
import 'package:jolinx_app/features/sales/domain/sale.dart';

import 'checkout_controller_test.dart' show FakeSaleRepository;

/// A controllable session journal for tests.
class _TestJournal extends SessionJournal {
  _TestJournal(super.db);

  bool _windowOpen = true;

  void setWindowOpen(bool open) => _windowOpen = open;

  @override
  Future<bool> offlineWindowOpen({Duration? window}) async => _windowOpen;
}

/// Branch cache with no platform storage behind it: always empty, so the
/// controller falls through to the overridden [posBranchIdProvider].
class _FakeBranchCache extends BranchCache {
  @override
  Future<String?> getCached() async => null;

  @override
  Future<void> store({required String branchId, String? branchName}) async {}
}

/// Always-authenticated controller: the offline permission check needs a
/// live session holding `sale.create` without bootstrapping AppConfig.
class _FakeAuthController extends AuthController {
  @override
  AuthState build() => AuthAuthenticated(_offlineSession());
}

Session _offlineSession() => Session(
      user: const AuthUser(
        id: 'user-1',
        tenantId: 'tenant-1',
        email: 'cashier@test.local',
        fullName: 'Test Cashier',
        phone: null,
        isActive: true,
        emailVerified: true,
        permissions: ['sale.create'],
      ),
      accessTokenExpiresAt: DateTime.now().add(const Duration(hours: 1)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalDatabase db;
  late LocalSalesService service;
  late _TestJournal journal;

  setUp(() {
    db = LocalDatabase(NativeDatabase.memory());
    service = LocalSalesService(database: db);
    journal = _TestJournal(db);
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

  ProviderContainer buildContainer({
    required FakeSaleRepository sales,
    required OfflineSaleRecorder offline,
    Future<String?> Function()? branch,
  }) =>
      ProviderContainer(overrides: [
        saleRepositoryProvider.overrideWithValue(sales),
        offlineSaleRecorderProvider.overrideWithValue(offline),
        sessionJournalProvider.overrideWithValue(journal),
        posBranchIdProvider
            .overrideWithValue(branch ?? (() async => 'branch-1')),
        branchCacheProvider.overrideWithValue(_FakeBranchCache()),
        authControllerProvider.overrideWith(() => _FakeAuthController()),
      ]);

  test('network failure records the SAME id locally and succeeds', () async {
    await seedStock(50);
    final sales = FakeSaleRepository(createError: NetworkException());
    final offline = recorder();
    final container = buildContainer(sales: sales, offline: offline);
    addTearDown(container.dispose);
    final controller = container.read(checkoutControllerProvider.notifier);

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
    final container = buildContainer(sales: sales, offline: offline);
    addTearDown(container.dispose);
    final controller = container.read(checkoutControllerProvider.notifier);

    final result = await controller.submit(
      lines: [line()],
      paymentMethod: 1,
    );

    expect(result!.pendingLocally, true);
    expect(sales.idempotencyKeys.single, result.id,
        reason: 'server may hold this exact sale; replay must dedupe at sync');
  });

  test('stalled backend falls back to the local queue after the deadline',
      () async {
    await seedStock(50);
    final sales = FakeSaleRepository(stall: Completer<void>().future);
    final offline = recorder();
    final container = buildContainer(sales: sales, offline: offline);
    addTearDown(container.dispose);
    final controller = container.read(checkoutControllerProvider.notifier);

    final result = await controller.submit(
      lines: [line()],
      paymentMethod: 1,
    );

    expect(result, isNotNull);
    expect(result!.pendingLocally, true,
        reason: 'a slow-but-alive backend must still land on the receipt');
    expect(sales.createCalls, 1,
        reason: 'the online attempt must start before the deadline fires');
    // The recorded local key equals the key the (still-running) online
    // attempt used, so a late server accept cannot produce a second sale.
    expect(sales.idempotencyKeys.single, result.id);
    final pending = await service.sales.byStatus(LocalSaleStatus.pending);
    expect(pending, hasLength(1));
    expect(pending.single.clientSaleId, result.id);
  });

  test('expired offline window blocks selling with a clear message', () async {
    final sales = FakeSaleRepository(createError: NetworkException());
    final offline = recorder();
    journal.setWindowOpen(false);
    final container = buildContainer(sales: sales, offline: offline);
    addTearDown(container.dispose);
    final controller = container.read(checkoutControllerProvider.notifier);

    final result = await controller.submit(
      lines: [line()],
      paymentMethod: 0,
    );

    expect(result, isNull);
    expect(await service.pendingSaleCount(), 0);
  });

  test('local stock guard refuses to oversell the projected balance', () async {
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
    final container = buildContainer(sales: sales, offline: offline);
    addTearDown(container.dispose);
    final controller = container.read(checkoutControllerProvider.notifier);

    final result = await controller.submit(
      lines: [line(quantity: 10)],
      paymentMethod: 0,
    );

    expect(result, isNull);
    expect(await service.pendingSaleCount(), 0,
        reason: 'nothing is written when the guard trips');
  });

  test('quick-sale line skips the stock guard (services hold no stock)',
      () async {
    final sales = FakeSaleRepository(createError: NetworkException());
    final offline = recorder();
    final container = buildContainer(sales: sales, offline: offline);
    addTearDown(container.dispose);
    final controller = container.read(checkoutControllerProvider.notifier);

    final result = await controller.submit(
      lines: [
        CartLine(
          productId: 'p-quick',
          name: 'Uza Haraka',
          unitPrice: 15000,
          unitPriceOverride: 15000,
          key: 'quick-1',
        ),
      ],
      paymentMethod: 0,
    );

    expect(result, isNotNull);
    expect(result!.pendingLocally, true);
    expect(result.totalAmount, 15000);

    final pending = await service.sales.byStatus(LocalSaleStatus.pending);
    expect(pending, hasLength(1));
  });
}
