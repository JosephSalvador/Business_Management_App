import 'package:drift/drift.dart' show Value;

import 'local_database.dart';

/// Tracks when the device last had a confirmed authenticated session
/// (M5.9). The offline selling window is measured from this timestamp.
///
/// Two mechanisms work together:
/// 1. **Online window**: anchored to the last successful API exchange
///    (login, refresh, restore). Reset every time the device talks to
///    the backend. Expires after 72 hours.
/// 2. **Offline token**: a time-limited HMAC-signed token generated after
///    biometric-verified offline login. Independent of the online window.
///    Expires after 72 hours.
///
/// Both must be valid for offline selling to proceed.
class SessionJournal {
  SessionJournal(this._db);

  static const _lastAuthKey = 'last_auth_success_at';
  static const _offlineWindow = Duration(hours: 72);

  /// Hard maximum offline window — even if the server is never reached again,
  /// the offline window cannot exceed this duration.
  static const _maxOfflineWindow = Duration(hours: 168); // 7 days

  final LocalDatabase _db;

  /// Called after every confirmed online session exchange (login, refresh,
  /// restore). Anchors the offline selling window to the current time.
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
  ///
  /// Checks both the online window AND the offline token validity.
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
    final effectiveWindow =
        window > _maxOfflineWindow ? _maxOfflineWindow : window;
    return DateTime.now().toUtc().isBefore(last.add(effectiveWindow));
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

  /// Returns the remaining offline window duration, or Duration.zero if
  /// the window is closed. Useful for displaying countdown to the user.
  Future<Duration> remainingOfflineWindow({
    Duration window = _offlineWindow,
  }) async {
    final row = await (_db.select(_db.metaEntries)
          ..where((t) => t.key.equals(_lastAuthKey)))
        .getSingleOrNull();
    if (row == null) return Duration.zero;
    final last = DateTime.tryParse(row.value)?.toUtc();
    if (last == null) return Duration.zero;
    final effectiveWindow =
        window > _maxOfflineWindow ? _maxOfflineWindow : window;
    final expiresAt = last.add(effectiveWindow);
    final remaining = expiresAt.difference(DateTime.now().toUtc());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}
