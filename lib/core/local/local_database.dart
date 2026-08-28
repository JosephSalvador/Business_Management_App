import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart' show Database;

import 'tables.dart';

part 'local_database.g.dart';

/// On Android the SQLCipher build ships as `libsqlcipher.so`, so the plain
/// `libsqlite3.so` lookup fails. Point the sqlite3 loader at SQLCipher.
///
/// IMPORTANT: `open.overrideFor` is PER-ISOLATE. [NativeDatabase.createInBackground]
/// opens the database in a worker isolate, so the override must be installed
/// there too — see [isolateSetup] in [_openExecutor].
void _configureSqliteLoader() {
  if (Platform.isAndroid) {
    open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
  }
}

@DriftDatabase(tables: [
  MetaEntries,
  CachedProducts,
  CachedStock,
  LocalSales,
  LocalSaleLines,
  LocalPayments,
  SyncQueue,
])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase(super.e);

  /// Opens the encrypted app database. The SQLCipher key comes exclusively
  /// from [keyProvider] (secure storage) — never from constants or files.
  static Future<LocalDatabase> open({
    required Future<String> Function() keyProvider,
  }) async {
    _configureSqliteLoader();
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'jolinx.pos.db'));
    final key = await keyProvider();
    return LocalDatabase(_openExecutor(file, key));
  }

  static QueryExecutor _openExecutor(File file, String? key) {
    return NativeDatabase.createInBackground(
      file,
      // Runs INSIDE the background isolate before it opens the database —
      // this is where the SQLCipher loader override must be installed.
      isolateSetup: _configureSqliteLoader,
      setup: (raw) {
        if (key != null && key.isNotEmpty) {
          raw.execute("PRAGMA key = '$key';");
        }
        raw.execute('PRAGMA foreign_keys = ON;');
        if (!_hasCipher(raw)) {
          debugPrint(
            'WARNING: SQLCipher not available on this platform; '
            'database is unencrypted.',
          );
        }
      },
    );
  }

  /// `PRAGMA cipher_version` returns a row only on SQLCipher builds. On plain
  /// SQLite the `PRAGMA key` above is silently ignored, so we surface that
  /// state loudly instead of pretending data is encrypted.
  static bool _hasCipher(Database raw) {
    try {
      final result = raw.select('PRAGMA cipher_version;');
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
      );
}
