import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' show Database;

QueryExecutor openExecutorSync(File file, String? key) {
  return NativeDatabase.createInBackground(
    file,
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

bool _hasCipher(Database raw) {
  try {
    final result = raw.select('PRAGMA cipher_version;');
    return result.isNotEmpty;
  } catch (_) {
    return false;
  }
}

Future<QueryExecutor> createDbExecutor({
  required Future<String> Function() keyProvider,
}) async {
  final dir = await getApplicationSupportDirectory();
  final file = File(p.join(dir.path, 'jolinx.pos.db'));
  final key = await keyProvider();
  return openExecutorSync(file, key);
}
