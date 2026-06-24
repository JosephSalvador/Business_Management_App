import 'package:drift/drift.dart';

import 'app_enums.dart';

class ProductCategories extends Table {
  TextColumn get id => text()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get code => text().nullable()();
  TextColumn get description => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get syncStatus => text()
      .map(const SyncStatusConverter())
      .clientDefault(() => SyncStatus.localOnly.name)();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class ProductUnits extends Table {
  TextColumn get id => text()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get symbol => text().nullable()();
  TextColumn get description => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get syncStatus => text()
      .map(const SyncStatusConverter())
      .clientDefault(() => SyncStatus.localOnly.name)();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Products extends Table {
  TextColumn get id => text()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get sku => text().nullable()();
  TextColumn get barcode => text().nullable()();
  TextColumn get categoryId => text().nullable().references(ProductCategories, #id)();
  TextColumn get unitId => text().nullable().references(ProductUnits, #id)();
  TextColumn get type => text().map(const ProductTypeConverter())();
  TextColumn get pricingMode => text()
      .map(const PricingModeConverter())
      .clientDefault(() => PricingMode.fixedPrice.name)();
  RealColumn get costPrice => real().withDefault(const Constant(0))();
  RealColumn get sellingPrice => real()();
  RealColumn get stockQuantity => real().withDefault(const Constant(0))();
  RealColumn get reorderLevel => real().withDefault(const Constant(0))();
  BoolColumn get trackStock => boolean().withDefault(const Constant(true))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isTaxable => boolean().withDefault(const Constant(true))();
  TextColumn get description => text().nullable()();
  TextColumn get syncStatus => text()
      .map(const SyncStatusConverter())
      .clientDefault(() => SyncStatus.localOnly.name)();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get fullName => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get tin => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get syncStatus => text()
      .map(const SyncStatusConverter())
      .clientDefault(() => SyncStatus.localOnly.name)();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Sales extends Table {
  TextColumn get id => text()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get receiptNumber => text()();
  TextColumn get customerId => text().nullable().references(Customers, #id)();
  TextColumn get customerName => text()();
  TextColumn get customerTin => text().nullable()();
  TextColumn get customerMobile => text().nullable()();
  DateTimeColumn get saleDate => dateTime().clientDefault(() => DateTime.now())();
  RealColumn get subtotal => real().withDefault(const Constant(0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0))();
  RealColumn get vatAmount => real().withDefault(const Constant(0))();
  RealColumn get totalAmount => real()();
  TextColumn get status => text().map(const SaleStatusConverter())();
  TextColumn get paymentMethod => text().map(const PaymentMethodConverter())();
  TextColumn get paymentReference => text().nullable()();
  TextColumn get paymentChannel => text().nullable()();
  TextColumn get notes => text().nullable()();
  RealColumn get cashReceived => real().nullable()();
  RealColumn get changeDue => real().nullable()();
  TextColumn get syncStatus => text()
      .map(const SyncStatusConverter())
      .clientDefault(() => SyncStatus.localOnly.name)();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SaleItems extends Table {
  TextColumn get id => text()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get productId => text().nullable().references(Products, #id)();
  TextColumn get productName => text()();
  TextColumn get productCode => text().nullable()();
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()();
  RealColumn get discountAmount => real().withDefault(const Constant(0))();
  RealColumn get taxRate => real().withDefault(const Constant(0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0))();
  RealColumn get totalAmount => real()();
  TextColumn get syncStatus => text()
      .map(const SyncStatusConverter())
      .clientDefault(() => SyncStatus.localOnly.name)();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get category => text().nullable()();
  RealColumn get amount => real()();
  DateTimeColumn get expenseDate => dateTime().clientDefault(() => DateTime.now())();
  TextColumn get paymentMethod => text().map(const PaymentMethodConverter())();
  TextColumn get supplierName => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get receiptNumber => text().nullable()();
  TextColumn get syncStatus => text()
      .map(const SyncStatusConverter())
      .clientDefault(() => SyncStatus.localOnly.name)();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class StockMovements extends Table {
  TextColumn get id => text()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get type => text().map(const StockMovementTypeConverter())();
  RealColumn get quantity => real()();
  RealColumn get unitCost => real().nullable()();
  TextColumn get referenceType => text().nullable()();
  TextColumn get referenceId => text().nullable()();
  TextColumn get reason => text().nullable()();
  DateTimeColumn get movementDate => dateTime().clientDefault(() => DateTime.now())();
  TextColumn get syncStatus => text()
      .map(const SyncStatusConverter())
      .clientDefault(() => SyncStatus.localOnly.name)();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class AppSettings extends Table {
  TextColumn get id => text()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get value => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get groupName => text().nullable()();
  BoolColumn get isSensitive => boolean().withDefault(const Constant(false))();
  TextColumn get syncStatus => text()
      .map(const SyncStatusConverter())
      .clientDefault(() => SyncStatus.localOnly.name)();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class DeviceIdentities extends Table {
  TextColumn get id => text()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get deviceName => text()();
  TextColumn get deviceModel => text().nullable()();
  TextColumn get platform => text().nullable()();
  TextColumn get installationId => text()();
  TextColumn get appVersion => text().nullable()();
  DateTimeColumn get lastSeenAt => dateTime().clientDefault(() => DateTime.now())();
  TextColumn get syncStatus => text()
      .map(const SyncStatusConverter())
      .clientDefault(() => SyncStatus.localOnly.name)();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncQueueItems extends Table {
  TextColumn get id => text()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text().map(const SyncOperationConverter())();
  TextColumn get payloadJson => text()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
  DateTimeColumn get processedAt => dateTime().nullable()();
  TextColumn get syncStatus => text()
      .map(const SyncStatusConverter())
      .clientDefault(() => SyncStatus.pendingSync.name)();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
