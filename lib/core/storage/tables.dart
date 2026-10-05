import 'package:drift/drift.dart';

/// Local sync-operation statuses. Mirrors the audit's contract:
/// pending → syncing → synced | failed | conflict. Failed and conflicted
/// operations are never deleted automatically (M5 rule 9).
abstract final class SyncOperationStatus {
  static const pending = 0;
  static const syncing = 1;
  static const synced = 2;
  static const failed = 3;
  static const conflict = 4;
}

/// Local sale lifecycle. A sale starts pending (offline), becomes synced when
/// the server confirms it with its authoritative id/number, or conflict when
/// the server rejects it in a way that needs a human decision.
abstract final class LocalSaleStatus {
  static const pending = 0;
  static const synced = 1;
  static const conflict = 2;
}

/// Wire-format product status/type codes as stored in the cache. Mirrors the
/// backend serialization the cache was filled from (active=1, goods=0); only
/// active goods are sellable offline.
abstract final class LocalProductCodes {
  static const statusActive = 1;
  static const typeGoods = 0;
}

/// Small key/value store for device-local operational metadata
/// (schema bookkeeping, last successful auth, last catalog refresh).
class MetaEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Read model for the offline POS grid/search. Deliberately NOT the server
/// schema: only what selling needs. Prices are the tax-inclusive shelf price
/// of the tenant default list (Retail) as resolved by the server.
class CachedProducts extends Table {
  TextColumn get tenantId => text()();
  TextColumn get productId => text()();
  TextColumn get name => text()();
  TextColumn get sku => text().nullable()();
  TextColumn get barcode => text().nullable()();
  IntColumn get status => integer()();
  BoolColumn get sellable => boolean()();
  IntColumn get productType => integer()();
  RealColumn get retailPrice => real()();
  TextColumn get currency => text()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {tenantId, productId};
}

/// Last-known stock balances per warehouse. Projected deductions from pending
/// offline sales are computed by joining [LocalSaleLines], never written here,
/// so the cache always reflects what the server last told us.
class CachedStock extends Table {
  TextColumn get tenantId => text()();
  TextColumn get productId => text()();
  TextColumn get warehouseId => text()();
  RealColumn get quantity => real()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {tenantId, productId, warehouseId};
}

/// Warehouse read model for the offline stock hub. Replaced wholesale on
/// catalog refresh, like [CachedProducts]/[CachedStock], so it always mirrors
/// what the server last returned.
class CachedWarehouses extends Table {
  TextColumn get tenantId => text()();
  TextColumn get warehouseId => text()();
  TextColumn get name => text()();
  TextColumn get code => text()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {tenantId, warehouseId};
}

/// An offline sale awaiting confirmation. `clientSaleId` is the same GUID sent
/// as body clientSaleId AND Idempotency-Key header, so retries after restarts
/// or lost responses can never create a second server sale.
class LocalSales extends Table {
  TextColumn get clientSaleId => text()();
  TextColumn get tenantId => text()();
  TextColumn get branchId => text()();
  TextColumn get deviceId => text()();
  TextColumn get userId => text()();
  IntColumn get status => integer()();
  TextColumn get currency => text()();
  DateTimeColumn get effectiveAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  RealColumn get subtotalEstimate => real().withDefault(const Constant(0))();
  RealColumn get taxEstimate => real().withDefault(const Constant(0))();
  RealColumn get totalEstimate => real()();
  IntColumn get paymentMethod => integer()();
  RealColumn get paymentAmount => real()();
  TextColumn get serverSaleId => text().nullable()();
  TextColumn get serverNumber => text().nullable()();
  TextColumn get errorCode => text().nullable()();
  TextColumn get errorMessage => text().nullable()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {clientSaleId};
}

/// Immutable line snapshots exactly as accepted at the counter.
class LocalSaleLines extends Table {
  TextColumn get clientSaleId => text()();
  IntColumn get orderIndex => integer()();
  TextColumn get productId => text()();
  TextColumn get productName => text()();
  TextColumn get sku => text().nullable()();
  RealColumn get quantity => real()();
  RealColumn get unitPriceSnapshot => real()();
  RealColumn get lineTotalEstimate => real()();

  @override
  Set<Column> get primaryKey => {clientSaleId, orderIndex};
}

class LocalPayments extends Table {
  TextColumn get clientSaleId => text()();
  IntColumn get orderIndex => integer()();
  IntColumn get method => integer()();
  RealColumn get amount => real()();
  TextColumn get reference => text().nullable()();

  @override
  Set<Column> get primaryKey => {clientSaleId, orderIndex};
}

/// Persistent operation queue. One row per logical operation; `operationId`
/// equals the aggregate's stable identity (`clientSaleId` for sale.create),
/// making replay safe across app crashes and lost responses.
class SyncQueue extends Table {
  TextColumn get operationId => text()();
  TextColumn get tenantId => text()();
  TextColumn get branchId => text()();
  TextColumn get deviceId => text()();
  TextColumn get operationType => text()();
  TextColumn get aggregateType => text()();
  TextColumn get aggregateId => text()();
  TextColumn get payload => text()();
  IntColumn get status => integer()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  TextColumn get serverReference => text().nullable()();
  TextColumn get errorCode => text().nullable()();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {operationId};
}
