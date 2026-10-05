import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/app/providers.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/features/products/application/catalog_controller.dart';
import 'package:jolinx_app/features/products/application/products_controller.dart';
import 'package:jolinx_app/features/products/data/product_repository.dart';
import 'package:jolinx_app/features/products/domain/catalog.dart';
import 'package:jolinx_app/features/products/domain/product.dart';

class FakeProductRepository implements ProductRepository {
  FakeProductRepository();

  List<Product> products = [];
  List<UnitOfMeasure> unitRows = [];
  List<TaxCategory> taxCategoryRows = [];
  List<Category> categoryRows = [];
  List<Brand> brandRows = [];
  List<Warehouse> warehouseRows = const [
    Warehouse(id: 'w1', name: 'Main Store', code: 'MAINSTORE'),
  ];
  Map<String, double> openingQuantities = {};
  PriceList? defaultPriceListRow = const PriceList(
    id: 'pl1',
    name: 'Retail Prices',
    currency: 'TZS',
    isDefault: true,
  );
  final Map<String, double> retailPrices = {};
  final Map<String, double> wholesalePrices = {};
  Object? createError;

  int unitsCreated = 0;
  ProductDraft? lastDraft;
  double? lastPrice;
  double? lastWholesalePrice;
  OpeningStockEntry? lastOpening;
  AdjustStockEntry? lastAdjustment;

  @override
  Future<PagedProducts> list(
      {int page = 1, int pageSize = 50, String? search}) async {
    var items = products;
    if (search != null && search.isNotEmpty) {
      items = items
          .where((p) => p.name.toLowerCase().contains(search.toLowerCase()))
          .toList();
    }
    return PagedProducts(items: items, total: items.length);
  }

  @override
  Future<Product> getById(String id) async =>
      products.singleWhere((p) => p.id == id);

  @override
  Future<Product> create(ProductDraft draft) async {
    final error = createError;
    if (error != null) {
      throw error;
    }
    lastDraft = draft;
    final product = Product(
      id: 'p${products.length + 1}',
      name: draft.name,
      unitOfMeasureId: draft.unitOfMeasureId,
      productType: draft.productType,
      status: ProductStatus.active,
      taxCategoryId: draft.taxCategoryId,
      sku: draft.sku,
    );
    products = [...products, product];
    return product;
  }

  @override
  Future<Product> update(String id, ProductDraft draft) async {
    lastDraft = draft;
    final index = products.indexWhere((p) => p.id == id);
    final updated = Product(
      id: id,
      name: draft.name,
      unitOfMeasureId: draft.unitOfMeasureId,
      productType: draft.productType,
      status: products[index].status,
      taxCategoryId: draft.taxCategoryId,
      sku: draft.sku,
    );
    products = [...products]..[index] = updated;
    return updated;
  }

  @override
  Future<List<UnitOfMeasure>> units() async => unitRows;

  @override
  Future<UnitOfMeasure> createUnit(String name, String abbreviation) async {
    unitsCreated++;
    final unit = UnitOfMeasure(
      id: 'u$unitsCreated',
      name: name,
      abbreviation: abbreviation,
    );
    unitRows = [...unitRows, unit];
    return unit;
  }

  @override
  Future<List<TaxCategory>> taxCategories() async => taxCategoryRows;

  @override
  Future<List<Category>> categories() async => categoryRows;

  @override
  Future<List<Brand>> brands() async => brandRows;

  @override
  Future<List<Warehouse>> warehouses() async => warehouseRows;

  @override
  Future<List<StockBalance>> balances() async => [
        for (final entry in openingQuantities.entries)
          StockBalance(
            warehouseId: 'w1',
            productId: entry.key,
            quantity: entry.value,
          ),
      ];

  @override
  Future<StockBalance> recordOpeningStock(OpeningStockEntry entry) async {
    lastOpening = entry;
    openingQuantities = {...openingQuantities, entry.productId: entry.quantity};
    return StockBalance(
      warehouseId: entry.warehouseId,
      productId: entry.productId,
      quantity: entry.quantity,
    );
  }

  @override
  Future<StockBalance> adjustStock(AdjustStockEntry entry) async {
    lastAdjustment = entry;
    openingQuantities = {
      ...openingQuantities,
      entry.productId: entry.quantityDelta,
    };
    return StockBalance(
      warehouseId: entry.warehouseId,
      productId: entry.productId,
      quantity: entry.quantityDelta,
    );
  }

  @override
  Future<PriceList?> defaultPriceList() async => defaultPriceListRow;

  @override
  Future<List<ProductPrice>> prices(String priceListId) async => [
        for (final entry in retailPrices.entries)
          ProductPrice(
            id: 'row-${entry.key}',
            productId: entry.key,
            priceType: 0,
            price: entry.value,
            currency: 'TZS',
          ),
        for (final entry in wholesalePrices.entries)
          ProductPrice(
            id: 'wrow-${entry.key}',
            productId: entry.key,
            priceType: 1,
            price: entry.value,
            currency: 'TZS',
          ),
      ];

  @override
  Future<void> setSellingPrice({
    required PriceList priceList,
    required String productId,
    required double price,
    int priceType = 0,
  }) async {
    lastPrice = price;
    if (priceType == 1) {
      lastWholesalePrice = price;
      wholesalePrices[productId] = price;
    } else {
      retailPrices[productId] = price;
    }
  }
}

