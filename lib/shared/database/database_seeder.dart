import 'package:drift/drift.dart';

import 'app_database.dart';

class DatabaseSeeder {
  final AppDatabase db;

  const DatabaseSeeder(this.db);

  Future<void> seedBaseLookupData() async {
    await _seedCategories();
    await _seedUnits();
  }

  Future<void> _seedCategories() async {
    final existing = await db.select(db.productCategories).get();
    if (existing.isNotEmpty) return;

    await db.batch((batch) {
      batch.insertAll(
        db.productCategories,
        [
          ProductCategoriesCompanion.insert(
            id: 'category-general',
            name: 'General',
            code: const Value('GENERAL'),
            description: const Value('Default category'),
            sortOrder: const Value(0),
          ),
        ],
      );
    });
  }

  Future<void> _seedUnits() async {
    final existing = await db.select(db.productUnits).get();
    if (existing.isNotEmpty) return;

    await db.batch((batch) {
      batch.insertAll(
        db.productUnits,
        [
          ProductUnitsCompanion.insert(
            id: 'unit-pcs',
            name: 'pcs',
            symbol: const Value('pcs'),
            description: const Value('Pieces'),
          ),
          ProductUnitsCompanion.insert(
            id: 'unit-box',
            name: 'box',
            symbol: const Value('box'),
            description: const Value('Box'),
          ),
          ProductUnitsCompanion.insert(
            id: 'unit-kg',
            name: 'kg',
            symbol: const Value('kg'),
            description: const Value('Kilogram'),
          ),
          ProductUnitsCompanion.insert(
            id: 'unit-litre',
            name: 'litre',
            symbol: const Value('L'),
            description: const Value('Litre'),
          ),
        ],
      );
    });
  }
}
