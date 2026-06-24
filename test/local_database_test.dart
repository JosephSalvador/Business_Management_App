import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:business_management_system/shared/database/app_database.dart';
import 'package:business_management_system/shared/database/app_enums.dart';
import 'package:business_management_system/shared/database/database_seeder.dart';
import 'package:business_management_system/shared/data/repositories/catalog_repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Enum converters round-trip sync and product types', () {
    const productTypeConverter = ProductTypeConverter();
    const syncStatusConverter = SyncStatusConverter();

    expect(productTypeConverter.toSql(ProductType.service), 'service');
    expect(productTypeConverter.fromSql('stockItem'), ProductType.stockItem);
    expect(syncStatusConverter.toSql(SyncStatus.pendingSync), 'pendingSync');
    expect(syncStatusConverter.fromSql('synced'), SyncStatus.synced);
  });

  test('Database seeds basic lookup data', () async {
    SharedPreferences.setMockInitialValues({});

    final db = AppDatabase.test();
    addTearDown(db.close);

    await DatabaseSeeder(db).seedBaseLookupData();

    final categories = await ProductCategoryRepository(db).getAll();
    final units = await ProductUnitRepository(db).getAll();

    expect(categories.map((c) => c.name), contains('General'));
    expect(units.map((u) => u.name), containsAll(['pcs', 'box', 'kg', 'litre']));
  });
}
