import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jolinx_app/app/providers.dart';
import 'package:jolinx_app/core/storage/local_database.dart';
import 'package:jolinx_app/core/sync/local_sales_service.dart';
import 'package:jolinx_app/core/storage/tables.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/core/network/connectivity_monitor.dart';
import 'package:jolinx_app/core/platform/device_info.dart';
import 'package:jolinx_app/app/router.dart';
import 'package:jolinx_app/features/inventory/application/stock_controller.dart';
import 'package:jolinx_app/features/products/data/product_repository.dart';
import 'package:jolinx_app/features/products/domain/product.dart';
import 'package:jolinx_app/features/sales/domain/sale.dart';
import 'package:jolinx_app/features/sales/presentation/pages/pos_page.dart';

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

/// The real StockController pulls a live InventoryRepository (ApiClient →
/// AppConfig) on load; the POS flow does not assert stock rows, so loading
/// is a no-op here.
class _FakeStockController extends StockController {
  @override
  Future<void> load() async {}
}

class _FakeDeviceIdentity extends DeviceIdentity {
  @override
  Future<String> get() async => 'device-test';
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
      localSalesServiceProvider.overrideWithValue(service),
      productRepositoryProvider.overrideWithValue(products),
      saleRepositoryProvider.overrideWithValue(sales),
      sessionContextProvider.overrideWithValue(const ('tenant-1', 'user-1')),
      connectionQualityProvider.overrideWithValue(ConnectionQuality.online),
      posBranchIdProvider.overrideWithValue(() async => 'branch-1'),
      stockControllerProvider.overrideWith(() => _FakeStockController()),
      deviceIdentityProvider.overrideWithValue(_FakeDeviceIdentity()),
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
      // Card price + cart-bar line + cart-bar total.
      expect(find.text('TSh 2,500'), findsNWidgets(3));

      // Open the payment sheet and pay cash.
      await tester.tap(find.widgetWithText(FilledButton, 'Lipa').first);
      await tester.pumpAndSettle();
      // Sheet title + total row both read "Jumla".
      expect(find.text('Jumla'), findsNWidgets(2));
      expect(find.text('Njia ya malipo'), findsOneWidget);

      await tester.tap(find.text('Fedha'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Lipa').last);
      // No pumpAndSettle here: the submitting spinner would never settle.
      // (The best-effort branch-cache read takes up to 2s to time out in
      // tests, where secure storage never answers.)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(seconds: 2));
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
          localSalesServiceProvider.overrideWithValue(service),
          productRepositoryProvider
              .overrideWithValue(_OfflineProductRepository()),
          sessionContextProvider
              .overrideWithValue(const ('tenant-1', 'user-1')),
          connectionQualityProvider
              .overrideWithValue(ConnectionQuality.offline),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    // Compact offline indicator (the long banner was removed in M9.2) +
    // product served purely from cache.
    expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    expect(find.text('Mchele'), findsOneWidget);
    expect(find.text('TSh 2,500'), findsOneWidget);
  });

  testWidgets(
      'advisory stock: zero-stock cached product can still be added to cart',
      (tester) async {
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
          localSalesServiceProvider.overrideWithValue(service),
          productRepositoryProvider
              .overrideWithValue(_OfflineProductRepository()),
          sessionContextProvider
              .overrideWithValue(const ('tenant-1', 'user-1')),
          connectionQualityProvider.overrideWithValue(ConnectionQuality.online),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Imeisha'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Advisory stock: sales always succeed; product is added to cart
    expect(find.text('1 bidhaa'), findsOneWidget);
  });

  testWidgets(
      'quick sale: inline panel commits to the cart live and UZA returns',
      (tester) async {
    final db = LocalDatabase(NativeDatabase.memory());
    final service = LocalSalesService(database: db);

    // Seed the cache with both a normal product and the reserved quick-sale
    // product (QS-BILA-JINA): the offline path resolves its id by SKU, so no
    // network call is needed to open the panel.
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
        CachedProductsCompanion.insert(
          tenantId: 'tenant-1',
          productId: 'p-quick',
          name: 'Uza Haraka',
          sku: const Value(QuickSaleDefaults.sku),
          barcode: const Value(null),
          status: LocalProductCodes.statusActive,
          sellable: false,
          productType: LocalProductCodes.typeGoods,
          retailPrice: 0,
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
          localSalesServiceProvider.overrideWithValue(service),
          productRepositoryProvider
              .overrideWithValue(_OfflineProductRepository()),
          sessionContextProvider
              .overrideWithValue(const ('tenant-1', 'user-1')),
          connectionQualityProvider
              .overrideWithValue(ConnectionQuality.offline),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    // Product grid is showing; open Quick Sale.
    expect(find.text('Mchele'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Uza Haraka'));
    await tester.pumpAndSettle();

    // The inline panel replaces the grid: name + amount fields visible, grid hidden.
    expect(find.text('Jina la bidhaa'), findsOneWidget);
    expect(find.text('Bei'), findsOneWidget);
    expect(find.text('Mchele'), findsNothing);

    // Type a name + amount and stash it with "+ Ongeza nyingine".
    await tester.enterText(find.byType(TextField).at(0), 'Madafu');
    await tester.enterText(find.byType(TextField).at(1), '1000');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Ongeza nyingine'));
    await tester.pump();

    // Cart updated live: bottom bar shows the item and the panel counts it.
    expect(find.text('1 bidhaa'), findsOneWidget);
    expect(find.text('1 zimeongezwa'), findsOneWidget);

    // Second item, then a big UZA commits any leftover and returns to the grid.
    await tester.enterText(find.byType(TextField).at(0), 'Dagaa');
    await tester.enterText(find.byType(TextField).at(1), '2000');
    await tester.tap(find.widgetWithText(FilledButton, 'UZA'));
    await tester.pumpAndSettle();

    expect(find.text('Mchele'), findsOneWidget);
    expect(find.text('2 bidhaa'), findsOneWidget);
  });
}
