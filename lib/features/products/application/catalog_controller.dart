import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  });

  final List<UnitOfMeasure> units;
  final List<TaxCategory> taxCategories;
  final List<Warehouse> warehouses;

  /// The default "Main Store" provisioned during business setup. Users never
  /// need to learn the warehouse concept; this is just where stock lives.
  Warehouse? get defaultWarehouse =>
      warehouses.isEmpty ? null : warehouses.first;
}

class CatalogFailure extends CatalogState {
  const CatalogFailure(this.message);

  final String message;
}

class CatalogController extends StateNotifier<CatalogState> {
  CatalogController(this._repository) : super(const CatalogLoading());

  static const _starterUnits = [
    (name: 'Kipande', abbreviation: 'kip'),
    (name: 'Kilo', abbreviation: 'kg'),
    (name: 'Lita', abbreviation: 'ltr'),
    (name: 'Gunia', abbreviation: 'bag'),
  ];

  final ProductRepository _repository;

  Future<void> load() async {
    state = const CatalogLoading();
    try {
      await _ensureStarterUnits();
      final results = await (
        _repository.units(),
        _repository.taxCategories(),
        _repository.warehouses(),
      ).wait;
      state = CatalogReady(
        units: results.$1,
        taxCategories: results.$2,
        warehouses: results.$3,
      );
    } on AppException catch (error) {
      state = CatalogFailure(error.message);
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
