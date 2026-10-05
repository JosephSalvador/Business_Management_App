import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../../core/storage/local_database.dart';
import '../../billing/domain/billing.dart';

class CapabilitiesDao {
  CapabilitiesDao(this._db);

  final LocalDatabase _db;
  static const _prefix = 'workspace_capabilities:';

  String _key(String tenantId) => '$_prefix$tenantId';

  Future<void> save(
      String tenantId, SubscriptionEntitlement entitlement) async {
    await _db.into(_db.metaEntries).insertOnConflictUpdate(
          MetaEntriesCompanion(
            key: Value(_key(tenantId)),
            value: Value(jsonEncode(entitlement.toJson())),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<SubscriptionEntitlement?> load(
    String tenantId, {
    DateTime? now,
  }) async {
    final row = await (_db.select(_db.metaEntries)
          ..where((t) => t.key.equals(_key(tenantId))))
        .getSingleOrNull();
    if (row == null) return null;
    try {
      final decoded = jsonDecode(row.value);
      if (decoded is! Map) return null;
      final entitlement = SubscriptionEntitlement.fromCapabilitiesJson(
        Map<String, dynamic>.from(decoded),
      );
      final at = (now ?? DateTime.now()).toUtc();
      if (!entitlement.isOfflineValid(at)) {
        return null;
      }
      return entitlement;
    } on Object {
      return null;
    }
  }

  Future<void> clear(String tenantId) async {
    await (_db.delete(_db.metaEntries)
          ..where((t) => t.key.equals(_key(tenantId))))
        .go();
  }
}
