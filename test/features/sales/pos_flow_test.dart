import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:business_management_system/core/di/providers.dart';
import 'package:business_management_system/core/local/local_database.dart';
import 'package:business_management_system/core/local/tables.dart';
import 'package:business_management_system/core/network/app_exception.dart';
import 'package:business_management_system/core/network/connectivity_monitor.dart';
import 'package:business_management_system/core/routing/app_router.dart';
import 'package:business_management_system/features/products/data/product_repository.dart';
import 'package:business_management_system/features/products/domain/product.dart';
import 'package:business_management_system/features/sales/application/checkout_controller.dart';
import 'package:business_management_system/features/sales/application/local_sales_service.dart';
import 'package:business_management_system/features/sales/application/pos_catalog_controller.dart';
import 'package:business_management_system/features/sales/application/sales_history_controller.dart';
import 'package:business_management_system/features/sales/domain/sale.dart';
import 'package:business_management_system/features/sales/presentation/pages/pos_page.dart';

import 'checkout_controller_test.dart' show FakeSaleRepository;
import '../products/products_controller_test.dart' show FakeProductRepository;

FakeProductRepository _productsWithRice() {
  final repository = FakeProductRepository()
    ..retailPrices['p1'] = 2500
    ..openingQuantities['p1'] = 50
    ..products = [
      const Product(
        id: 'p1',
        name: 'Mchele',
        unitOfMeasureId: 'u1',
        productType: ProductType.goods,
        status: ProductStatus.active,
      ),
    ];
  return repository;
}

/// Simulates a dead network so catalog refresh fails and the POS serves
/// purely from cache.
class _OfflineProductRepository extends FakeProductRepository {
  @override
  Future<PagedProducts> list(
          {int page = 1, int pageSize = 50, String? search}) =>
      throw NetworkException();
}