void main() {
  group('CatalogController', () {
    test('creates starter units when the tenant has none', () async {
      final repository = FakeProductRepository();
      final container = ProviderContainer(overrides: [
        productRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(catalogControllerProvider.notifier);

      await controller.load();

      expect(repository.unitsCreated, greaterThanOrEqualTo(4));
      final state = controller.state as CatalogReady;
      expect(state.units.map((u) => u.name), contains('Kipande'));
      expect(state.defaultWarehouse!.name, 'Main Store');
    });

    test('keeps existing units and reports readiness', () async {
      final repository = FakeProductRepository()
        ..unitRows = [
          const UnitOfMeasure(id: 'u9', name: 'Kilo', abbreviation: 'kg')
        ];
      final container = ProviderContainer(overrides: [
        productRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(catalogControllerProvider.notifier);

      await controller.load();

      expect(controller.state, isA<CatalogReady>());
    });

    test('exposes categories and brands for the product form', () async {
      final repository = FakeProductRepository()
        ..categoryRows = [const Category(id: 'c1', name: 'Pamba')]
        ..brandRows = [const Brand(id: 'b1', name: 'Jamaa')];
      final container = ProviderContainer(overrides: [
        productRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(catalogControllerProvider.notifier);

      await controller.load();

      final state = controller.state as CatalogReady;
      expect(state.categories.single.id, 'c1');
      expect(state.brands.single.id, 'b1');
    });
  });

  group('ProductsController', () {
    test('create persists the product and its selling price, then reloads',
        () async {
      final repository = FakeProductRepository();
      final container = ProviderContainer(overrides: [
        productRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(productsControllerProvider.notifier);
      await controller.load();

      final created = await controller.create(
        const ProductDraft(name: 'Mchele', unitOfMeasureId: 'u1'),
        2500,
      );

      expect(created.isActive, isTrue);
      expect(repository.retailPrices[created.id], 2500);
      final state = controller.state as ProductsLoaded;
      expect(state.total, 1);
      expect(state.prices[created.id], 2500);
    });

    test('create also persists an optional wholesale price', () async {
      final repository = FakeProductRepository();
      final container = ProviderContainer(overrides: [
        productRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(productsControllerProvider.notifier);
      await controller.load();

      final created = await controller.create(
        const ProductDraft(name: 'Sukari', unitOfMeasureId: 'u1'),
        3000,
        wholesalePrice: 2800,
      );

      expect(repository.retailPrices[created.id], 3000);
      expect(repository.wholesalePrices[created.id], 2800);
      expect(repository.lastWholesalePrice, 2800);
      final state = controller.state as ProductsLoaded;
      expect(state.prices[created.id], 3000);
    });

    test('update persists retail and wholesale prices together', () async {
      final repository = FakeProductRepository();
      final container = ProviderContainer(overrides: [
        productRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(productsControllerProvider.notifier);
      await controller.create(
        const ProductDraft(name: 'Mchele', unitOfMeasureId: 'u1'),
        null,
      );

      await controller.update(
        'p1',
        const ProductDraft(name: 'Mchele', unitOfMeasureId: 'u1'),
        900,
        wholesalePrice: 800,
      );

      expect(repository.retailPrices['p1'], 900);
      expect(repository.wholesalePrices['p1'], 800);
    });

    test('create without a default price list still succeeds', () async {
      final repository = FakeProductRepository()..defaultPriceListRow = null;
      final container = ProviderContainer(overrides: [
        productRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(productsControllerProvider.notifier);
      await controller.load();

      final created = await controller.create(
        const ProductDraft(name: 'Mchele', unitOfMeasureId: 'u1'),
        2500,
      );

      expect(created.isActive, isTrue);
      expect(repository.lastPrice, isNull);
    });

    test('backend conflict surfaces as an exception, state untouched',
        () async {
      final repository = FakeProductRepository()
        ..createError = ConflictException('SKU already exists.');
      final container = ProviderContainer(overrides: [
        productRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(productsControllerProvider.notifier);
      await controller.load();
      final before = controller.state;

      await expectLater(
        controller.create(
          const ProductDraft(name: 'Dup', unitOfMeasureId: 'u1'),
          null,
        ),
        throwsA(isA<ConflictException>()),
      );

      expect(controller.state, same(before));
    });

    test('update refreshes the list with the previous search applied',
        () async {
      final repository = FakeProductRepository();
      final container = ProviderContainer(overrides: [
        productRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(productsControllerProvider.notifier);
      await controller.create(
        const ProductDraft(name: 'Mchele', unitOfMeasureId: 'u1'),
        null,
      );
      await controller.create(
        const ProductDraft(name: 'Sukari', unitOfMeasureId: 'u1'),
        null,
      );
      await controller.load(search: 'mchele');

      await controller.update(
        'p1',
        const ProductDraft(name: 'Mchele wa Tanga', unitOfMeasureId: 'u1'),
        900,
      );

      final state = controller.state as ProductsLoaded;
      expect(state.search, 'mchele');
      expect(state.items.single.name, 'Mchele wa Tanga');
      expect(state.prices['p1'], 900);
    });
  });
}
