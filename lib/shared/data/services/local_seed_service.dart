import '../../database/app_database.dart';
import '../../database/database_seeder.dart';

class LocalSeedService {
  final AppDatabase db;

  const LocalSeedService(this.db);

  Future<void> seedCoreLookups() {
    return DatabaseSeeder(db).seedBaseLookupData();
  }
}
