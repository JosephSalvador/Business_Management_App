import 'package:drift/drift.dart';

import 'db_executor.dart';
import 'tables.dart';

part 'local_database.g.dart';

@DriftDatabase(tables: [
  MetaEntries,
  CachedProducts,
  CachedStock,
  CachedWarehouses,
  LocalSales,
  LocalSaleLines,
  LocalPayments,
  SyncQueue,
])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase(super.e);

  static Future<LocalDatabase> open({
    required Future<String> Function() keyProvider,
  }) async {
    final executor = await createDbExecutor(keyProvider: keyProvider);
    return LocalDatabase(executor);
  }

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(cachedWarehouses);
          }
        },
      );
}
