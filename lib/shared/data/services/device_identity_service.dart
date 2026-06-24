import 'package:drift/drift.dart';

import '../../database/app_enums.dart';
import '../../database/app_database.dart';

class DeviceIdentityService {
  final AppDatabase db;

  const DeviceIdentityService(this.db);

  Future<DeviceIdentity?> getCurrentIdentity() {
    return db.select(db.deviceIdentities).getSingleOrNull();
  }

  Future<void> saveIdentity(DeviceIdentitiesCompanion identity) async {
    await db.into(db.deviceIdentities).insertOnConflictUpdate(identity);
  }

  Future<void> touch(String id) async {
    await (db.update(db.deviceIdentities)..where((row) => row.id.equals(id))).write(
      DeviceIdentitiesCompanion(
        updatedAt: Value(DateTime.now()),
        lastSeenAt: Value(DateTime.now()),
        syncStatus: const Value(SyncStatus.pendingSync),
      ),
    );
  }
}
