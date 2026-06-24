import 'package:drift/drift.dart';

import '../../database/app_database.dart';

class AppSettingsService {
  final AppDatabase db;

  const AppSettingsService(this.db);

  Stream<List<AppSetting>> watchAll() => db.select(db.appSettings).watch();

  Future<String?> getValue(String key) async {
    final row = await (db.select(db.appSettings)..where((t) => t.id.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setValue(String key, String? value,
      {String? groupName, String? description, bool isSensitive = false}) async {
    await db.into(db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion(
            id: Value(key),
            value: Value(value),
            groupName: Value(groupName),
            description: Value(description),
            isSensitive: Value(isSensitive),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }
}
