import 'package:drift/drift.dart';

enum ProductType { stockItem, service, nonStockItem }

enum PricingMode { fixedPrice, openPrice }

enum SaleStatus { draft, completed, cancelled, returned }

enum SyncStatus { localOnly, pendingSync, synced, syncFailed }

enum PaymentMethod { cash, mobileMoney, bank, credit, mixed }

enum StockMovementType {
  openingStock,
  sale,
  purchase,
  adjustment,
  returnIn,
  returnOut,
}

enum SyncOperation { insert, update, delete }

class ProductTypeConverter extends TypeConverter<ProductType, String> {
  const ProductTypeConverter();

  @override
  ProductType fromSql(String fromDb) => ProductType.values.byName(fromDb);

  @override
  String toSql(ProductType value) => value.name;
}

class PricingModeConverter extends TypeConverter<PricingMode, String> {
  const PricingModeConverter();

  @override
  PricingMode fromSql(String fromDb) => PricingMode.values.byName(fromDb);

  @override
  String toSql(PricingMode value) => value.name;
}

class SaleStatusConverter extends TypeConverter<SaleStatus, String> {
  const SaleStatusConverter();

  @override
  SaleStatus fromSql(String fromDb) => SaleStatus.values.byName(fromDb);

  @override
  String toSql(SaleStatus value) => value.name;
}

class SyncStatusConverter extends TypeConverter<SyncStatus, String> {
  const SyncStatusConverter();

  @override
  SyncStatus fromSql(String fromDb) => SyncStatus.values.byName(fromDb);

  @override
  String toSql(SyncStatus value) => value.name;
}

class PaymentMethodConverter extends TypeConverter<PaymentMethod, String> {
  const PaymentMethodConverter();

  @override
  PaymentMethod fromSql(String fromDb) => PaymentMethod.values.byName(fromDb);

  @override
  String toSql(PaymentMethod value) => value.name;
}

class StockMovementTypeConverter
    extends TypeConverter<StockMovementType, String> {
  const StockMovementTypeConverter();

  @override
  StockMovementType fromSql(String fromDb) =>
      StockMovementType.values.byName(fromDb);

  @override
  String toSql(StockMovementType value) => value.name;
}

class SyncOperationConverter extends TypeConverter<SyncOperation, String> {
  const SyncOperationConverter();

  @override
  SyncOperation fromSql(String fromDb) => SyncOperation.values.byName(fromDb);

  @override
  String toSql(SyncOperation value) => value.name;
}
