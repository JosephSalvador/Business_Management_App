import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import 'local_database.dart';

class OfflineCacheDao {
  OfflineCacheDao(this._db);

  final LocalDatabase _db;
  static const _prefix = 'offline_cache:';

  String _formatKey(String key) => '$_prefix$key';

  Future<void> save(String key, Map<String, dynamic> data) async {
    final formattedKey = _formatKey(key);
    await _db.into(_db.metaEntries).insertOnConflictUpdate(
          MetaEntriesCompanion(
            key: Value(formattedKey),
            value: Value(jsonEncode(data)),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<Map<String, dynamic>?> load(String key) async {
    final formattedKey = _formatKey(key);
    final row = await (_db.select(_db.metaEntries)
          ..where((t) => t.key.equals(formattedKey)))
        .getSingleOrNull();

    if (row == null) return null;

    try {
      final decoded = jsonDecode(row.value);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    } on Object {
      return null;
    }
  }

  Future<DateTime?> getLastUpdated(String key) async {
    final formattedKey = _formatKey(key);
    final row = await (_db.select(_db.metaEntries)
          ..where((t) => t.key.equals(formattedKey)))
        .getSingleOrNull();
    return row?.updatedAt;
  }

  Future<void> clear(String key) async {
    final formattedKey = _formatKey(key);
    await (_db.delete(_db.metaEntries)
          ..where((t) => t.key.equals(formattedKey)))
        .go();
  }
}
