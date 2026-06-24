import 'package:drift/drift.dart';

import '../../database/app_database.dart';

class SalesRepository {
  final AppDatabase db;

  const SalesRepository(this.db);

  Stream<List<Sale>> watchRecent() {
    return (db.select(db.sales)
          ..orderBy([(row) => OrderingTerm.desc(row.saleDate)]))
        .watch();
  }

  Future<List<Sale>> getAll() {
    return (db.select(db.sales)
          ..orderBy([(row) => OrderingTerm.desc(row.saleDate)]))
        .get();
  }

  Future<int> saveSale(SalesCompanion sale) {
    return db.into(db.sales).insertOnConflictUpdate(sale);
  }

  Future<void> saveSaleItems(List<SaleItemsCompanion> items) {
    return db.batch((batch) {
      batch.insertAll(db.saleItems, items);
    });
  }
}
