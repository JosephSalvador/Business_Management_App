import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import 'local_database.dart';

class OfflineCacheDao {
  OfflineCacheDao(this._db);

  final LocalDatabase _db;
  static const _prefix = 'offline_cache:';

  String _formatKey(String key) => '$_prefix$key';

  Future<void> save(String key, Map<String, dynamic> data) async {
    try {
      final formattedKey = _formatKey(key);
      await _db
          .into(_db.metaEntries)
          .insertOnConflictUpdate(
            MetaEntriesCompanion(
              key: Value(formattedKey),
              value: Value(jsonEncode(data)),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
          )
          .timeout(const Duration(milliseconds: 2000));
    } catch (_) {
      // Offline cache persistence failure is non-fatal; continue silently.
    }
  }

  Future<Map<String, dynamic>?> load(String key) async {
    try {
      final formattedKey = _formatKey(key);
      final row = await (_db.select(_db.metaEntries)
            ..where((t) => t.key.equals(formattedKey)))
          .getSingleOrNull()
          .timeout(const Duration(milliseconds: 1500));

      if (row == null) return null;

      final decoded = jsonDecode(row.value);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<DateTime?> getLastUpdated(String key) async {
    try {
      final formattedKey = _formatKey(key);
      final row = await (_db.select(_db.metaEntries)
            ..where((t) => t.key.equals(formattedKey)))
          .getSingleOrNull()
          .timeout(const Duration(milliseconds: 1500));
      return row?.updatedAt;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear(String key) async {
    try {
      final formattedKey = _formatKey(key);
      await (_db.delete(_db.metaEntries)
            ..where((t) => t.key.equals(formattedKey)))
          .go()
          .timeout(const Duration(milliseconds: 2000));
    } catch (_) {}
  }
}
