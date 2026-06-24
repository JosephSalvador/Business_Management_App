import 'package:drift/drift.dart';

import '../../database/app_enums.dart';
import '../../database/app_database.dart';

class ProductCategoryRepository {
  final AppDatabase db;

  const ProductCategoryRepository(this.db);

  Stream<List<ProductCategory>> watchAll() => db.select(db.productCategories).watch();

  Future<List<ProductCategory>> getAll() => db.select(db.productCategories).get();

  Future<int> upsert(ProductCategoriesCompanion category) {
    return db.into(db.productCategories).insertOnConflictUpdate(category);
  }
}

class ProductUnitRepository {
  final AppDatabase db;

  const ProductUnitRepository(this.db);

  Stream<List<ProductUnit>> watchAll() => db.select(db.productUnits).watch();

  Future<List<ProductUnit>> getAll() => db.select(db.productUnits).get();

  Future<int> upsert(ProductUnitsCompanion unit) {
    return db.into(db.productUnits).insertOnConflictUpdate(unit);
  }
}

class ProductRepository {
  final AppDatabase db;

  const ProductRepository(this.db);

  Stream<List<Product>> watchAll() => db.select(db.products).watch();

  Future<List<Product>> getAll() => db.select(db.products).get();

  Future<Product?> findById(String id) {
    return (db.select(db.products)..where((row) => row.id.equals(id)))
        .getSingleOrNull();
  }

  Future<int> upsert(ProductsCompanion product) {
    return db.into(db.products).insertOnConflictUpdate(product);
  }

  Future<int> softDelete(String id) {
    return (db.update(db.products)..where((row) => row.id.equals(id))).write(
      ProductsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        syncStatus: const Value(SyncStatus.pendingSync),
      ),
    );
  }
}
