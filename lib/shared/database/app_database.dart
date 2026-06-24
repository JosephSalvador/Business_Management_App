import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_enums.dart';
import 'app_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    ProductCategories,
    ProductUnits,
    Products,
    Customers,
    Sales,
    SaleItems,
    Expenses,
    StockMovements,
    AppSettings,
    DeviceIdentities,
    SyncQueueItems,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor}) : super(executor ?? _openConnection());

  factory AppDatabase.test() => AppDatabase(executor: NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final directory = await getApplicationDocumentsDirectory();
      final file = File(p.join(directory.path, 'business_pos.sqlite'));
      return NativeDatabase(file);
    });
  }
}
