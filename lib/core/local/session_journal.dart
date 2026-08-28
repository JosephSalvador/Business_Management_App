import 'package:drift/drift.dart' show Value;

import 'local_database.dart';

/// Tracks when the device last had a confirmed authenticated session
/// (M5.9). The offline selling window is measured from this timestamp.
class SessionJournal {
  SessionJournal(this._db);

  static const _lastAuthKey = 'last_auth_success_at';
  static const _offlineWindow = Duration(hours: 72);

  final LocalDatabase _db;

  Future<void> markAuthenticated() async {
    final now = DateTime.now().toUtc();
    await _db.into(_db.metaEntries).insertOnConflictUpdate(MetaEntriesCompanion(
      key: const Value(_lastAuthKey),
      value: Value(now.toIso8601String()),
      updatedAt: Value(now),
    ));
  }

  /// True while offline selling is still allowed. A never-authenticated
  /// device cannot sell offline at all.
  Future<bool> offlineWindowOpen({Duration window = _offlineWindow}) async {
    final row = await (_db.select(_db.metaEntries)
          ..where((t) => t.key.equals(_lastAuthKey)))
        .getSingleOrNull();
    if (row == null) {
      return false;
    }
    final last = DateTime.tryParse(row.value)?.toUtc();
    if (last == null) {
      return false;
    }
    return DateTime.now().toUtc().isBefore(last.add(window));
  }

  Future<DateTime?> lastAuthenticatedAt() async {
    final row = await (_db.select(_db.metaEntries)
          ..where((t) => t.key.equals(_lastAuthKey)))
        .getSingleOrNull();
    if (row == null) {
      return null;
    }
    return DateTime.tryParse(row.value)?.toUtc();
  }
}