Widget _app({
  required FakeProductRepository products,
  required FakeSaleRepository sales,
}) {
  final db = LocalDatabase(NativeDatabase.memory());
  final service = LocalSalesService(database: db);

  final router = GoRouter(
    initialLocation: '/pos-test',
    routes: [
      GoRoute(path: '/pos-test', builder: (_, __) => const PosPage()),
      GoRoute(
        path: Routes.posSuccess,
        builder: (_, state) {
          final sale = state.extra as SaleDto?;
          return Directionality(
            textDirection: TextDirection.ltr,
            child: Scaffold(
              body: Text(
                'DONE ${sale!.number.isEmpty ? 'PENDING' : sale.number} '
                '${sale.totalAmount.toStringAsFixed(0)}',
              ),
            ),
          );
        },
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      localDatabaseProvider.overrideWithValue(db),
      connectionQualityProvider.overrideWithValue(ConnectionQuality.online),
      posCatalogControllerProvider.overrideWith(
        (ref) => PosCatalogController(
          dao: service.catalog,
          repository: products,
          tenantIdOf: () async => 'tenant-1',
        ),
      ),
      checkoutControllerProvider.overrideWith(
        (ref) => CheckoutController(sales, () async => 'branch-1'),
      ),
      salesHistoryControllerProvider.overrideWith(
        (ref) => SalesHistoryController(FakeSaleRepository()),
      ),
      syncStatusProvider
          .overrideWith((ref) => SyncStatusController(service)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets(
    'POS flow: tap product → cart total → Cash → Lipa → success screen',
    (tester) async {
      final sales = FakeSaleRepository();
      await tester.pumpWidget(_app(
        products: _productsWithRice(),
        sales: sales,
      ));
      // First pump: cache is empty; second pass refreshes from the fake API.
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      // The product card shows the cached retail price after refresh.
      expect(find.text('Mchele'), findsOneWidget);
      expect(find.text('TSh 2,500'), findsOneWidget);

      // Tapping adds it to the cart and reveals the cart bar.
      await tester.tap(find.text('Mchele'));
      await tester.pump();
      expect(find.text('1 bidhaa'), findsOneWidget);
      expect(find.text('TSh 2,500'), findsNWidgets(2));

      // Open the payment sheet and pay cash.
      await tester.tap(find.widgetWithText(FilledButton, 'Lipa').first);
      await tester.pumpAndSettle();
      expect(find.text('Jumla'), findsOneWidget);
      expect(find.text('Njia ya malipo:'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cash'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Lipa').last);
      // No pumpAndSettle here: the submitting spinner would never settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      // Success screen replaces the POS with server-truth numbers.
      expect(find.textContaining('DONE S-2026-000001'), findsOneWidget);
      expect(sales.createCalls, 1);
      expect(sales.idempotencyKeys.single, isA<String>());
    },
  );

  testWidgets('offline product appears once cached and stays sellable',
      (tester) async {
    final db = LocalDatabase(NativeDatabase.memory());
    final service = LocalSalesService(database: db);

    // Seed the cache directly: this is what a previous online session left.
    await service.catalog.replaceCatalog(
      tenantId: 'tenant-1',
      products: [
        CachedProductsCompanion.insert(
          tenantId: 'tenant-1',
          productId: 'p1',
          name: 'Mchele',
          status: LocalProductCodes.statusActive,
          sellable: true,
          productType: LocalProductCodes.typeGoods,
          retailPrice: 2500,
          currency: 'TZS',
          fetchedAt: DateTime.now().toUtc(),
        ),
      ],
      stock: [
        CachedStockCompanion.insert(
          tenantId: 'tenant-1',
          productId: 'p1',
          warehouseId: '*',
          quantity: 10,
          fetchedAt: DateTime.now().toUtc(),
        ),
      ],
    );

    final router = GoRouter(
      initialLocation: '/pos-test',
      routes: [
        GoRoute(path: '/pos-test', builder: (_, __) => const PosPage()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(db),
          connectionQualityProvider
              .overrideWithValue(ConnectionQuality.offline),
          posCatalogControllerProvider.overrideWith(
            (ref) => PosCatalogController(
              dao: service.catalog,
              repository: _OfflineProductRepository(),
              tenantIdOf: () async => 'tenant-1',
            ),
          ),
          syncStatusProvider
              .overrideWith((ref) => SyncStatusController(service)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    // Offline banner + product served purely from cache.
    expect(
      find.text('Offline — Mauzo yataendelea. Yatasawazishwa internet ikirudi.'),
      findsOneWidget,
    );
    expect(find.text('Mchele'), findsOneWidget);
    expect(find.text('TSh 2,500'), findsOneWidget);
  });

  testWidgets('out-of-stock cached product cannot be added', (tester) async {
    final db = LocalDatabase(NativeDatabase.memory());
    final service = LocalSalesService(database: db);

    await service.catalog.replaceCatalog(
      tenantId: 'tenant-1',
      products: [
        CachedProductsCompanion.insert(
          tenantId: 'tenant-1',
          productId: 'p-empty',
          name: 'Imeisha',
          sku: const Value(null),
          barcode: const Value(null),
          status: LocalProductCodes.statusActive,
          sellable: true,
          productType: LocalProductCodes.typeGoods,
          retailPrice: 1000,
          currency: 'TZS',
          fetchedAt: DateTime.now().toUtc(),
        ),
      ],
      stock: const [],
    );

    final router = GoRouter(
      initialLocation: '/pos-test',
      routes: [
        GoRoute(path: '/pos-test', builder: (_, __) => const PosPage()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(db),
          connectionQualityProvider.overrideWithValue(ConnectionQuality.online),
          posCatalogControllerProvider.overrideWith(
            (ref) => PosCatalogController(
              dao: service.catalog,
              repository: _OfflineProductRepository(),
              tenantIdOf: () async => 'tenant-1',
            ),
          ),
          syncStatusProvider
              .overrideWith((ref) => SyncStatusController(service)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Imeisha'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Out-of-stock cards do not open the cart at all.
    expect(find.text('1 bidhaa'), findsNothing);
  });
}
