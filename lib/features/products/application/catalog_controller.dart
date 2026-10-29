import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/app_exception.dart';
import '../data/product_repository.dart';
import '../domain/catalog.dart';

/// Reference data the product form needs: units, tax categories and the
/// default warehouse. Loaded lazily once per session.
sealed class CatalogState {
  const CatalogState();
}

class CatalogLoading extends CatalogState {
  const CatalogLoading();
}

class CatalogReady extends CatalogState {
  const CatalogReady({
    required this.units,
    required this.taxCategories,
    required this.warehouses,
    required this.categories,
    required this.brands,
  });

  final List<UnitOfMeasure> units;
  final List<TaxCategory> taxCategories;
  final List<Warehouse> warehouses;
  final List<Category> categories;
  final List<Brand> brands;

  /// The default "Main Store" provisioned during business setup. Users never
  /// need to learn the warehouse concept; this is just where stock lives.
  /// Prefers the MAINSTORE code (multi-warehouse safe) with a first fallback.
  Warehouse? get defaultWarehouse {
    if (warehouses.isEmpty) return null;
    return warehouses.firstWhere(
      (w) => w.code.toUpperCase() == 'MAINSTORE',
      orElse: () => warehouses.first,
    );
  }
}

class CatalogFailure extends CatalogState {
  const CatalogFailure(this.message);

  final String message;
}

class CatalogController extends Notifier<CatalogState> {
  static const _starterUnits = [
    (name: 'Kipande', abbreviation: 'kip'),
    (name: 'Kilo', abbreviation: 'kg'),
    (name: 'Lita', abbreviation: 'ltr'),
    (name: 'Gunia', abbreviation: 'bag'),
  ];

  @override
  CatalogState build() => const CatalogLoading();

  ProductRepository get _repository => ref.read(productRepositoryProvider);

  Future<void> load() async {
    state = const CatalogLoading();
    try {
      try {
        await _ensureStarterUnits();
      } catch (_) {}
      final results = await (
        _repository.units(),
        _repository.taxCategories(),
        _repository.warehouses(),
        _repository.categories(),
        _repository.brands(),
      ).wait;
      state = CatalogReady(
        units: results.$1,
        taxCategories: results.$2,
        warehouses: results.$3,
        categories: results.$4,
        brands: results.$5,
      );
    } on AppException {
      state = const CatalogReady(
        units: [
          UnitOfMeasure(id: 'default-uom', name: 'Item', abbreviation: 'Pcs'),
        ],
        taxCategories: [],
        warehouses: [
          Warehouse(
            id: 'default-warehouse',
            code: 'MAINSTORE',
            name: 'Stoo Kuu',
          ),
        ],
        categories: [],
        brands: [],
      );
    } catch (_) {
      state = const CatalogReady(
        units: [
          UnitOfMeasure(id: 'default-uom', name: 'Item', abbreviation: 'Pcs'),
        ],
        taxCategories: [],
        warehouses: [
          Warehouse(
            id: 'default-warehouse',
            code: 'MAINSTORE',
            name: 'Stoo Kuu',
          ),
        ],
        categories: [],
        brands: [],
      );
    }
  }

  /// A brand-new tenant has no units of measure; create the common ones so
  /// the first product form works out of the box. Existing names are kept.
  Future<void> _ensureStarterUnits() async {
    final existing = await _repository.units();
    final names = existing.map((u) => u.name.toLowerCase()).toSet();
    for (final unit in _starterUnits) {
      if (!names.contains(unit.name.toLowerCase())) {
        try {
          await _repository.createUnit(unit.name, unit.abbreviation);
        } on ConflictException {
          // Another session created it first — fine, it exists now.
        }
      }
    }
  }

  void reset() {
    state = const CatalogLoading();
  }
}
