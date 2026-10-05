// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_database.dart';

// ignore_for_file: type=lint
class $MetaEntriesTable extends MetaEntries
    with TableInfo<$MetaEntriesTable, MetaEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta_entries';
  @override
  VerificationContext validateIntegrity(Insertable<MetaEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  MetaEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaEntry(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $MetaEntriesTable createAlias(String alias) {
    return $MetaEntriesTable(attachedDatabase, alias);
  }
}

class MetaEntry extends DataClass implements Insertable<MetaEntry> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const MetaEntry(
      {required this.key, required this.value, required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MetaEntriesCompanion toCompanion(bool nullToAbsent) {
    return MetaEntriesCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory MetaEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MetaEntry copyWith({String? key, String? value, DateTime? updatedAt}) =>
      MetaEntry(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  MetaEntry copyWithCompanion(MetaEntriesCompanion data) {
    return MetaEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaEntry(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetaEntry &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class MetaEntriesCompanion extends UpdateCompanion<MetaEntry> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MetaEntriesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaEntriesCompanion.insert({
    required String key,
    required String value,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value),
        updatedAt = Value(updatedAt);
  static Insertable<MetaEntry> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetaEntriesCompanion copyWith(
      {Value<String>? key,
      Value<String>? value,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return MetaEntriesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetaEntriesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedProductsTable extends CachedProducts
    with TableInfo<$CachedProductsTable, CachedProduct> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tenantIdMeta =
      const VerificationMeta('tenantId');
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
      'tenant_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _productIdMeta =
      const VerificationMeta('productId');
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
      'product_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _skuMeta = const VerificationMeta('sku');
  @override
  late final GeneratedColumn<String> sku = GeneratedColumn<String>(
      'sku', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _barcodeMeta =
      const VerificationMeta('barcode');
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
      'barcode', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
      'status', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _sellableMeta =
      const VerificationMeta('sellable');
  @override
  late final GeneratedColumn<bool> sellable = GeneratedColumn<bool>(
      'sellable', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("sellable" IN (0, 1))'));
  static const VerificationMeta _productTypeMeta =
      const VerificationMeta('productType');
  @override
  late final GeneratedColumn<int> productType = GeneratedColumn<int>(
      'product_type', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _retailPriceMeta =
      const VerificationMeta('retailPrice');
  @override
  late final GeneratedColumn<double> retailPrice = GeneratedColumn<double>(
      'retail_price', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fetchedAtMeta =
      const VerificationMeta('fetchedAt');
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
      'fetched_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        tenantId,
        productId,
        name,
        sku,
        barcode,
        status,
        sellable,
        productType,
        retailPrice,
        currency,
        fetchedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_products';
  @override
  VerificationContext validateIntegrity(Insertable<CachedProduct> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tenant_id')) {
      context.handle(_tenantIdMeta,
          tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta));
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(_productIdMeta,
          productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta));
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sku')) {
      context.handle(
          _skuMeta, sku.isAcceptableOrUnknown(data['sku']!, _skuMeta));
    }
    if (data.containsKey('barcode')) {
      context.handle(_barcodeMeta,
          barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('sellable')) {
      context.handle(_sellableMeta,
          sellable.isAcceptableOrUnknown(data['sellable']!, _sellableMeta));
    } else if (isInserting) {
      context.missing(_sellableMeta);
    }
    if (data.containsKey('product_type')) {
      context.handle(
          _productTypeMeta,
          productType.isAcceptableOrUnknown(
              data['product_type']!, _productTypeMeta));
    } else if (isInserting) {
      context.missing(_productTypeMeta);
    }
    if (data.containsKey('retail_price')) {
      context.handle(
          _retailPriceMeta,
          retailPrice.isAcceptableOrUnknown(
              data['retail_price']!, _retailPriceMeta));
    } else if (isInserting) {
      context.missing(_retailPriceMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(_fetchedAtMeta,
          fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta));
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tenantId, productId};
  @override
  CachedProduct map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedProduct(
      tenantId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tenant_id'])!,
      productId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      sku: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sku']),
      barcode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}barcode']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}status'])!,
      sellable: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}sellable'])!,
      productType: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}product_type'])!,
      retailPrice: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}retail_price'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      fetchedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}fetched_at'])!,
    );
  }

  @override
  $CachedProductsTable createAlias(String alias) {
    return $CachedProductsTable(attachedDatabase, alias);
  }
}

class CachedProduct extends DataClass implements Insertable<CachedProduct> {
  final String tenantId;
  final String productId;
  final String name;
  final String? sku;
  final String? barcode;
  final int status;
  final bool sellable;
  final int productType;
  final double retailPrice;
  final String currency;
  final DateTime fetchedAt;
  const CachedProduct(
      {required this.tenantId,
      required this.productId,
      required this.name,
      this.sku,
      this.barcode,
      required this.status,
      required this.sellable,
      required this.productType,
      required this.retailPrice,
      required this.currency,
      required this.fetchedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tenant_id'] = Variable<String>(tenantId);
    map['product_id'] = Variable<String>(productId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || sku != null) {
      map['sku'] = Variable<String>(sku);
    }
    if (!nullToAbsent || barcode != null) {
      map['barcode'] = Variable<String>(barcode);
    }
    map['status'] = Variable<int>(status);
    map['sellable'] = Variable<bool>(sellable);
    map['product_type'] = Variable<int>(productType);
    map['retail_price'] = Variable<double>(retailPrice);
    map['currency'] = Variable<String>(currency);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  CachedProductsCompanion toCompanion(bool nullToAbsent) {
    return CachedProductsCompanion(
      tenantId: Value(tenantId),
      productId: Value(productId),
      name: Value(name),
      sku: sku == null && nullToAbsent ? const Value.absent() : Value(sku),
      barcode: barcode == null && nullToAbsent
          ? const Value.absent()
          : Value(barcode),
      status: Value(status),
      sellable: Value(sellable),
      productType: Value(productType),
      retailPrice: Value(retailPrice),
      currency: Value(currency),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory CachedProduct.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedProduct(
      tenantId: serializer.fromJson<String>(json['tenantId']),
      productId: serializer.fromJson<String>(json['productId']),
      name: serializer.fromJson<String>(json['name']),
      sku: serializer.fromJson<String?>(json['sku']),
      barcode: serializer.fromJson<String?>(json['barcode']),
      status: serializer.fromJson<int>(json['status']),
      sellable: serializer.fromJson<bool>(json['sellable']),
      productType: serializer.fromJson<int>(json['productType']),
      retailPrice: serializer.fromJson<double>(json['retailPrice']),
      currency: serializer.fromJson<String>(json['currency']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tenantId': serializer.toJson<String>(tenantId),
      'productId': serializer.toJson<String>(productId),
      'name': serializer.toJson<String>(name),
      'sku': serializer.toJson<String?>(sku),
      'barcode': serializer.toJson<String?>(barcode),
      'status': serializer.toJson<int>(status),
      'sellable': serializer.toJson<bool>(sellable),
      'productType': serializer.toJson<int>(productType),
      'retailPrice': serializer.toJson<double>(retailPrice),
      'currency': serializer.toJson<String>(currency),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  CachedProduct copyWith(
          {String? tenantId,
          String? productId,
          String? name,
          Value<String?> sku = const Value.absent(),
          Value<String?> barcode = const Value.absent(),
          int? status,
          bool? sellable,
          int? productType,
          double? retailPrice,
          String? currency,
          DateTime? fetchedAt}) =>
      CachedProduct(
        tenantId: tenantId ?? this.tenantId,
        productId: productId ?? this.productId,
        name: name ?? this.name,
        sku: sku.present ? sku.value : this.sku,
        barcode: barcode.present ? barcode.value : this.barcode,
        status: status ?? this.status,
        sellable: sellable ?? this.sellable,
        productType: productType ?? this.productType,
        retailPrice: retailPrice ?? this.retailPrice,
        currency: currency ?? this.currency,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );
  CachedProduct copyWithCompanion(CachedProductsCompanion data) {
    return CachedProduct(
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      productId: data.productId.present ? data.productId.value : this.productId,
      name: data.name.present ? data.name.value : this.name,
      sku: data.sku.present ? data.sku.value : this.sku,
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      status: data.status.present ? data.status.value : this.status,
      sellable: data.sellable.present ? data.sellable.value : this.sellable,
      productType:
          data.productType.present ? data.productType.value : this.productType,
      retailPrice:
          data.retailPrice.present ? data.retailPrice.value : this.retailPrice,
      currency: data.currency.present ? data.currency.value : this.currency,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedProduct(')
          ..write('tenantId: $tenantId, ')
          ..write('productId: $productId, ')
          ..write('name: $name, ')
          ..write('sku: $sku, ')
          ..write('barcode: $barcode, ')
          ..write('status: $status, ')
          ..write('sellable: $sellable, ')
          ..write('productType: $productType, ')
          ..write('retailPrice: $retailPrice, ')
          ..write('currency: $currency, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(tenantId, productId, name, sku, barcode,
      status, sellable, productType, retailPrice, currency, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedProduct &&
          other.tenantId == this.tenantId &&
          other.productId == this.productId &&
          other.name == this.name &&
          other.sku == this.sku &&
          other.barcode == this.barcode &&
          other.status == this.status &&
          other.sellable == this.sellable &&
          other.productType == this.productType &&
          other.retailPrice == this.retailPrice &&
          other.currency == this.currency &&
          other.fetchedAt == this.fetchedAt);
}

class CachedProductsCompanion extends UpdateCompanion<CachedProduct> {
  final Value<String> tenantId;
  final Value<String> productId;
  final Value<String> name;
  final Value<String?> sku;
  final Value<String?> barcode;
  final Value<int> status;
  final Value<bool> sellable;
  final Value<int> productType;
  final Value<double> retailPrice;
  final Value<String> currency;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const CachedProductsCompanion({
    this.tenantId = const Value.absent(),
    this.productId = const Value.absent(),
    this.name = const Value.absent(),
    this.sku = const Value.absent(),
    this.barcode = const Value.absent(),
    this.status = const Value.absent(),
    this.sellable = const Value.absent(),
    this.productType = const Value.absent(),
    this.retailPrice = const Value.absent(),
    this.currency = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedProductsCompanion.insert({
    required String tenantId,
    required String productId,
    required String name,
    this.sku = const Value.absent(),
    this.barcode = const Value.absent(),
    required int status,
    required bool sellable,
    required int productType,
    required double retailPrice,
    required String currency,
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  })  : tenantId = Value(tenantId),
        productId = Value(productId),
        name = Value(name),
        status = Value(status),
        sellable = Value(sellable),
        productType = Value(productType),
        retailPrice = Value(retailPrice),
        currency = Value(currency),
        fetchedAt = Value(fetchedAt);
  static Insertable<CachedProduct> custom({
    Expression<String>? tenantId,
    Expression<String>? productId,
    Expression<String>? name,
    Expression<String>? sku,
    Expression<String>? barcode,
    Expression<int>? status,
    Expression<bool>? sellable,
    Expression<int>? productType,
    Expression<double>? retailPrice,
    Expression<String>? currency,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tenantId != null) 'tenant_id': tenantId,
      if (productId != null) 'product_id': productId,
      if (name != null) 'name': name,
      if (sku != null) 'sku': sku,
      if (barcode != null) 'barcode': barcode,
      if (status != null) 'status': status,
      if (sellable != null) 'sellable': sellable,
      if (productType != null) 'product_type': productType,
      if (retailPrice != null) 'retail_price': retailPrice,
      if (currency != null) 'currency': currency,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedProductsCompanion copyWith(
      {Value<String>? tenantId,
      Value<String>? productId,
      Value<String>? name,
      Value<String?>? sku,
      Value<String?>? barcode,
      Value<int>? status,
      Value<bool>? sellable,
      Value<int>? productType,
      Value<double>? retailPrice,
      Value<String>? currency,
      Value<DateTime>? fetchedAt,
      Value<int>? rowid}) {
    return CachedProductsCompanion(
      tenantId: tenantId ?? this.tenantId,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      status: status ?? this.status,
      sellable: sellable ?? this.sellable,
      productType: productType ?? this.productType,
      retailPrice: retailPrice ?? this.retailPrice,
      currency: currency ?? this.currency,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sku.present) {
      map['sku'] = Variable<String>(sku.value);
    }
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (sellable.present) {
      map['sellable'] = Variable<bool>(sellable.value);
    }
    if (productType.present) {
      map['product_type'] = Variable<int>(productType.value);
    }
    if (retailPrice.present) {
      map['retail_price'] = Variable<double>(retailPrice.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedProductsCompanion(')
          ..write('tenantId: $tenantId, ')
          ..write('productId: $productId, ')
          ..write('name: $name, ')
          ..write('sku: $sku, ')
          ..write('barcode: $barcode, ')
          ..write('status: $status, ')
          ..write('sellable: $sellable, ')
          ..write('productType: $productType, ')
          ..write('retailPrice: $retailPrice, ')
          ..write('currency: $currency, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedStockTable extends CachedStock
    with TableInfo<$CachedStockTable, CachedStockData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedStockTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tenantIdMeta =
      const VerificationMeta('tenantId');
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
      'tenant_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _productIdMeta =
      const VerificationMeta('productId');
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
      'product_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _warehouseIdMeta =
      const VerificationMeta('warehouseId');
  @override
  late final GeneratedColumn<String> warehouseId = GeneratedColumn<String>(
      'warehouse_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _quantityMeta =
      const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
      'quantity', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _fetchedAtMeta =
      const VerificationMeta('fetchedAt');
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
      'fetched_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [tenantId, productId, warehouseId, quantity, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_stock';
  @override
  VerificationContext validateIntegrity(Insertable<CachedStockData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tenant_id')) {
      context.handle(_tenantIdMeta,
          tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta));
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(_productIdMeta,
          productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta));
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('warehouse_id')) {
      context.handle(
          _warehouseIdMeta,
          warehouseId.isAcceptableOrUnknown(
              data['warehouse_id']!, _warehouseIdMeta));
    } else if (isInserting) {
      context.missing(_warehouseIdMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta,
          quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(_fetchedAtMeta,
          fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta));
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tenantId, productId, warehouseId};
  @override
  CachedStockData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedStockData(
      tenantId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tenant_id'])!,
      productId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_id'])!,
      warehouseId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}warehouse_id'])!,
      quantity: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}quantity'])!,
      fetchedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}fetched_at'])!,
    );
  }

  @override
  $CachedStockTable createAlias(String alias) {
    return $CachedStockTable(attachedDatabase, alias);
  }
}

class CachedStockData extends DataClass implements Insertable<CachedStockData> {
  final String tenantId;
  final String productId;
  final String warehouseId;
  final double quantity;
  final DateTime fetchedAt;
  const CachedStockData(
      {required this.tenantId,
      required this.productId,
      required this.warehouseId,
      required this.quantity,
      required this.fetchedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tenant_id'] = Variable<String>(tenantId);
    map['product_id'] = Variable<String>(productId);
    map['warehouse_id'] = Variable<String>(warehouseId);
    map['quantity'] = Variable<double>(quantity);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  CachedStockCompanion toCompanion(bool nullToAbsent) {
    return CachedStockCompanion(
      tenantId: Value(tenantId),
      productId: Value(productId),
      warehouseId: Value(warehouseId),
      quantity: Value(quantity),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory CachedStockData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedStockData(
      tenantId: serializer.fromJson<String>(json['tenantId']),
      productId: serializer.fromJson<String>(json['productId']),
      warehouseId: serializer.fromJson<String>(json['warehouseId']),
      quantity: serializer.fromJson<double>(json['quantity']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tenantId': serializer.toJson<String>(tenantId),
      'productId': serializer.toJson<String>(productId),
      'warehouseId': serializer.toJson<String>(warehouseId),
      'quantity': serializer.toJson<double>(quantity),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  CachedStockData copyWith(
          {String? tenantId,
          String? productId,
          String? warehouseId,
          double? quantity,
          DateTime? fetchedAt}) =>
      CachedStockData(
        tenantId: tenantId ?? this.tenantId,
        productId: productId ?? this.productId,
        warehouseId: warehouseId ?? this.warehouseId,
        quantity: quantity ?? this.quantity,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );
  CachedStockData copyWithCompanion(CachedStockCompanion data) {
    return CachedStockData(
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      productId: data.productId.present ? data.productId.value : this.productId,
      warehouseId:
          data.warehouseId.present ? data.warehouseId.value : this.warehouseId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedStockData(')
          ..write('tenantId: $tenantId, ')
          ..write('productId: $productId, ')
          ..write('warehouseId: $warehouseId, ')
          ..write('quantity: $quantity, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(tenantId, productId, warehouseId, quantity, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedStockData &&
          other.tenantId == this.tenantId &&
          other.productId == this.productId &&
          other.warehouseId == this.warehouseId &&
          other.quantity == this.quantity &&
          other.fetchedAt == this.fetchedAt);
}

class CachedStockCompanion extends UpdateCompanion<CachedStockData> {
  final Value<String> tenantId;
  final Value<String> productId;
  final Value<String> warehouseId;
  final Value<double> quantity;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const CachedStockCompanion({
    this.tenantId = const Value.absent(),
    this.productId = const Value.absent(),
    this.warehouseId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedStockCompanion.insert({
    required String tenantId,
    required String productId,
    required String warehouseId,
    required double quantity,
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  })  : tenantId = Value(tenantId),
        productId = Value(productId),
        warehouseId = Value(warehouseId),
        quantity = Value(quantity),
        fetchedAt = Value(fetchedAt);
  static Insertable<CachedStockData> custom({
    Expression<String>? tenantId,
    Expression<String>? productId,
    Expression<String>? warehouseId,
    Expression<double>? quantity,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tenantId != null) 'tenant_id': tenantId,
      if (productId != null) 'product_id': productId,
      if (warehouseId != null) 'warehouse_id': warehouseId,
      if (quantity != null) 'quantity': quantity,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedStockCompanion copyWith(
      {Value<String>? tenantId,
      Value<String>? productId,
      Value<String>? warehouseId,
      Value<double>? quantity,
      Value<DateTime>? fetchedAt,
      Value<int>? rowid}) {
    return CachedStockCompanion(
      tenantId: tenantId ?? this.tenantId,
      productId: productId ?? this.productId,
      warehouseId: warehouseId ?? this.warehouseId,
      quantity: quantity ?? this.quantity,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (warehouseId.present) {
      map['warehouse_id'] = Variable<String>(warehouseId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedStockCompanion(')
          ..write('tenantId: $tenantId, ')
          ..write('productId: $productId, ')
          ..write('warehouseId: $warehouseId, ')
          ..write('quantity: $quantity, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedWarehousesTable extends CachedWarehouses
    with TableInfo<$CachedWarehousesTable, CachedWarehouse> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedWarehousesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tenantIdMeta =
      const VerificationMeta('tenantId');
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
      'tenant_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _warehouseIdMeta =
      const VerificationMeta('warehouseId');
  @override
  late final GeneratedColumn<String> warehouseId = GeneratedColumn<String>(
      'warehouse_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
      'code', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fetchedAtMeta =
      const VerificationMeta('fetchedAt');
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
      'fetched_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [tenantId, warehouseId, name, code, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_warehouses';
  @override
  VerificationContext validateIntegrity(Insertable<CachedWarehouse> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tenant_id')) {
      context.handle(_tenantIdMeta,
          tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta));
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('warehouse_id')) {
      context.handle(
          _warehouseIdMeta,
          warehouseId.isAcceptableOrUnknown(
              data['warehouse_id']!, _warehouseIdMeta));
    } else if (isInserting) {
      context.missing(_warehouseIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
          _codeMeta, code.isAcceptableOrUnknown(data['code']!, _codeMeta));
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(_fetchedAtMeta,
          fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta));
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tenantId, warehouseId};
  @override
  CachedWarehouse map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedWarehouse(
      tenantId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tenant_id'])!,
      warehouseId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}warehouse_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      code: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}code'])!,
      fetchedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}fetched_at'])!,
    );
  }

  @override
  $CachedWarehousesTable createAlias(String alias) {
    return $CachedWarehousesTable(attachedDatabase, alias);
  }
}

class CachedWarehouse extends DataClass implements Insertable<CachedWarehouse> {
  final String tenantId;
  final String warehouseId;
  final String name;
  final String code;
  final DateTime fetchedAt;
  const CachedWarehouse(
      {required this.tenantId,
      required this.warehouseId,
      required this.name,
      required this.code,
      required this.fetchedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tenant_id'] = Variable<String>(tenantId);
    map['warehouse_id'] = Variable<String>(warehouseId);
    map['name'] = Variable<String>(name);
    map['code'] = Variable<String>(code);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  CachedWarehousesCompanion toCompanion(bool nullToAbsent) {
    return CachedWarehousesCompanion(
      tenantId: Value(tenantId),
      warehouseId: Value(warehouseId),
      name: Value(name),
      code: Value(code),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory CachedWarehouse.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedWarehouse(
      tenantId: serializer.fromJson<String>(json['tenantId']),
      warehouseId: serializer.fromJson<String>(json['warehouseId']),
      name: serializer.fromJson<String>(json['name']),
      code: serializer.fromJson<String>(json['code']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tenantId': serializer.toJson<String>(tenantId),
      'warehouseId': serializer.toJson<String>(warehouseId),
      'name': serializer.toJson<String>(name),
      'code': serializer.toJson<String>(code),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  CachedWarehouse copyWith(
          {String? tenantId,
          String? warehouseId,
          String? name,
          String? code,
          DateTime? fetchedAt}) =>
      CachedWarehouse(
        tenantId: tenantId ?? this.tenantId,
        warehouseId: warehouseId ?? this.warehouseId,
        name: name ?? this.name,
        code: code ?? this.code,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );
  CachedWarehouse copyWithCompanion(CachedWarehousesCompanion data) {
    return CachedWarehouse(
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      warehouseId:
          data.warehouseId.present ? data.warehouseId.value : this.warehouseId,
      name: data.name.present ? data.name.value : this.name,
      code: data.code.present ? data.code.value : this.code,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedWarehouse(')
          ..write('tenantId: $tenantId, ')
          ..write('warehouseId: $warehouseId, ')
          ..write('name: $name, ')
          ..write('code: $code, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(tenantId, warehouseId, name, code, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedWarehouse &&
          other.tenantId == this.tenantId &&
          other.warehouseId == this.warehouseId &&
          other.name == this.name &&
          other.code == this.code &&
          other.fetchedAt == this.fetchedAt);
}

class CachedWarehousesCompanion extends UpdateCompanion<CachedWarehouse> {
  final Value<String> tenantId;
  final Value<String> warehouseId;
  final Value<String> name;
  final Value<String> code;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const CachedWarehousesCompanion({
    this.tenantId = const Value.absent(),
    this.warehouseId = const Value.absent(),
    this.name = const Value.absent(),
    this.code = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedWarehousesCompanion.insert({
    required String tenantId,
    required String warehouseId,
    required String name,
    required String code,
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  })  : tenantId = Value(tenantId),
        warehouseId = Value(warehouseId),
        name = Value(name),
        code = Value(code),
        fetchedAt = Value(fetchedAt);
  static Insertable<CachedWarehouse> custom({
    Expression<String>? tenantId,
    Expression<String>? warehouseId,
    Expression<String>? name,
    Expression<String>? code,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tenantId != null) 'tenant_id': tenantId,
      if (warehouseId != null) 'warehouse_id': warehouseId,
      if (name != null) 'name': name,
      if (code != null) 'code': code,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedWarehousesCompanion copyWith(
      {Value<String>? tenantId,
      Value<String>? warehouseId,
      Value<String>? name,
      Value<String>? code,
      Value<DateTime>? fetchedAt,
      Value<int>? rowid}) {
    return CachedWarehousesCompanion(
      tenantId: tenantId ?? this.tenantId,
      warehouseId: warehouseId ?? this.warehouseId,
      name: name ?? this.name,
      code: code ?? this.code,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (warehouseId.present) {
      map['warehouse_id'] = Variable<String>(warehouseId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedWarehousesCompanion(')
          ..write('tenantId: $tenantId, ')
          ..write('warehouseId: $warehouseId, ')
          ..write('name: $name, ')
          ..write('code: $code, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSalesTable extends LocalSales
    with TableInfo<$LocalSalesTable, LocalSale> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSalesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientSaleIdMeta =
      const VerificationMeta('clientSaleId');
  @override
  late final GeneratedColumn<String> clientSaleId = GeneratedColumn<String>(
      'client_sale_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tenantIdMeta =
      const VerificationMeta('tenantId');
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
      'tenant_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _branchIdMeta =
      const VerificationMeta('branchId');
  @override
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
      'branch_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
      'status', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _effectiveAtMeta =
      const VerificationMeta('effectiveAt');
  @override
  late final GeneratedColumn<DateTime> effectiveAt = GeneratedColumn<DateTime>(
      'effective_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _subtotalEstimateMeta =
      const VerificationMeta('subtotalEstimate');
  @override
  late final GeneratedColumn<double> subtotalEstimate = GeneratedColumn<double>(
      'subtotal_estimate', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _taxEstimateMeta =
      const VerificationMeta('taxEstimate');
  @override
  late final GeneratedColumn<double> taxEstimate = GeneratedColumn<double>(
      'tax_estimate', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _totalEstimateMeta =
      const VerificationMeta('totalEstimate');
  @override
  late final GeneratedColumn<double> totalEstimate = GeneratedColumn<double>(
      'total_estimate', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _paymentMethodMeta =
      const VerificationMeta('paymentMethod');
  @override
  late final GeneratedColumn<int> paymentMethod = GeneratedColumn<int>(
      'payment_method', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _paymentAmountMeta =
      const VerificationMeta('paymentAmount');
  @override
  late final GeneratedColumn<double> paymentAmount = GeneratedColumn<double>(
      'payment_amount', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _serverSaleIdMeta =
      const VerificationMeta('serverSaleId');
  @override
  late final GeneratedColumn<String> serverSaleId = GeneratedColumn<String>(
      'server_sale_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _serverNumberMeta =
      const VerificationMeta('serverNumber');
  @override
  late final GeneratedColumn<String> serverNumber = GeneratedColumn<String>(
      'server_number', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _errorCodeMeta =
      const VerificationMeta('errorCode');
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
      'error_code', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _errorMessageMeta =
      const VerificationMeta('errorMessage');
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
      'error_message', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _attemptCountMeta =
      const VerificationMeta('attemptCount');
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
      'attempt_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastAttemptAtMeta =
      const VerificationMeta('lastAttemptAt');
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>('last_attempt_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        clientSaleId,
        tenantId,
        branchId,
        deviceId,
        userId,
        status,
        currency,
        effectiveAt,
        createdAt,
        syncedAt,
        subtotalEstimate,
        taxEstimate,
        totalEstimate,
        paymentMethod,
        paymentAmount,
        serverSaleId,
        serverNumber,
        errorCode,
        errorMessage,
        attemptCount,
        lastAttemptAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_sales';
  @override
  VerificationContext validateIntegrity(Insertable<LocalSale> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_sale_id')) {
      context.handle(
          _clientSaleIdMeta,
          clientSaleId.isAcceptableOrUnknown(
              data['client_sale_id']!, _clientSaleIdMeta));
    } else if (isInserting) {
      context.missing(_clientSaleIdMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(_tenantIdMeta,
          tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta));
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('branch_id')) {
      context.handle(_branchIdMeta,
          branchId.isAcceptableOrUnknown(data['branch_id']!, _branchIdMeta));
    } else if (isInserting) {
      context.missing(_branchIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('effective_at')) {
      context.handle(
          _effectiveAtMeta,
          effectiveAt.isAcceptableOrUnknown(
              data['effective_at']!, _effectiveAtMeta));
    } else if (isInserting) {
      context.missing(_effectiveAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    }
    if (data.containsKey('subtotal_estimate')) {
      context.handle(
          _subtotalEstimateMeta,
          subtotalEstimate.isAcceptableOrUnknown(
              data['subtotal_estimate']!, _subtotalEstimateMeta));
    }
    if (data.containsKey('tax_estimate')) {
      context.handle(
          _taxEstimateMeta,
          taxEstimate.isAcceptableOrUnknown(
              data['tax_estimate']!, _taxEstimateMeta));
    }
    if (data.containsKey('total_estimate')) {
      context.handle(
          _totalEstimateMeta,
          totalEstimate.isAcceptableOrUnknown(
              data['total_estimate']!, _totalEstimateMeta));
    } else if (isInserting) {
      context.missing(_totalEstimateMeta);
    }
    if (data.containsKey('payment_method')) {
      context.handle(
          _paymentMethodMeta,
          paymentMethod.isAcceptableOrUnknown(
              data['payment_method']!, _paymentMethodMeta));
    } else if (isInserting) {
      context.missing(_paymentMethodMeta);
    }
    if (data.containsKey('payment_amount')) {
      context.handle(
          _paymentAmountMeta,
          paymentAmount.isAcceptableOrUnknown(
              data['payment_amount']!, _paymentAmountMeta));
    } else if (isInserting) {
      context.missing(_paymentAmountMeta);
    }
    if (data.containsKey('server_sale_id')) {
      context.handle(
          _serverSaleIdMeta,
          serverSaleId.isAcceptableOrUnknown(
              data['server_sale_id']!, _serverSaleIdMeta));
    }
    if (data.containsKey('server_number')) {
      context.handle(
          _serverNumberMeta,
          serverNumber.isAcceptableOrUnknown(
              data['server_number']!, _serverNumberMeta));
    }
    if (data.containsKey('error_code')) {
      context.handle(_errorCodeMeta,
          errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta));
    }
    if (data.containsKey('error_message')) {
      context.handle(
          _errorMessageMeta,
          errorMessage.isAcceptableOrUnknown(
              data['error_message']!, _errorMessageMeta));
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
          _attemptCountMeta,
          attemptCount.isAcceptableOrUnknown(
              data['attempt_count']!, _attemptCountMeta));
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
          _lastAttemptAtMeta,
          lastAttemptAt.isAcceptableOrUnknown(
              data['last_attempt_at']!, _lastAttemptAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clientSaleId};
  @override
  LocalSale map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSale(
      clientSaleId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}client_sale_id'])!,
      tenantId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tenant_id'])!,
      branchId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}branch_id'])!,
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}status'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      effectiveAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}effective_at'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}synced_at']),
      subtotalEstimate: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}subtotal_estimate'])!,
      taxEstimate: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}tax_estimate'])!,
      totalEstimate: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}total_estimate'])!,
      paymentMethod: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}payment_method'])!,
      paymentAmount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}payment_amount'])!,
      serverSaleId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}server_sale_id']),
      serverNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}server_number']),
      errorCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}error_code']),
      errorMessage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}error_message']),
      attemptCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempt_count'])!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_attempt_at']),
    );
  }

  @override
  $LocalSalesTable createAlias(String alias) {
    return $LocalSalesTable(attachedDatabase, alias);
  }
}

class LocalSale extends DataClass implements Insertable<LocalSale> {
  final String clientSaleId;
  final String tenantId;
  final String branchId;
  final String deviceId;
  final String userId;
  final int status;
  final String currency;
  final DateTime effectiveAt;
  final DateTime createdAt;
  final DateTime? syncedAt;
  final double subtotalEstimate;
  final double taxEstimate;
  final double totalEstimate;
  final int paymentMethod;
  final double paymentAmount;
  final String? serverSaleId;
  final String? serverNumber;
  final String? errorCode;
  final String? errorMessage;
  final int attemptCount;
  final DateTime? lastAttemptAt;
  const LocalSale(
      {required this.clientSaleId,
      required this.tenantId,
      required this.branchId,
      required this.deviceId,
      required this.userId,
      required this.status,
      required this.currency,
      required this.effectiveAt,
      required this.createdAt,
      this.syncedAt,
      required this.subtotalEstimate,
      required this.taxEstimate,
      required this.totalEstimate,
      required this.paymentMethod,
      required this.paymentAmount,
      this.serverSaleId,
      this.serverNumber,
      this.errorCode,
      this.errorMessage,
      required this.attemptCount,
      this.lastAttemptAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_sale_id'] = Variable<String>(clientSaleId);
    map['tenant_id'] = Variable<String>(tenantId);
    map['branch_id'] = Variable<String>(branchId);
    map['device_id'] = Variable<String>(deviceId);
    map['user_id'] = Variable<String>(userId);
    map['status'] = Variable<int>(status);
    map['currency'] = Variable<String>(currency);
    map['effective_at'] = Variable<DateTime>(effectiveAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    map['subtotal_estimate'] = Variable<double>(subtotalEstimate);
    map['tax_estimate'] = Variable<double>(taxEstimate);
    map['total_estimate'] = Variable<double>(totalEstimate);
    map['payment_method'] = Variable<int>(paymentMethod);
    map['payment_amount'] = Variable<double>(paymentAmount);
    if (!nullToAbsent || serverSaleId != null) {
      map['server_sale_id'] = Variable<String>(serverSaleId);
    }
    if (!nullToAbsent || serverNumber != null) {
      map['server_number'] = Variable<String>(serverNumber);
    }
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    return map;
  }

  LocalSalesCompanion toCompanion(bool nullToAbsent) {
    return LocalSalesCompanion(
      clientSaleId: Value(clientSaleId),
      tenantId: Value(tenantId),
      branchId: Value(branchId),
      deviceId: Value(deviceId),
      userId: Value(userId),
      status: Value(status),
      currency: Value(currency),
      effectiveAt: Value(effectiveAt),
      createdAt: Value(createdAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      subtotalEstimate: Value(subtotalEstimate),
      taxEstimate: Value(taxEstimate),
      totalEstimate: Value(totalEstimate),
      paymentMethod: Value(paymentMethod),
      paymentAmount: Value(paymentAmount),
      serverSaleId: serverSaleId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverSaleId),
      serverNumber: serverNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(serverNumber),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      attemptCount: Value(attemptCount),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
    );
  }

  factory LocalSale.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSale(
      clientSaleId: serializer.fromJson<String>(json['clientSaleId']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      branchId: serializer.fromJson<String>(json['branchId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      userId: serializer.fromJson<String>(json['userId']),
      status: serializer.fromJson<int>(json['status']),
      currency: serializer.fromJson<String>(json['currency']),
      effectiveAt: serializer.fromJson<DateTime>(json['effectiveAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
      subtotalEstimate: serializer.fromJson<double>(json['subtotalEstimate']),
      taxEstimate: serializer.fromJson<double>(json['taxEstimate']),
      totalEstimate: serializer.fromJson<double>(json['totalEstimate']),
      paymentMethod: serializer.fromJson<int>(json['paymentMethod']),
      paymentAmount: serializer.fromJson<double>(json['paymentAmount']),
      serverSaleId: serializer.fromJson<String?>(json['serverSaleId']),
      serverNumber: serializer.fromJson<String?>(json['serverNumber']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientSaleId': serializer.toJson<String>(clientSaleId),
      'tenantId': serializer.toJson<String>(tenantId),
      'branchId': serializer.toJson<String>(branchId),
      'deviceId': serializer.toJson<String>(deviceId),
      'userId': serializer.toJson<String>(userId),
      'status': serializer.toJson<int>(status),
      'currency': serializer.toJson<String>(currency),
      'effectiveAt': serializer.toJson<DateTime>(effectiveAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
      'subtotalEstimate': serializer.toJson<double>(subtotalEstimate),
      'taxEstimate': serializer.toJson<double>(taxEstimate),
      'totalEstimate': serializer.toJson<double>(totalEstimate),
      'paymentMethod': serializer.toJson<int>(paymentMethod),
      'paymentAmount': serializer.toJson<double>(paymentAmount),
      'serverSaleId': serializer.toJson<String?>(serverSaleId),
      'serverNumber': serializer.toJson<String?>(serverNumber),
      'errorCode': serializer.toJson<String?>(errorCode),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
    };
  }

  LocalSale copyWith(
          {String? clientSaleId,
          String? tenantId,
          String? branchId,
          String? deviceId,
          String? userId,
          int? status,
          String? currency,
          DateTime? effectiveAt,
          DateTime? createdAt,
          Value<DateTime?> syncedAt = const Value.absent(),
          double? subtotalEstimate,
          double? taxEstimate,
          double? totalEstimate,
          int? paymentMethod,
          double? paymentAmount,
          Value<String?> serverSaleId = const Value.absent(),
          Value<String?> serverNumber = const Value.absent(),
          Value<String?> errorCode = const Value.absent(),
          Value<String?> errorMessage = const Value.absent(),
          int? attemptCount,
          Value<DateTime?> lastAttemptAt = const Value.absent()}) =>
      LocalSale(
        clientSaleId: clientSaleId ?? this.clientSaleId,
        tenantId: tenantId ?? this.tenantId,
        branchId: branchId ?? this.branchId,
        deviceId: deviceId ?? this.deviceId,
        userId: userId ?? this.userId,
        status: status ?? this.status,
        currency: currency ?? this.currency,
        effectiveAt: effectiveAt ?? this.effectiveAt,
        createdAt: createdAt ?? this.createdAt,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
        subtotalEstimate: subtotalEstimate ?? this.subtotalEstimate,
        taxEstimate: taxEstimate ?? this.taxEstimate,
        totalEstimate: totalEstimate ?? this.totalEstimate,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        paymentAmount: paymentAmount ?? this.paymentAmount,
        serverSaleId:
            serverSaleId.present ? serverSaleId.value : this.serverSaleId,
        serverNumber:
            serverNumber.present ? serverNumber.value : this.serverNumber,
        errorCode: errorCode.present ? errorCode.value : this.errorCode,
        errorMessage:
            errorMessage.present ? errorMessage.value : this.errorMessage,
        attemptCount: attemptCount ?? this.attemptCount,
        lastAttemptAt:
            lastAttemptAt.present ? lastAttemptAt.value : this.lastAttemptAt,
      );
  LocalSale copyWithCompanion(LocalSalesCompanion data) {
    return LocalSale(
      clientSaleId: data.clientSaleId.present
          ? data.clientSaleId.value
          : this.clientSaleId,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      userId: data.userId.present ? data.userId.value : this.userId,
      status: data.status.present ? data.status.value : this.status,
      currency: data.currency.present ? data.currency.value : this.currency,
      effectiveAt:
          data.effectiveAt.present ? data.effectiveAt.value : this.effectiveAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      subtotalEstimate: data.subtotalEstimate.present
          ? data.subtotalEstimate.value
          : this.subtotalEstimate,
      taxEstimate:
          data.taxEstimate.present ? data.taxEstimate.value : this.taxEstimate,
      totalEstimate: data.totalEstimate.present
          ? data.totalEstimate.value
          : this.totalEstimate,
      paymentMethod: data.paymentMethod.present
          ? data.paymentMethod.value
          : this.paymentMethod,
      paymentAmount: data.paymentAmount.present
          ? data.paymentAmount.value
          : this.paymentAmount,
      serverSaleId: data.serverSaleId.present
          ? data.serverSaleId.value
          : this.serverSaleId,
      serverNumber: data.serverNumber.present
          ? data.serverNumber.value
          : this.serverNumber,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSale(')
          ..write('clientSaleId: $clientSaleId, ')
          ..write('tenantId: $tenantId, ')
          ..write('branchId: $branchId, ')
          ..write('deviceId: $deviceId, ')
          ..write('userId: $userId, ')
          ..write('status: $status, ')
          ..write('currency: $currency, ')
          ..write('effectiveAt: $effectiveAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('subtotalEstimate: $subtotalEstimate, ')
          ..write('taxEstimate: $taxEstimate, ')
          ..write('totalEstimate: $totalEstimate, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('paymentAmount: $paymentAmount, ')
          ..write('serverSaleId: $serverSaleId, ')
          ..write('serverNumber: $serverNumber, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastAttemptAt: $lastAttemptAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        clientSaleId,
        tenantId,
        branchId,
        deviceId,
        userId,
        status,
        currency,
        effectiveAt,
        createdAt,
        syncedAt,
        subtotalEstimate,
        taxEstimate,
        totalEstimate,
        paymentMethod,
        paymentAmount,
        serverSaleId,
        serverNumber,
        errorCode,
        errorMessage,
        attemptCount,
        lastAttemptAt
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSale &&
          other.clientSaleId == this.clientSaleId &&
          other.tenantId == this.tenantId &&
          other.branchId == this.branchId &&
          other.deviceId == this.deviceId &&
          other.userId == this.userId &&
          other.status == this.status &&
          other.currency == this.currency &&
          other.effectiveAt == this.effectiveAt &&
          other.createdAt == this.createdAt &&
          other.syncedAt == this.syncedAt &&
          other.subtotalEstimate == this.subtotalEstimate &&
          other.taxEstimate == this.taxEstimate &&
          other.totalEstimate == this.totalEstimate &&
          other.paymentMethod == this.paymentMethod &&
          other.paymentAmount == this.paymentAmount &&
          other.serverSaleId == this.serverSaleId &&
          other.serverNumber == this.serverNumber &&
          other.errorCode == this.errorCode &&
          other.errorMessage == this.errorMessage &&
          other.attemptCount == this.attemptCount &&
          other.lastAttemptAt == this.lastAttemptAt);
}

class LocalSalesCompanion extends UpdateCompanion<LocalSale> {
  final Value<String> clientSaleId;
  final Value<String> tenantId;
  final Value<String> branchId;
  final Value<String> deviceId;
  final Value<String> userId;
  final Value<int> status;
  final Value<String> currency;
  final Value<DateTime> effectiveAt;
  final Value<DateTime> createdAt;
  final Value<DateTime?> syncedAt;
  final Value<double> subtotalEstimate;
  final Value<double> taxEstimate;
  final Value<double> totalEstimate;
  final Value<int> paymentMethod;
  final Value<double> paymentAmount;
  final Value<String?> serverSaleId;
  final Value<String?> serverNumber;
  final Value<String?> errorCode;
  final Value<String?> errorMessage;
  final Value<int> attemptCount;
  final Value<DateTime?> lastAttemptAt;
  final Value<int> rowid;
  const LocalSalesCompanion({
    this.clientSaleId = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.userId = const Value.absent(),
    this.status = const Value.absent(),
    this.currency = const Value.absent(),
    this.effectiveAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.subtotalEstimate = const Value.absent(),
    this.taxEstimate = const Value.absent(),
    this.totalEstimate = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.paymentAmount = const Value.absent(),
    this.serverSaleId = const Value.absent(),
    this.serverNumber = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSalesCompanion.insert({
    required String clientSaleId,
    required String tenantId,
    required String branchId,
    required String deviceId,
    required String userId,
    required int status,
    required String currency,
    required DateTime effectiveAt,
    required DateTime createdAt,
    this.syncedAt = const Value.absent(),
    this.subtotalEstimate = const Value.absent(),
    this.taxEstimate = const Value.absent(),
    required double totalEstimate,
    required int paymentMethod,
    required double paymentAmount,
    this.serverSaleId = const Value.absent(),
    this.serverNumber = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : clientSaleId = Value(clientSaleId),
        tenantId = Value(tenantId),
        branchId = Value(branchId),
        deviceId = Value(deviceId),
        userId = Value(userId),
        status = Value(status),
        currency = Value(currency),
        effectiveAt = Value(effectiveAt),
        createdAt = Value(createdAt),
        totalEstimate = Value(totalEstimate),
        paymentMethod = Value(paymentMethod),
        paymentAmount = Value(paymentAmount);
  static Insertable<LocalSale> custom({
    Expression<String>? clientSaleId,
    Expression<String>? tenantId,
    Expression<String>? branchId,
    Expression<String>? deviceId,
    Expression<String>? userId,
    Expression<int>? status,
    Expression<String>? currency,
    Expression<DateTime>? effectiveAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? syncedAt,
    Expression<double>? subtotalEstimate,
    Expression<double>? taxEstimate,
    Expression<double>? totalEstimate,
    Expression<int>? paymentMethod,
    Expression<double>? paymentAmount,
    Expression<String>? serverSaleId,
    Expression<String>? serverNumber,
    Expression<String>? errorCode,
    Expression<String>? errorMessage,
    Expression<int>? attemptCount,
    Expression<DateTime>? lastAttemptAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientSaleId != null) 'client_sale_id': clientSaleId,
      if (tenantId != null) 'tenant_id': tenantId,
      if (branchId != null) 'branch_id': branchId,
      if (deviceId != null) 'device_id': deviceId,
      if (userId != null) 'user_id': userId,
      if (status != null) 'status': status,
      if (currency != null) 'currency': currency,
      if (effectiveAt != null) 'effective_at': effectiveAt,
      if (createdAt != null) 'created_at': createdAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (subtotalEstimate != null) 'subtotal_estimate': subtotalEstimate,
      if (taxEstimate != null) 'tax_estimate': taxEstimate,
      if (totalEstimate != null) 'total_estimate': totalEstimate,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (paymentAmount != null) 'payment_amount': paymentAmount,
      if (serverSaleId != null) 'server_sale_id': serverSaleId,
      if (serverNumber != null) 'server_number': serverNumber,
      if (errorCode != null) 'error_code': errorCode,
      if (errorMessage != null) 'error_message': errorMessage,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSalesCompanion copyWith(
      {Value<String>? clientSaleId,
      Value<String>? tenantId,
      Value<String>? branchId,
      Value<String>? deviceId,
      Value<String>? userId,
      Value<int>? status,
      Value<String>? currency,
      Value<DateTime>? effectiveAt,
      Value<DateTime>? createdAt,
      Value<DateTime?>? syncedAt,
      Value<double>? subtotalEstimate,
      Value<double>? taxEstimate,
      Value<double>? totalEstimate,
      Value<int>? paymentMethod,
      Value<double>? paymentAmount,
      Value<String?>? serverSaleId,
      Value<String?>? serverNumber,
      Value<String?>? errorCode,
      Value<String?>? errorMessage,
      Value<int>? attemptCount,
      Value<DateTime?>? lastAttemptAt,
      Value<int>? rowid}) {
    return LocalSalesCompanion(
      clientSaleId: clientSaleId ?? this.clientSaleId,
      tenantId: tenantId ?? this.tenantId,
      branchId: branchId ?? this.branchId,
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      currency: currency ?? this.currency,
      effectiveAt: effectiveAt ?? this.effectiveAt,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
      subtotalEstimate: subtotalEstimate ?? this.subtotalEstimate,
      taxEstimate: taxEstimate ?? this.taxEstimate,
      totalEstimate: totalEstimate ?? this.totalEstimate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      serverSaleId: serverSaleId ?? this.serverSaleId,
      serverNumber: serverNumber ?? this.serverNumber,
      errorCode: errorCode ?? this.errorCode,
      errorMessage: errorMessage ?? this.errorMessage,
      attemptCount: attemptCount ?? this.attemptCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientSaleId.present) {
      map['client_sale_id'] = Variable<String>(clientSaleId.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (effectiveAt.present) {
      map['effective_at'] = Variable<DateTime>(effectiveAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (subtotalEstimate.present) {
      map['subtotal_estimate'] = Variable<double>(subtotalEstimate.value);
    }
    if (taxEstimate.present) {
      map['tax_estimate'] = Variable<double>(taxEstimate.value);
    }
    if (totalEstimate.present) {
      map['total_estimate'] = Variable<double>(totalEstimate.value);
    }
    if (paymentMethod.present) {
      map['payment_method'] = Variable<int>(paymentMethod.value);
    }
    if (paymentAmount.present) {
      map['payment_amount'] = Variable<double>(paymentAmount.value);
    }
    if (serverSaleId.present) {
      map['server_sale_id'] = Variable<String>(serverSaleId.value);
    }
    if (serverNumber.present) {
      map['server_number'] = Variable<String>(serverNumber.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSalesCompanion(')
          ..write('clientSaleId: $clientSaleId, ')
          ..write('tenantId: $tenantId, ')
          ..write('branchId: $branchId, ')
          ..write('deviceId: $deviceId, ')
          ..write('userId: $userId, ')
          ..write('status: $status, ')
          ..write('currency: $currency, ')
          ..write('effectiveAt: $effectiveAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('subtotalEstimate: $subtotalEstimate, ')
          ..write('taxEstimate: $taxEstimate, ')
          ..write('totalEstimate: $totalEstimate, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('paymentAmount: $paymentAmount, ')
          ..write('serverSaleId: $serverSaleId, ')
          ..write('serverNumber: $serverNumber, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSaleLinesTable extends LocalSaleLines
    with TableInfo<$LocalSaleLinesTable, LocalSaleLine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSaleLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientSaleIdMeta =
      const VerificationMeta('clientSaleId');
  @override
  late final GeneratedColumn<String> clientSaleId = GeneratedColumn<String>(
      'client_sale_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _orderIndexMeta =
      const VerificationMeta('orderIndex');
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
      'order_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _productIdMeta =
      const VerificationMeta('productId');
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
      'product_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _productNameMeta =
      const VerificationMeta('productName');
  @override
  late final GeneratedColumn<String> productName = GeneratedColumn<String>(
      'product_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _skuMeta = const VerificationMeta('sku');
  @override
  late final GeneratedColumn<String> sku = GeneratedColumn<String>(
      'sku', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _quantityMeta =
      const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
      'quantity', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _unitPriceSnapshotMeta =
      const VerificationMeta('unitPriceSnapshot');
  @override
  late final GeneratedColumn<double> unitPriceSnapshot =
      GeneratedColumn<double>('unit_price_snapshot', aliasedName, false,
          type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _lineTotalEstimateMeta =
      const VerificationMeta('lineTotalEstimate');
  @override
  late final GeneratedColumn<double> lineTotalEstimate =
      GeneratedColumn<double>('line_total_estimate', aliasedName, false,
          type: DriftSqlType.double, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        clientSaleId,
        orderIndex,
        productId,
        productName,
        sku,
        quantity,
        unitPriceSnapshot,
        lineTotalEstimate
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_sale_lines';
  @override
  VerificationContext validateIntegrity(Insertable<LocalSaleLine> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_sale_id')) {
      context.handle(
          _clientSaleIdMeta,
          clientSaleId.isAcceptableOrUnknown(
              data['client_sale_id']!, _clientSaleIdMeta));
    } else if (isInserting) {
      context.missing(_clientSaleIdMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
          _orderIndexMeta,
          orderIndex.isAcceptableOrUnknown(
              data['order_index']!, _orderIndexMeta));
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(_productIdMeta,
          productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta));
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('product_name')) {
      context.handle(
          _productNameMeta,
          productName.isAcceptableOrUnknown(
              data['product_name']!, _productNameMeta));
    } else if (isInserting) {
      context.missing(_productNameMeta);
    }
    if (data.containsKey('sku')) {
      context.handle(
          _skuMeta, sku.isAcceptableOrUnknown(data['sku']!, _skuMeta));
    }
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta,
          quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('unit_price_snapshot')) {
      context.handle(
          _unitPriceSnapshotMeta,
          unitPriceSnapshot.isAcceptableOrUnknown(
              data['unit_price_snapshot']!, _unitPriceSnapshotMeta));
    } else if (isInserting) {
      context.missing(_unitPriceSnapshotMeta);
    }
    if (data.containsKey('line_total_estimate')) {
      context.handle(
          _lineTotalEstimateMeta,
          lineTotalEstimate.isAcceptableOrUnknown(
              data['line_total_estimate']!, _lineTotalEstimateMeta));
    } else if (isInserting) {
      context.missing(_lineTotalEstimateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clientSaleId, orderIndex};
  @override
  LocalSaleLine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSaleLine(
      clientSaleId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}client_sale_id'])!,
      orderIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}order_index'])!,
      productId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_id'])!,
      productName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_name'])!,
      sku: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sku']),
      quantity: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}quantity'])!,
      unitPriceSnapshot: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}unit_price_snapshot'])!,
      lineTotalEstimate: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}line_total_estimate'])!,
    );
  }

  @override
  $LocalSaleLinesTable createAlias(String alias) {
    return $LocalSaleLinesTable(attachedDatabase, alias);
  }
}

class LocalSaleLine extends DataClass implements Insertable<LocalSaleLine> {
  final String clientSaleId;
  final int orderIndex;
  final String productId;
  final String productName;
  final String? sku;
  final double quantity;
  final double unitPriceSnapshot;
  final double lineTotalEstimate;
  const LocalSaleLine(
      {required this.clientSaleId,
      required this.orderIndex,
      required this.productId,
      required this.productName,
      this.sku,
      required this.quantity,
      required this.unitPriceSnapshot,
      required this.lineTotalEstimate});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_sale_id'] = Variable<String>(clientSaleId);
    map['order_index'] = Variable<int>(orderIndex);
    map['product_id'] = Variable<String>(productId);
    map['product_name'] = Variable<String>(productName);
    if (!nullToAbsent || sku != null) {
      map['sku'] = Variable<String>(sku);
    }
    map['quantity'] = Variable<double>(quantity);
    map['unit_price_snapshot'] = Variable<double>(unitPriceSnapshot);
    map['line_total_estimate'] = Variable<double>(lineTotalEstimate);
    return map;
  }

  LocalSaleLinesCompanion toCompanion(bool nullToAbsent) {
    return LocalSaleLinesCompanion(
      clientSaleId: Value(clientSaleId),
      orderIndex: Value(orderIndex),
      productId: Value(productId),
      productName: Value(productName),
      sku: sku == null && nullToAbsent ? const Value.absent() : Value(sku),
      quantity: Value(quantity),
      unitPriceSnapshot: Value(unitPriceSnapshot),
      lineTotalEstimate: Value(lineTotalEstimate),
    );
  }

  factory LocalSaleLine.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSaleLine(
      clientSaleId: serializer.fromJson<String>(json['clientSaleId']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      productId: serializer.fromJson<String>(json['productId']),
      productName: serializer.fromJson<String>(json['productName']),
      sku: serializer.fromJson<String?>(json['sku']),
      quantity: serializer.fromJson<double>(json['quantity']),
      unitPriceSnapshot: serializer.fromJson<double>(json['unitPriceSnapshot']),
      lineTotalEstimate: serializer.fromJson<double>(json['lineTotalEstimate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientSaleId': serializer.toJson<String>(clientSaleId),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'productId': serializer.toJson<String>(productId),
      'productName': serializer.toJson<String>(productName),
      'sku': serializer.toJson<String?>(sku),
      'quantity': serializer.toJson<double>(quantity),
      'unitPriceSnapshot': serializer.toJson<double>(unitPriceSnapshot),
      'lineTotalEstimate': serializer.toJson<double>(lineTotalEstimate),
    };
  }

  LocalSaleLine copyWith(
          {String? clientSaleId,
          int? orderIndex,
          String? productId,
          String? productName,
          Value<String?> sku = const Value.absent(),
          double? quantity,
          double? unitPriceSnapshot,
          double? lineTotalEstimate}) =>
      LocalSaleLine(
        clientSaleId: clientSaleId ?? this.clientSaleId,
        orderIndex: orderIndex ?? this.orderIndex,
        productId: productId ?? this.productId,
        productName: productName ?? this.productName,
        sku: sku.present ? sku.value : this.sku,
        quantity: quantity ?? this.quantity,
        unitPriceSnapshot: unitPriceSnapshot ?? this.unitPriceSnapshot,
        lineTotalEstimate: lineTotalEstimate ?? this.lineTotalEstimate,
      );
  LocalSaleLine copyWithCompanion(LocalSaleLinesCompanion data) {
    return LocalSaleLine(
      clientSaleId: data.clientSaleId.present
          ? data.clientSaleId.value
          : this.clientSaleId,
      orderIndex:
          data.orderIndex.present ? data.orderIndex.value : this.orderIndex,
      productId: data.productId.present ? data.productId.value : this.productId,
      productName:
          data.productName.present ? data.productName.value : this.productName,
      sku: data.sku.present ? data.sku.value : this.sku,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unitPriceSnapshot: data.unitPriceSnapshot.present
          ? data.unitPriceSnapshot.value
          : this.unitPriceSnapshot,
      lineTotalEstimate: data.lineTotalEstimate.present
          ? data.lineTotalEstimate.value
          : this.lineTotalEstimate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSaleLine(')
          ..write('clientSaleId: $clientSaleId, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('productId: $productId, ')
          ..write('productName: $productName, ')
          ..write('sku: $sku, ')
          ..write('quantity: $quantity, ')
          ..write('unitPriceSnapshot: $unitPriceSnapshot, ')
          ..write('lineTotalEstimate: $lineTotalEstimate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(clientSaleId, orderIndex, productId,
      productName, sku, quantity, unitPriceSnapshot, lineTotalEstimate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSaleLine &&
          other.clientSaleId == this.clientSaleId &&
          other.orderIndex == this.orderIndex &&
          other.productId == this.productId &&
          other.productName == this.productName &&
          other.sku == this.sku &&
          other.quantity == this.quantity &&
          other.unitPriceSnapshot == this.unitPriceSnapshot &&
          other.lineTotalEstimate == this.lineTotalEstimate);
}

class LocalSaleLinesCompanion extends UpdateCompanion<LocalSaleLine> {
  final Value<String> clientSaleId;
  final Value<int> orderIndex;
  final Value<String> productId;
  final Value<String> productName;
  final Value<String?> sku;
  final Value<double> quantity;
  final Value<double> unitPriceSnapshot;
  final Value<double> lineTotalEstimate;
  final Value<int> rowid;
  const LocalSaleLinesCompanion({
    this.clientSaleId = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.productId = const Value.absent(),
    this.productName = const Value.absent(),
    this.sku = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unitPriceSnapshot = const Value.absent(),
    this.lineTotalEstimate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSaleLinesCompanion.insert({
    required String clientSaleId,
    required int orderIndex,
    required String productId,
    required String productName,
    this.sku = const Value.absent(),
    required double quantity,
    required double unitPriceSnapshot,
    required double lineTotalEstimate,
    this.rowid = const Value.absent(),
  })  : clientSaleId = Value(clientSaleId),
        orderIndex = Value(orderIndex),
        productId = Value(productId),
        productName = Value(productName),
        quantity = Value(quantity),
        unitPriceSnapshot = Value(unitPriceSnapshot),
        lineTotalEstimate = Value(lineTotalEstimate);
  static Insertable<LocalSaleLine> custom({
    Expression<String>? clientSaleId,
    Expression<int>? orderIndex,
    Expression<String>? productId,
    Expression<String>? productName,
    Expression<String>? sku,
    Expression<double>? quantity,
    Expression<double>? unitPriceSnapshot,
    Expression<double>? lineTotalEstimate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientSaleId != null) 'client_sale_id': clientSaleId,
      if (orderIndex != null) 'order_index': orderIndex,
      if (productId != null) 'product_id': productId,
      if (productName != null) 'product_name': productName,
      if (sku != null) 'sku': sku,
      if (quantity != null) 'quantity': quantity,
      if (unitPriceSnapshot != null) 'unit_price_snapshot': unitPriceSnapshot,
      if (lineTotalEstimate != null) 'line_total_estimate': lineTotalEstimate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSaleLinesCompanion copyWith(
      {Value<String>? clientSaleId,
      Value<int>? orderIndex,
      Value<String>? productId,
      Value<String>? productName,
      Value<String?>? sku,
      Value<double>? quantity,
      Value<double>? unitPriceSnapshot,
      Value<double>? lineTotalEstimate,
      Value<int>? rowid}) {
    return LocalSaleLinesCompanion(
      clientSaleId: clientSaleId ?? this.clientSaleId,
      orderIndex: orderIndex ?? this.orderIndex,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      sku: sku ?? this.sku,
      quantity: quantity ?? this.quantity,
      unitPriceSnapshot: unitPriceSnapshot ?? this.unitPriceSnapshot,
      lineTotalEstimate: lineTotalEstimate ?? this.lineTotalEstimate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientSaleId.present) {
      map['client_sale_id'] = Variable<String>(clientSaleId.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (productName.present) {
      map['product_name'] = Variable<String>(productName.value);
    }
    if (sku.present) {
      map['sku'] = Variable<String>(sku.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (unitPriceSnapshot.present) {
      map['unit_price_snapshot'] = Variable<double>(unitPriceSnapshot.value);
    }
    if (lineTotalEstimate.present) {
      map['line_total_estimate'] = Variable<double>(lineTotalEstimate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSaleLinesCompanion(')
          ..write('clientSaleId: $clientSaleId, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('productId: $productId, ')
          ..write('productName: $productName, ')
          ..write('sku: $sku, ')
          ..write('quantity: $quantity, ')
          ..write('unitPriceSnapshot: $unitPriceSnapshot, ')
          ..write('lineTotalEstimate: $lineTotalEstimate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalPaymentsTable extends LocalPayments
    with TableInfo<$LocalPaymentsTable, LocalPayment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalPaymentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientSaleIdMeta =
      const VerificationMeta('clientSaleId');
  @override
  late final GeneratedColumn<String> clientSaleId = GeneratedColumn<String>(
      'client_sale_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _orderIndexMeta =
      const VerificationMeta('orderIndex');
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
      'order_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<int> method = GeneratedColumn<int>(
      'method', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
      'amount', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _referenceMeta =
      const VerificationMeta('reference');
  @override
  late final GeneratedColumn<String> reference = GeneratedColumn<String>(
      'reference', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [clientSaleId, orderIndex, method, amount, reference];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_payments';
  @override
  VerificationContext validateIntegrity(Insertable<LocalPayment> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_sale_id')) {
      context.handle(
          _clientSaleIdMeta,
          clientSaleId.isAcceptableOrUnknown(
              data['client_sale_id']!, _clientSaleIdMeta));
    } else if (isInserting) {
      context.missing(_clientSaleIdMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
          _orderIndexMeta,
          orderIndex.isAcceptableOrUnknown(
              data['order_index']!, _orderIndexMeta));
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    if (data.containsKey('method')) {
      context.handle(_methodMeta,
          method.isAcceptableOrUnknown(data['method']!, _methodMeta));
    } else if (isInserting) {
      context.missing(_methodMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('reference')) {
      context.handle(_referenceMeta,
          reference.isAcceptableOrUnknown(data['reference']!, _referenceMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clientSaleId, orderIndex};
  @override
  LocalPayment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalPayment(
      clientSaleId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}client_sale_id'])!,
      orderIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}order_index'])!,
      method: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}method'])!,
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount'])!,
      reference: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reference']),
    );
  }

  @override
  $LocalPaymentsTable createAlias(String alias) {
    return $LocalPaymentsTable(attachedDatabase, alias);
  }
}

class LocalPayment extends DataClass implements Insertable<LocalPayment> {
  final String clientSaleId;
  final int orderIndex;
  final int method;
  final double amount;
  final String? reference;
  const LocalPayment(
      {required this.clientSaleId,
      required this.orderIndex,
      required this.method,
      required this.amount,
      this.reference});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_sale_id'] = Variable<String>(clientSaleId);
    map['order_index'] = Variable<int>(orderIndex);
    map['method'] = Variable<int>(method);
    map['amount'] = Variable<double>(amount);
    if (!nullToAbsent || reference != null) {
      map['reference'] = Variable<String>(reference);
    }
    return map;
  }

  LocalPaymentsCompanion toCompanion(bool nullToAbsent) {
    return LocalPaymentsCompanion(
      clientSaleId: Value(clientSaleId),
      orderIndex: Value(orderIndex),
      method: Value(method),
      amount: Value(amount),
      reference: reference == null && nullToAbsent
          ? const Value.absent()
          : Value(reference),
    );
  }

  factory LocalPayment.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalPayment(
      clientSaleId: serializer.fromJson<String>(json['clientSaleId']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      method: serializer.fromJson<int>(json['method']),
      amount: serializer.fromJson<double>(json['amount']),
      reference: serializer.fromJson<String?>(json['reference']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientSaleId': serializer.toJson<String>(clientSaleId),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'method': serializer.toJson<int>(method),
      'amount': serializer.toJson<double>(amount),
      'reference': serializer.toJson<String?>(reference),
    };
  }

  LocalPayment copyWith(
          {String? clientSaleId,
          int? orderIndex,
          int? method,
          double? amount,
          Value<String?> reference = const Value.absent()}) =>
      LocalPayment(
        clientSaleId: clientSaleId ?? this.clientSaleId,
        orderIndex: orderIndex ?? this.orderIndex,
        method: method ?? this.method,
        amount: amount ?? this.amount,
        reference: reference.present ? reference.value : this.reference,
      );
  LocalPayment copyWithCompanion(LocalPaymentsCompanion data) {
    return LocalPayment(
      clientSaleId: data.clientSaleId.present
          ? data.clientSaleId.value
          : this.clientSaleId,
      orderIndex:
          data.orderIndex.present ? data.orderIndex.value : this.orderIndex,
      method: data.method.present ? data.method.value : this.method,
      amount: data.amount.present ? data.amount.value : this.amount,
      reference: data.reference.present ? data.reference.value : this.reference,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalPayment(')
          ..write('clientSaleId: $clientSaleId, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('method: $method, ')
          ..write('amount: $amount, ')
          ..write('reference: $reference')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(clientSaleId, orderIndex, method, amount, reference);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalPayment &&
          other.clientSaleId == this.clientSaleId &&
          other.orderIndex == this.orderIndex &&
          other.method == this.method &&
          other.amount == this.amount &&
          other.reference == this.reference);
}

class LocalPaymentsCompanion extends UpdateCompanion<LocalPayment> {
  final Value<String> clientSaleId;
  final Value<int> orderIndex;
  final Value<int> method;
  final Value<double> amount;
  final Value<String?> reference;
  final Value<int> rowid;
  const LocalPaymentsCompanion({
    this.clientSaleId = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.method = const Value.absent(),
    this.amount = const Value.absent(),
    this.reference = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalPaymentsCompanion.insert({
    required String clientSaleId,
    required int orderIndex,
    required int method,
    required double amount,
    this.reference = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : clientSaleId = Value(clientSaleId),
        orderIndex = Value(orderIndex),
        method = Value(method),
        amount = Value(amount);
  static Insertable<LocalPayment> custom({
    Expression<String>? clientSaleId,
    Expression<int>? orderIndex,
    Expression<int>? method,
    Expression<double>? amount,
    Expression<String>? reference,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientSaleId != null) 'client_sale_id': clientSaleId,
      if (orderIndex != null) 'order_index': orderIndex,
      if (method != null) 'method': method,
      if (amount != null) 'amount': amount,
      if (reference != null) 'reference': reference,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalPaymentsCompanion copyWith(
      {Value<String>? clientSaleId,
      Value<int>? orderIndex,
      Value<int>? method,
      Value<double>? amount,
      Value<String?>? reference,
      Value<int>? rowid}) {
    return LocalPaymentsCompanion(
      clientSaleId: clientSaleId ?? this.clientSaleId,
      orderIndex: orderIndex ?? this.orderIndex,
      method: method ?? this.method,
      amount: amount ?? this.amount,
      reference: reference ?? this.reference,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientSaleId.present) {
      map['client_sale_id'] = Variable<String>(clientSaleId.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (method.present) {
      map['method'] = Variable<int>(method.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (reference.present) {
      map['reference'] = Variable<String>(reference.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalPaymentsCompanion(')
          ..write('clientSaleId: $clientSaleId, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('method: $method, ')
          ..write('amount: $amount, ')
          ..write('reference: $reference, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueTable extends SyncQueue
    with TableInfo<$SyncQueueTable, SyncQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _operationIdMeta =
      const VerificationMeta('operationId');
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
      'operation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tenantIdMeta =
      const VerificationMeta('tenantId');
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
      'tenant_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _branchIdMeta =
      const VerificationMeta('branchId');
  @override
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
      'branch_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _operationTypeMeta =
      const VerificationMeta('operationType');
  @override
  late final GeneratedColumn<String> operationType = GeneratedColumn<String>(
      'operation_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _aggregateTypeMeta =
      const VerificationMeta('aggregateType');
  @override
  late final GeneratedColumn<String> aggregateType = GeneratedColumn<String>(
      'aggregate_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _aggregateIdMeta =
      const VerificationMeta('aggregateId');
  @override
  late final GeneratedColumn<String> aggregateId = GeneratedColumn<String>(
      'aggregate_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
      'status', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _attemptCountMeta =
      const VerificationMeta('attemptCount');
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
      'attempt_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastAttemptAtMeta =
      const VerificationMeta('lastAttemptAt');
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>('last_attempt_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _nextAttemptAtMeta =
      const VerificationMeta('nextAttemptAt');
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>('next_attempt_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _serverReferenceMeta =
      const VerificationMeta('serverReference');
  @override
  late final GeneratedColumn<String> serverReference = GeneratedColumn<String>(
      'server_reference', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _errorCodeMeta =
      const VerificationMeta('errorCode');
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
      'error_code', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _errorMessageMeta =
      const VerificationMeta('errorMessage');
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
      'error_message', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        operationId,
        tenantId,
        branchId,
        deviceId,
        operationType,
        aggregateType,
        aggregateId,
        payload,
        status,
        attemptCount,
        lastAttemptAt,
        nextAttemptAt,
        serverReference,
        errorCode,
        errorMessage,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue';
  @override
  VerificationContext validateIntegrity(Insertable<SyncQueueData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('operation_id')) {
      context.handle(
          _operationIdMeta,
          operationId.isAcceptableOrUnknown(
              data['operation_id']!, _operationIdMeta));
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(_tenantIdMeta,
          tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta));
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('branch_id')) {
      context.handle(_branchIdMeta,
          branchId.isAcceptableOrUnknown(data['branch_id']!, _branchIdMeta));
    } else if (isInserting) {
      context.missing(_branchIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('operation_type')) {
      context.handle(
          _operationTypeMeta,
          operationType.isAcceptableOrUnknown(
              data['operation_type']!, _operationTypeMeta));
    } else if (isInserting) {
      context.missing(_operationTypeMeta);
    }
    if (data.containsKey('aggregate_type')) {
      context.handle(
          _aggregateTypeMeta,
          aggregateType.isAcceptableOrUnknown(
              data['aggregate_type']!, _aggregateTypeMeta));
    } else if (isInserting) {
      context.missing(_aggregateTypeMeta);
    }
    if (data.containsKey('aggregate_id')) {
      context.handle(
          _aggregateIdMeta,
          aggregateId.isAcceptableOrUnknown(
              data['aggregate_id']!, _aggregateIdMeta));
    } else if (isInserting) {
      context.missing(_aggregateIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
          _attemptCountMeta,
          attemptCount.isAcceptableOrUnknown(
              data['attempt_count']!, _attemptCountMeta));
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
          _lastAttemptAtMeta,
          lastAttemptAt.isAcceptableOrUnknown(
              data['last_attempt_at']!, _lastAttemptAtMeta));
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
          _nextAttemptAtMeta,
          nextAttemptAt.isAcceptableOrUnknown(
              data['next_attempt_at']!, _nextAttemptAtMeta));
    }
    if (data.containsKey('server_reference')) {
      context.handle(
          _serverReferenceMeta,
          serverReference.isAcceptableOrUnknown(
              data['server_reference']!, _serverReferenceMeta));
    }
    if (data.containsKey('error_code')) {
      context.handle(_errorCodeMeta,
          errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta));
    }
    if (data.containsKey('error_message')) {
      context.handle(
          _errorMessageMeta,
          errorMessage.isAcceptableOrUnknown(
              data['error_message']!, _errorMessageMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {operationId};
  @override
  SyncQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueData(
      operationId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operation_id'])!,
      tenantId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tenant_id'])!,
      branchId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}branch_id'])!,
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      operationType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operation_type'])!,
      aggregateType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}aggregate_type'])!,
      aggregateId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}aggregate_id'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}status'])!,
      attemptCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempt_count'])!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_attempt_at']),
      nextAttemptAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}next_attempt_at']),
      serverReference: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}server_reference']),
      errorCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}error_code']),
      errorMessage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}error_message']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $SyncQueueTable createAlias(String alias) {
    return $SyncQueueTable(attachedDatabase, alias);
  }
}

class SyncQueueData extends DataClass implements Insertable<SyncQueueData> {
  final String operationId;
  final String tenantId;
  final String branchId;
  final String deviceId;
  final String operationType;
  final String aggregateType;
  final String aggregateId;
  final String payload;
  final int status;
  final int attemptCount;
  final DateTime? lastAttemptAt;
  final DateTime? nextAttemptAt;
  final String? serverReference;
  final String? errorCode;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  const SyncQueueData(
      {required this.operationId,
      required this.tenantId,
      required this.branchId,
      required this.deviceId,
      required this.operationType,
      required this.aggregateType,
      required this.aggregateId,
      required this.payload,
      required this.status,
      required this.attemptCount,
      this.lastAttemptAt,
      this.nextAttemptAt,
      this.serverReference,
      this.errorCode,
      this.errorMessage,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['operation_id'] = Variable<String>(operationId);
    map['tenant_id'] = Variable<String>(tenantId);
    map['branch_id'] = Variable<String>(branchId);
    map['device_id'] = Variable<String>(deviceId);
    map['operation_type'] = Variable<String>(operationType);
    map['aggregate_type'] = Variable<String>(aggregateType);
    map['aggregate_id'] = Variable<String>(aggregateId);
    map['payload'] = Variable<String>(payload);
    map['status'] = Variable<int>(status);
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    }
    if (!nullToAbsent || serverReference != null) {
      map['server_reference'] = Variable<String>(serverReference);
    }
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SyncQueueCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueCompanion(
      operationId: Value(operationId),
      tenantId: Value(tenantId),
      branchId: Value(branchId),
      deviceId: Value(deviceId),
      operationType: Value(operationType),
      aggregateType: Value(aggregateType),
      aggregateId: Value(aggregateId),
      payload: Value(payload),
      status: Value(status),
      attemptCount: Value(attemptCount),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      serverReference: serverReference == null && nullToAbsent
          ? const Value.absent()
          : Value(serverReference),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SyncQueueData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueData(
      operationId: serializer.fromJson<String>(json['operationId']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      branchId: serializer.fromJson<String>(json['branchId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      operationType: serializer.fromJson<String>(json['operationType']),
      aggregateType: serializer.fromJson<String>(json['aggregateType']),
      aggregateId: serializer.fromJson<String>(json['aggregateId']),
      payload: serializer.fromJson<String>(json['payload']),
      status: serializer.fromJson<int>(json['status']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
      serverReference: serializer.fromJson<String?>(json['serverReference']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'operationId': serializer.toJson<String>(operationId),
      'tenantId': serializer.toJson<String>(tenantId),
      'branchId': serializer.toJson<String>(branchId),
      'deviceId': serializer.toJson<String>(deviceId),
      'operationType': serializer.toJson<String>(operationType),
      'aggregateType': serializer.toJson<String>(aggregateType),
      'aggregateId': serializer.toJson<String>(aggregateId),
      'payload': serializer.toJson<String>(payload),
      'status': serializer.toJson<int>(status),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
      'serverReference': serializer.toJson<String?>(serverReference),
      'errorCode': serializer.toJson<String?>(errorCode),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SyncQueueData copyWith(
          {String? operationId,
          String? tenantId,
          String? branchId,
          String? deviceId,
          String? operationType,
          String? aggregateType,
          String? aggregateId,
          String? payload,
          int? status,
          int? attemptCount,
          Value<DateTime?> lastAttemptAt = const Value.absent(),
          Value<DateTime?> nextAttemptAt = const Value.absent(),
          Value<String?> serverReference = const Value.absent(),
          Value<String?> errorCode = const Value.absent(),
          Value<String?> errorMessage = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      SyncQueueData(
        operationId: operationId ?? this.operationId,
        tenantId: tenantId ?? this.tenantId,
        branchId: branchId ?? this.branchId,
        deviceId: deviceId ?? this.deviceId,
        operationType: operationType ?? this.operationType,
        aggregateType: aggregateType ?? this.aggregateType,
        aggregateId: aggregateId ?? this.aggregateId,
        payload: payload ?? this.payload,
        status: status ?? this.status,
        attemptCount: attemptCount ?? this.attemptCount,
        lastAttemptAt:
            lastAttemptAt.present ? lastAttemptAt.value : this.lastAttemptAt,
        nextAttemptAt:
            nextAttemptAt.present ? nextAttemptAt.value : this.nextAttemptAt,
        serverReference: serverReference.present
            ? serverReference.value
            : this.serverReference,
        errorCode: errorCode.present ? errorCode.value : this.errorCode,
        errorMessage:
            errorMessage.present ? errorMessage.value : this.errorMessage,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  SyncQueueData copyWithCompanion(SyncQueueCompanion data) {
    return SyncQueueData(
      operationId:
          data.operationId.present ? data.operationId.value : this.operationId,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      operationType: data.operationType.present
          ? data.operationType.value
          : this.operationType,
      aggregateType: data.aggregateType.present
          ? data.aggregateType.value
          : this.aggregateType,
      aggregateId:
          data.aggregateId.present ? data.aggregateId.value : this.aggregateId,
      payload: data.payload.present ? data.payload.value : this.payload,
      status: data.status.present ? data.status.value : this.status,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      serverReference: data.serverReference.present
          ? data.serverReference.value
          : this.serverReference,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueData(')
          ..write('operationId: $operationId, ')
          ..write('tenantId: $tenantId, ')
          ..write('branchId: $branchId, ')
          ..write('deviceId: $deviceId, ')
          ..write('operationType: $operationType, ')
          ..write('aggregateType: $aggregateType, ')
          ..write('aggregateId: $aggregateId, ')
          ..write('payload: $payload, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('serverReference: $serverReference, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      operationId,
      tenantId,
      branchId,
      deviceId,
      operationType,
      aggregateType,
      aggregateId,
      payload,
      status,
      attemptCount,
      lastAttemptAt,
      nextAttemptAt,
      serverReference,
      errorCode,
      errorMessage,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueData &&
          other.operationId == this.operationId &&
          other.tenantId == this.tenantId &&
          other.branchId == this.branchId &&
          other.deviceId == this.deviceId &&
          other.operationType == this.operationType &&
          other.aggregateType == this.aggregateType &&
          other.aggregateId == this.aggregateId &&
          other.payload == this.payload &&
          other.status == this.status &&
          other.attemptCount == this.attemptCount &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.serverReference == this.serverReference &&
          other.errorCode == this.errorCode &&
          other.errorMessage == this.errorMessage &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SyncQueueCompanion extends UpdateCompanion<SyncQueueData> {
  final Value<String> operationId;
  final Value<String> tenantId;
  final Value<String> branchId;
  final Value<String> deviceId;
  final Value<String> operationType;
  final Value<String> aggregateType;
  final Value<String> aggregateId;
  final Value<String> payload;
  final Value<int> status;
  final Value<int> attemptCount;
  final Value<DateTime?> lastAttemptAt;
  final Value<DateTime?> nextAttemptAt;
  final Value<String?> serverReference;
  final Value<String?> errorCode;
  final Value<String?> errorMessage;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SyncQueueCompanion({
    this.operationId = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.operationType = const Value.absent(),
    this.aggregateType = const Value.absent(),
    this.aggregateId = const Value.absent(),
    this.payload = const Value.absent(),
    this.status = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.serverReference = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncQueueCompanion.insert({
    required String operationId,
    required String tenantId,
    required String branchId,
    required String deviceId,
    required String operationType,
    required String aggregateType,
    required String aggregateId,
    required String payload,
    required int status,
    this.attemptCount = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.serverReference = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorMessage = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : operationId = Value(operationId),
        tenantId = Value(tenantId),
        branchId = Value(branchId),
        deviceId = Value(deviceId),
        operationType = Value(operationType),
        aggregateType = Value(aggregateType),
        aggregateId = Value(aggregateId),
        payload = Value(payload),
        status = Value(status),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<SyncQueueData> custom({
    Expression<String>? operationId,
    Expression<String>? tenantId,
    Expression<String>? branchId,
    Expression<String>? deviceId,
    Expression<String>? operationType,
    Expression<String>? aggregateType,
    Expression<String>? aggregateId,
    Expression<String>? payload,
    Expression<int>? status,
    Expression<int>? attemptCount,
    Expression<DateTime>? lastAttemptAt,
    Expression<DateTime>? nextAttemptAt,
    Expression<String>? serverReference,
    Expression<String>? errorCode,
    Expression<String>? errorMessage,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (operationId != null) 'operation_id': operationId,
      if (tenantId != null) 'tenant_id': tenantId,
      if (branchId != null) 'branch_id': branchId,
      if (deviceId != null) 'device_id': deviceId,
      if (operationType != null) 'operation_type': operationType,
      if (aggregateType != null) 'aggregate_type': aggregateType,
      if (aggregateId != null) 'aggregate_id': aggregateId,
      if (payload != null) 'payload': payload,
      if (status != null) 'status': status,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (serverReference != null) 'server_reference': serverReference,
      if (errorCode != null) 'error_code': errorCode,
      if (errorMessage != null) 'error_message': errorMessage,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncQueueCompanion copyWith(
      {Value<String>? operationId,
      Value<String>? tenantId,
      Value<String>? branchId,
      Value<String>? deviceId,
      Value<String>? operationType,
      Value<String>? aggregateType,
      Value<String>? aggregateId,
      Value<String>? payload,
      Value<int>? status,
      Value<int>? attemptCount,
      Value<DateTime?>? lastAttemptAt,
      Value<DateTime?>? nextAttemptAt,
      Value<String?>? serverReference,
      Value<String?>? errorCode,
      Value<String?>? errorMessage,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return SyncQueueCompanion(
      operationId: operationId ?? this.operationId,
      tenantId: tenantId ?? this.tenantId,
      branchId: branchId ?? this.branchId,
      deviceId: deviceId ?? this.deviceId,
      operationType: operationType ?? this.operationType,
      aggregateType: aggregateType ?? this.aggregateType,
      aggregateId: aggregateId ?? this.aggregateId,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      serverReference: serverReference ?? this.serverReference,
      errorCode: errorCode ?? this.errorCode,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (operationType.present) {
      map['operation_type'] = Variable<String>(operationType.value);
    }
    if (aggregateType.present) {
      map['aggregate_type'] = Variable<String>(aggregateType.value);
    }
    if (aggregateId.present) {
      map['aggregate_id'] = Variable<String>(aggregateId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (serverReference.present) {
      map['server_reference'] = Variable<String>(serverReference.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueCompanion(')
          ..write('operationId: $operationId, ')
          ..write('tenantId: $tenantId, ')
          ..write('branchId: $branchId, ')
          ..write('deviceId: $deviceId, ')
          ..write('operationType: $operationType, ')
          ..write('aggregateType: $aggregateType, ')
          ..write('aggregateId: $aggregateId, ')
          ..write('payload: $payload, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('serverReference: $serverReference, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalDatabase extends GeneratedDatabase {
  _$LocalDatabase(QueryExecutor e) : super(e);
  $LocalDatabaseManager get managers => $LocalDatabaseManager(this);
  late final $MetaEntriesTable metaEntries = $MetaEntriesTable(this);
  late final $CachedProductsTable cachedProducts = $CachedProductsTable(this);
  late final $CachedStockTable cachedStock = $CachedStockTable(this);
  late final $CachedWarehousesTable cachedWarehouses =
      $CachedWarehousesTable(this);
  late final $LocalSalesTable localSales = $LocalSalesTable(this);
  late final $LocalSaleLinesTable localSaleLines = $LocalSaleLinesTable(this);
  late final $LocalPaymentsTable localPayments = $LocalPaymentsTable(this);
  late final $SyncQueueTable syncQueue = $SyncQueueTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        metaEntries,
        cachedProducts,
        cachedStock,
        cachedWarehouses,
        localSales,
        localSaleLines,
        localPayments,
        syncQueue
      ];
}

typedef $$MetaEntriesTableCreateCompanionBuilder = MetaEntriesCompanion
    Function({
  required String key,
  required String value,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$MetaEntriesTableUpdateCompanionBuilder = MetaEntriesCompanion
    Function({
  Value<String> key,
  Value<String> value,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$MetaEntriesTableFilterComposer
    extends Composer<_$LocalDatabase, $MetaEntriesTable> {
  $$MetaEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$MetaEntriesTableOrderingComposer
    extends Composer<_$LocalDatabase, $MetaEntriesTable> {
  $$MetaEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$MetaEntriesTableAnnotationComposer
    extends Composer<_$LocalDatabase, $MetaEntriesTable> {
  $$MetaEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MetaEntriesTableTableManager extends RootTableManager<
    _$LocalDatabase,
    $MetaEntriesTable,
    MetaEntry,
    $$MetaEntriesTableFilterComposer,
    $$MetaEntriesTableOrderingComposer,
    $$MetaEntriesTableAnnotationComposer,
    $$MetaEntriesTableCreateCompanionBuilder,
    $$MetaEntriesTableUpdateCompanionBuilder,
    (MetaEntry, BaseReferences<_$LocalDatabase, $MetaEntriesTable, MetaEntry>),
    MetaEntry,
    PrefetchHooks Function()> {
  $$MetaEntriesTableTableManager(_$LocalDatabase db, $MetaEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetaEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetaEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetaEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MetaEntriesCompanion(
            key: key,
            value: value,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              MetaEntriesCompanion.insert(
            key: key,
            value: value,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$MetaEntriesTable, MetaEntry>(table),
                    BaseReferences<_$LocalDatabase, $MetaEntriesTable,
                        MetaEntry>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MetaEntriesTableProcessedTableManager = ProcessedTableManager<
    _$LocalDatabase,
    $MetaEntriesTable,
    MetaEntry,
    $$MetaEntriesTableFilterComposer,
    $$MetaEntriesTableOrderingComposer,
    $$MetaEntriesTableAnnotationComposer,
    $$MetaEntriesTableCreateCompanionBuilder,
    $$MetaEntriesTableUpdateCompanionBuilder,
    (MetaEntry, BaseReferences<_$LocalDatabase, $MetaEntriesTable, MetaEntry>),
    MetaEntry,
    PrefetchHooks Function()>;
typedef $$CachedProductsTableCreateCompanionBuilder = CachedProductsCompanion
    Function({
  required String tenantId,
  required String productId,
  required String name,
  Value<String?> sku,
  Value<String?> barcode,
  required int status,
  required bool sellable,
  required int productType,
  required double retailPrice,
  required String currency,
  required DateTime fetchedAt,
  Value<int> rowid,
});
typedef $$CachedProductsTableUpdateCompanionBuilder = CachedProductsCompanion
    Function({
  Value<String> tenantId,
  Value<String> productId,
  Value<String> name,
  Value<String?> sku,
  Value<String?> barcode,
  Value<int> status,
  Value<bool> sellable,
  Value<int> productType,
  Value<double> retailPrice,
  Value<String> currency,
  Value<DateTime> fetchedAt,
  Value<int> rowid,
});

class $$CachedProductsTableFilterComposer
    extends Composer<_$LocalDatabase, $CachedProductsTable> {
  $$CachedProductsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tenantId => $composableBuilder(
      column: $table.tenantId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sku => $composableBuilder(
      column: $table.sku, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get barcode => $composableBuilder(
      column: $table.barcode, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get sellable => $composableBuilder(
      column: $table.sellable, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get productType => $composableBuilder(
      column: $table.productType, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get retailPrice => $composableBuilder(
      column: $table.retailPrice, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnFilters(column));
}

class $$CachedProductsTableOrderingComposer
    extends Composer<_$LocalDatabase, $CachedProductsTable> {
  $$CachedProductsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tenantId => $composableBuilder(
      column: $table.tenantId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sku => $composableBuilder(
      column: $table.sku, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get barcode => $composableBuilder(
      column: $table.barcode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get sellable => $composableBuilder(
      column: $table.sellable, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get productType => $composableBuilder(
      column: $table.productType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get retailPrice => $composableBuilder(
      column: $table.retailPrice, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnOrderings(column));
}

class $$CachedProductsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $CachedProductsTable> {
  $$CachedProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get sku =>
      $composableBuilder(column: $table.sku, builder: (column) => column);

  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get sellable =>
      $composableBuilder(column: $table.sellable, builder: (column) => column);

  GeneratedColumn<int> get productType => $composableBuilder(
      column: $table.productType, builder: (column) => column);

  GeneratedColumn<double> get retailPrice => $composableBuilder(
      column: $table.retailPrice, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$CachedProductsTableTableManager extends RootTableManager<
    _$LocalDatabase,
    $CachedProductsTable,
    CachedProduct,
    $$CachedProductsTableFilterComposer,
    $$CachedProductsTableOrderingComposer,
    $$CachedProductsTableAnnotationComposer,
    $$CachedProductsTableCreateCompanionBuilder,
    $$CachedProductsTableUpdateCompanionBuilder,
    (
      CachedProduct,
      BaseReferences<_$LocalDatabase, $CachedProductsTable, CachedProduct>
    ),
    CachedProduct,
    PrefetchHooks Function()> {
  $$CachedProductsTableTableManager(
      _$LocalDatabase db, $CachedProductsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> tenantId = const Value.absent(),
            Value<String> productId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> sku = const Value.absent(),
            Value<String?> barcode = const Value.absent(),
            Value<int> status = const Value.absent(),
            Value<bool> sellable = const Value.absent(),
            Value<int> productType = const Value.absent(),
            Value<double> retailPrice = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<DateTime> fetchedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedProductsCompanion(
            tenantId: tenantId,
            productId: productId,
            name: name,
            sku: sku,
            barcode: barcode,
            status: status,
            sellable: sellable,
            productType: productType,
            retailPrice: retailPrice,
            currency: currency,
            fetchedAt: fetchedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String tenantId,
            required String productId,
            required String name,
            Value<String?> sku = const Value.absent(),
            Value<String?> barcode = const Value.absent(),
            required int status,
            required bool sellable,
            required int productType,
            required double retailPrice,
            required String currency,
            required DateTime fetchedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedProductsCompanion.insert(
            tenantId: tenantId,
            productId: productId,
            name: name,
            sku: sku,
            barcode: barcode,
            status: status,
            sellable: sellable,
            productType: productType,
            retailPrice: retailPrice,
            currency: currency,
            fetchedAt: fetchedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$CachedProductsTable, CachedProduct>(table),
                    BaseReferences<_$LocalDatabase, $CachedProductsTable,
                        CachedProduct>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedProductsTableProcessedTableManager = ProcessedTableManager<
    _$LocalDatabase,
    $CachedProductsTable,
    CachedProduct,
    $$CachedProductsTableFilterComposer,
    $$CachedProductsTableOrderingComposer,
    $$CachedProductsTableAnnotationComposer,
    $$CachedProductsTableCreateCompanionBuilder,
    $$CachedProductsTableUpdateCompanionBuilder,
    (
      CachedProduct,
      BaseReferences<_$LocalDatabase, $CachedProductsTable, CachedProduct>
    ),
    CachedProduct,
    PrefetchHooks Function()>;
typedef $$CachedStockTableCreateCompanionBuilder = CachedStockCompanion
    Function({
  required String tenantId,
  required String productId,
  required String warehouseId,
  required double quantity,
  required DateTime fetchedAt,
  Value<int> rowid,
});
typedef $$CachedStockTableUpdateCompanionBuilder = CachedStockCompanion
    Function({
  Value<String> tenantId,
  Value<String> productId,
  Value<String> warehouseId,
  Value<double> quantity,
  Value<DateTime> fetchedAt,
  Value<int> rowid,
});

class $$CachedStockTableFilterComposer
    extends Composer<_$LocalDatabase, $CachedStockTable> {
  $$CachedStockTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tenantId => $composableBuilder(
      column: $table.tenantId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get warehouseId => $composableBuilder(
      column: $table.warehouseId, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnFilters(column));
}

class $$CachedStockTableOrderingComposer
    extends Composer<_$LocalDatabase, $CachedStockTable> {
  $$CachedStockTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tenantId => $composableBuilder(
      column: $table.tenantId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get warehouseId => $composableBuilder(
      column: $table.warehouseId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnOrderings(column));
}

class $$CachedStockTableAnnotationComposer
    extends Composer<_$LocalDatabase, $CachedStockTable> {
  $$CachedStockTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get warehouseId => $composableBuilder(
      column: $table.warehouseId, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$CachedStockTableTableManager extends RootTableManager<
    _$LocalDatabase,
    $CachedStockTable,
    CachedStockData,
    $$CachedStockTableFilterComposer,
    $$CachedStockTableOrderingComposer,
    $$CachedStockTableAnnotationComposer,
    $$CachedStockTableCreateCompanionBuilder,
    $$CachedStockTableUpdateCompanionBuilder,
    (
      CachedStockData,
      BaseReferences<_$LocalDatabase, $CachedStockTable, CachedStockData>
    ),
    CachedStockData,
    PrefetchHooks Function()> {
  $$CachedStockTableTableManager(_$LocalDatabase db, $CachedStockTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedStockTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedStockTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedStockTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> tenantId = const Value.absent(),
            Value<String> productId = const Value.absent(),
            Value<String> warehouseId = const Value.absent(),
            Value<double> quantity = const Value.absent(),
            Value<DateTime> fetchedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedStockCompanion(
            tenantId: tenantId,
            productId: productId,
            warehouseId: warehouseId,
            quantity: quantity,
            fetchedAt: fetchedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String tenantId,
            required String productId,
            required String warehouseId,
            required double quantity,
            required DateTime fetchedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedStockCompanion.insert(
            tenantId: tenantId,
            productId: productId,
            warehouseId: warehouseId,
            quantity: quantity,
            fetchedAt: fetchedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$CachedStockTable, CachedStockData>(table),
                    BaseReferences<_$LocalDatabase, $CachedStockTable,
                        CachedStockData>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedStockTableProcessedTableManager = ProcessedTableManager<
    _$LocalDatabase,
    $CachedStockTable,
    CachedStockData,
    $$CachedStockTableFilterComposer,
    $$CachedStockTableOrderingComposer,
    $$CachedStockTableAnnotationComposer,
    $$CachedStockTableCreateCompanionBuilder,
    $$CachedStockTableUpdateCompanionBuilder,
    (
      CachedStockData,
      BaseReferences<_$LocalDatabase, $CachedStockTable, CachedStockData>
    ),
    CachedStockData,
    PrefetchHooks Function()>;
typedef $$CachedWarehousesTableCreateCompanionBuilder
    = CachedWarehousesCompanion Function({
  required String tenantId,
  required String warehouseId,
  required String name,
  required String code,
  required DateTime fetchedAt,
  Value<int> rowid,
});
typedef $$CachedWarehousesTableUpdateCompanionBuilder
    = CachedWarehousesCompanion Function({
  Value<String> tenantId,
  Value<String> warehouseId,
  Value<String> name,
  Value<String> code,
  Value<DateTime> fetchedAt,
  Value<int> rowid,
});

class $$CachedWarehousesTableFilterComposer
    extends Composer<_$LocalDatabase, $CachedWarehousesTable> {
  $$CachedWarehousesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tenantId => $composableBuilder(
      column: $table.tenantId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get warehouseId => $composableBuilder(
      column: $table.warehouseId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnFilters(column));
}

class $$CachedWarehousesTableOrderingComposer
    extends Composer<_$LocalDatabase, $CachedWarehousesTable> {
  $$CachedWarehousesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tenantId => $composableBuilder(
      column: $table.tenantId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get warehouseId => $composableBuilder(
      column: $table.warehouseId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnOrderings(column));
}

class $$CachedWarehousesTableAnnotationComposer
    extends Composer<_$LocalDatabase, $CachedWarehousesTable> {
  $$CachedWarehousesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get warehouseId => $composableBuilder(
      column: $table.warehouseId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$CachedWarehousesTableTableManager extends RootTableManager<
    _$LocalDatabase,
    $CachedWarehousesTable,
    CachedWarehouse,
    $$CachedWarehousesTableFilterComposer,
    $$CachedWarehousesTableOrderingComposer,
    $$CachedWarehousesTableAnnotationComposer,
    $$CachedWarehousesTableCreateCompanionBuilder,
    $$CachedWarehousesTableUpdateCompanionBuilder,
    (
      CachedWarehouse,
      BaseReferences<_$LocalDatabase, $CachedWarehousesTable, CachedWarehouse>
    ),
    CachedWarehouse,
    PrefetchHooks Function()> {
  $$CachedWarehousesTableTableManager(
      _$LocalDatabase db, $CachedWarehousesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedWarehousesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedWarehousesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedWarehousesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> tenantId = const Value.absent(),
            Value<String> warehouseId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> code = const Value.absent(),
            Value<DateTime> fetchedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedWarehousesCompanion(
            tenantId: tenantId,
            warehouseId: warehouseId,
            name: name,
            code: code,
            fetchedAt: fetchedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String tenantId,
            required String warehouseId,
            required String name,
            required String code,
            required DateTime fetchedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedWarehousesCompanion.insert(
            tenantId: tenantId,
            warehouseId: warehouseId,
            name: name,
            code: code,
            fetchedAt: fetchedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$CachedWarehousesTable, CachedWarehouse>(table),
                    BaseReferences<_$LocalDatabase, $CachedWarehousesTable,
                        CachedWarehouse>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedWarehousesTableProcessedTableManager = ProcessedTableManager<
    _$LocalDatabase,
    $CachedWarehousesTable,
    CachedWarehouse,
    $$CachedWarehousesTableFilterComposer,
    $$CachedWarehousesTableOrderingComposer,
    $$CachedWarehousesTableAnnotationComposer,
    $$CachedWarehousesTableCreateCompanionBuilder,
    $$CachedWarehousesTableUpdateCompanionBuilder,
    (
      CachedWarehouse,
      BaseReferences<_$LocalDatabase, $CachedWarehousesTable, CachedWarehouse>
    ),
    CachedWarehouse,
    PrefetchHooks Function()>;
typedef $$LocalSalesTableCreateCompanionBuilder = LocalSalesCompanion Function({
  required String clientSaleId,
  required String tenantId,
  required String branchId,
  required String deviceId,
  required String userId,
  required int status,
  required String currency,
  required DateTime effectiveAt,
  required DateTime createdAt,
  Value<DateTime?> syncedAt,
  Value<double> subtotalEstimate,
  Value<double> taxEstimate,
  required double totalEstimate,
  required int paymentMethod,
  required double paymentAmount,
  Value<String?> serverSaleId,
  Value<String?> serverNumber,
  Value<String?> errorCode,
  Value<String?> errorMessage,
  Value<int> attemptCount,
  Value<DateTime?> lastAttemptAt,
  Value<int> rowid,
});
typedef $$LocalSalesTableUpdateCompanionBuilder = LocalSalesCompanion Function({
  Value<String> clientSaleId,
  Value<String> tenantId,
  Value<String> branchId,
  Value<String> deviceId,
  Value<String> userId,
  Value<int> status,
  Value<String> currency,
  Value<DateTime> effectiveAt,
  Value<DateTime> createdAt,
  Value<DateTime?> syncedAt,
  Value<double> subtotalEstimate,
  Value<double> taxEstimate,
  Value<double> totalEstimate,
  Value<int> paymentMethod,
  Value<double> paymentAmount,
  Value<String?> serverSaleId,
  Value<String?> serverNumber,
  Value<String?> errorCode,
  Value<String?> errorMessage,
  Value<int> attemptCount,
  Value<DateTime?> lastAttemptAt,
  Value<int> rowid,
});

class $$LocalSalesTableFilterComposer
    extends Composer<_$LocalDatabase, $LocalSalesTable> {
  $$LocalSalesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientSaleId => $composableBuilder(
      column: $table.clientSaleId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tenantId => $composableBuilder(
      column: $table.tenantId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get effectiveAt => $composableBuilder(
      column: $table.effectiveAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get subtotalEstimate => $composableBuilder(
      column: $table.subtotalEstimate,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get taxEstimate => $composableBuilder(
      column: $table.taxEstimate, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get totalEstimate => $composableBuilder(
      column: $table.totalEstimate, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get paymentMethod => $composableBuilder(
      column: $table.paymentMethod, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get paymentAmount => $composableBuilder(
      column: $table.paymentAmount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serverSaleId => $composableBuilder(
      column: $table.serverSaleId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serverNumber => $composableBuilder(
      column: $table.serverNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get errorCode => $composableBuilder(
      column: $table.errorCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
      column: $table.lastAttemptAt, builder: (column) => ColumnFilters(column));
}

class $$LocalSalesTableOrderingComposer
    extends Composer<_$LocalDatabase, $LocalSalesTable> {
  $$LocalSalesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientSaleId => $composableBuilder(
      column: $table.clientSaleId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tenantId => $composableBuilder(
      column: $table.tenantId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get effectiveAt => $composableBuilder(
      column: $table.effectiveAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get subtotalEstimate => $composableBuilder(
      column: $table.subtotalEstimate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get taxEstimate => $composableBuilder(
      column: $table.taxEstimate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get totalEstimate => $composableBuilder(
      column: $table.totalEstimate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get paymentMethod => $composableBuilder(
      column: $table.paymentMethod,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get paymentAmount => $composableBuilder(
      column: $table.paymentAmount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serverSaleId => $composableBuilder(
      column: $table.serverSaleId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serverNumber => $composableBuilder(
      column: $table.serverNumber,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get errorCode => $composableBuilder(
      column: $table.errorCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
      column: $table.lastAttemptAt,
      builder: (column) => ColumnOrderings(column));
}

class $$LocalSalesTableAnnotationComposer
    extends Composer<_$LocalDatabase, $LocalSalesTable> {
  $$LocalSalesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientSaleId => $composableBuilder(
      column: $table.clientSaleId, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get branchId =>
      $composableBuilder(column: $table.branchId, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<DateTime> get effectiveAt => $composableBuilder(
      column: $table.effectiveAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<double> get subtotalEstimate => $composableBuilder(
      column: $table.subtotalEstimate, builder: (column) => column);

  GeneratedColumn<double> get taxEstimate => $composableBuilder(
      column: $table.taxEstimate, builder: (column) => column);

  GeneratedColumn<double> get totalEstimate => $composableBuilder(
      column: $table.totalEstimate, builder: (column) => column);

  GeneratedColumn<int> get paymentMethod => $composableBuilder(
      column: $table.paymentMethod, builder: (column) => column);

  GeneratedColumn<double> get paymentAmount => $composableBuilder(
      column: $table.paymentAmount, builder: (column) => column);

  GeneratedColumn<String> get serverSaleId => $composableBuilder(
      column: $table.serverSaleId, builder: (column) => column);

  GeneratedColumn<String> get serverNumber => $composableBuilder(
      column: $table.serverNumber, builder: (column) => column);

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
      column: $table.lastAttemptAt, builder: (column) => column);
}

class $$LocalSalesTableTableManager extends RootTableManager<
    _$LocalDatabase,
    $LocalSalesTable,
    LocalSale,
    $$LocalSalesTableFilterComposer,
    $$LocalSalesTableOrderingComposer,
    $$LocalSalesTableAnnotationComposer,
    $$LocalSalesTableCreateCompanionBuilder,
    $$LocalSalesTableUpdateCompanionBuilder,
    (LocalSale, BaseReferences<_$LocalDatabase, $LocalSalesTable, LocalSale>),
    LocalSale,
    PrefetchHooks Function()> {
  $$LocalSalesTableTableManager(_$LocalDatabase db, $LocalSalesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSalesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSalesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSalesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientSaleId = const Value.absent(),
            Value<String> tenantId = const Value.absent(),
            Value<String> branchId = const Value.absent(),
            Value<String> deviceId = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<int> status = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<DateTime> effectiveAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> syncedAt = const Value.absent(),
            Value<double> subtotalEstimate = const Value.absent(),
            Value<double> taxEstimate = const Value.absent(),
            Value<double> totalEstimate = const Value.absent(),
            Value<int> paymentMethod = const Value.absent(),
            Value<double> paymentAmount = const Value.absent(),
            Value<String?> serverSaleId = const Value.absent(),
            Value<String?> serverNumber = const Value.absent(),
            Value<String?> errorCode = const Value.absent(),
            Value<String?> errorMessage = const Value.absent(),
            Value<int> attemptCount = const Value.absent(),
            Value<DateTime?> lastAttemptAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalSalesCompanion(
            clientSaleId: clientSaleId,
            tenantId: tenantId,
            branchId: branchId,
            deviceId: deviceId,
            userId: userId,
            status: status,
            currency: currency,
            effectiveAt: effectiveAt,
            createdAt: createdAt,
            syncedAt: syncedAt,
            subtotalEstimate: subtotalEstimate,
            taxEstimate: taxEstimate,
            totalEstimate: totalEstimate,
            paymentMethod: paymentMethod,
            paymentAmount: paymentAmount,
            serverSaleId: serverSaleId,
            serverNumber: serverNumber,
            errorCode: errorCode,
            errorMessage: errorMessage,
            attemptCount: attemptCount,
            lastAttemptAt: lastAttemptAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String clientSaleId,
            required String tenantId,
            required String branchId,
            required String deviceId,
            required String userId,
            required int status,
            required String currency,
            required DateTime effectiveAt,
            required DateTime createdAt,
            Value<DateTime?> syncedAt = const Value.absent(),
            Value<double> subtotalEstimate = const Value.absent(),
            Value<double> taxEstimate = const Value.absent(),
            required double totalEstimate,
            required int paymentMethod,
            required double paymentAmount,
            Value<String?> serverSaleId = const Value.absent(),
            Value<String?> serverNumber = const Value.absent(),
            Value<String?> errorCode = const Value.absent(),
            Value<String?> errorMessage = const Value.absent(),
            Value<int> attemptCount = const Value.absent(),
            Value<DateTime?> lastAttemptAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalSalesCompanion.insert(
            clientSaleId: clientSaleId,
            tenantId: tenantId,
            branchId: branchId,
            deviceId: deviceId,
            userId: userId,
            status: status,
            currency: currency,
            effectiveAt: effectiveAt,
            createdAt: createdAt,
            syncedAt: syncedAt,
            subtotalEstimate: subtotalEstimate,
            taxEstimate: taxEstimate,
            totalEstimate: totalEstimate,
            paymentMethod: paymentMethod,
            paymentAmount: paymentAmount,
            serverSaleId: serverSaleId,
            serverNumber: serverNumber,
            errorCode: errorCode,
            errorMessage: errorMessage,
            attemptCount: attemptCount,
            lastAttemptAt: lastAttemptAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$LocalSalesTable, LocalSale>(table),
                    BaseReferences<_$LocalDatabase, $LocalSalesTable,
                        LocalSale>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalSalesTableProcessedTableManager = ProcessedTableManager<
    _$LocalDatabase,
    $LocalSalesTable,
    LocalSale,
    $$LocalSalesTableFilterComposer,
    $$LocalSalesTableOrderingComposer,
    $$LocalSalesTableAnnotationComposer,
    $$LocalSalesTableCreateCompanionBuilder,
    $$LocalSalesTableUpdateCompanionBuilder,
    (LocalSale, BaseReferences<_$LocalDatabase, $LocalSalesTable, LocalSale>),
    LocalSale,
    PrefetchHooks Function()>;
typedef $$LocalSaleLinesTableCreateCompanionBuilder = LocalSaleLinesCompanion
    Function({
  required String clientSaleId,
  required int orderIndex,
  required String productId,
  required String productName,
  Value<String?> sku,
  required double quantity,
  required double unitPriceSnapshot,
  required double lineTotalEstimate,
  Value<int> rowid,
});
typedef $$LocalSaleLinesTableUpdateCompanionBuilder = LocalSaleLinesCompanion
    Function({
  Value<String> clientSaleId,
  Value<int> orderIndex,
  Value<String> productId,
  Value<String> productName,
  Value<String?> sku,
  Value<double> quantity,
  Value<double> unitPriceSnapshot,
  Value<double> lineTotalEstimate,
  Value<int> rowid,
});

class $$LocalSaleLinesTableFilterComposer
    extends Composer<_$LocalDatabase, $LocalSaleLinesTable> {
  $$LocalSaleLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientSaleId => $composableBuilder(
      column: $table.clientSaleId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get orderIndex => $composableBuilder(
      column: $table.orderIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get productName => $composableBuilder(
      column: $table.productName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sku => $composableBuilder(
      column: $table.sku, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get unitPriceSnapshot => $composableBuilder(
      column: $table.unitPriceSnapshot,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lineTotalEstimate => $composableBuilder(
      column: $table.lineTotalEstimate,
      builder: (column) => ColumnFilters(column));
}

class $$LocalSaleLinesTableOrderingComposer
    extends Composer<_$LocalDatabase, $LocalSaleLinesTable> {
  $$LocalSaleLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientSaleId => $composableBuilder(
      column: $table.clientSaleId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get orderIndex => $composableBuilder(
      column: $table.orderIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get productName => $composableBuilder(
      column: $table.productName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sku => $composableBuilder(
      column: $table.sku, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get unitPriceSnapshot => $composableBuilder(
      column: $table.unitPriceSnapshot,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lineTotalEstimate => $composableBuilder(
      column: $table.lineTotalEstimate,
      builder: (column) => ColumnOrderings(column));
}

class $$LocalSaleLinesTableAnnotationComposer
    extends Composer<_$LocalDatabase, $LocalSaleLinesTable> {
  $$LocalSaleLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientSaleId => $composableBuilder(
      column: $table.clientSaleId, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
      column: $table.orderIndex, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get productName => $composableBuilder(
      column: $table.productName, builder: (column) => column);

  GeneratedColumn<String> get sku =>
      $composableBuilder(column: $table.sku, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get unitPriceSnapshot => $composableBuilder(
      column: $table.unitPriceSnapshot, builder: (column) => column);

  GeneratedColumn<double> get lineTotalEstimate => $composableBuilder(
      column: $table.lineTotalEstimate, builder: (column) => column);
}

class $$LocalSaleLinesTableTableManager extends RootTableManager<
    _$LocalDatabase,
    $LocalSaleLinesTable,
    LocalSaleLine,
    $$LocalSaleLinesTableFilterComposer,
    $$LocalSaleLinesTableOrderingComposer,
    $$LocalSaleLinesTableAnnotationComposer,
    $$LocalSaleLinesTableCreateCompanionBuilder,
    $$LocalSaleLinesTableUpdateCompanionBuilder,
    (
      LocalSaleLine,
      BaseReferences<_$LocalDatabase, $LocalSaleLinesTable, LocalSaleLine>
    ),
    LocalSaleLine,
    PrefetchHooks Function()> {
  $$LocalSaleLinesTableTableManager(
      _$LocalDatabase db, $LocalSaleLinesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSaleLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSaleLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSaleLinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientSaleId = const Value.absent(),
            Value<int> orderIndex = const Value.absent(),
            Value<String> productId = const Value.absent(),
            Value<String> productName = const Value.absent(),
            Value<String?> sku = const Value.absent(),
            Value<double> quantity = const Value.absent(),
            Value<double> unitPriceSnapshot = const Value.absent(),
            Value<double> lineTotalEstimate = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalSaleLinesCompanion(
            clientSaleId: clientSaleId,
            orderIndex: orderIndex,
            productId: productId,
            productName: productName,
            sku: sku,
            quantity: quantity,
            unitPriceSnapshot: unitPriceSnapshot,
            lineTotalEstimate: lineTotalEstimate,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String clientSaleId,
            required int orderIndex,
            required String productId,
            required String productName,
            Value<String?> sku = const Value.absent(),
            required double quantity,
            required double unitPriceSnapshot,
            required double lineTotalEstimate,
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalSaleLinesCompanion.insert(
            clientSaleId: clientSaleId,
            orderIndex: orderIndex,
            productId: productId,
            productName: productName,
            sku: sku,
            quantity: quantity,
            unitPriceSnapshot: unitPriceSnapshot,
            lineTotalEstimate: lineTotalEstimate,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$LocalSaleLinesTable, LocalSaleLine>(table),
                    BaseReferences<_$LocalDatabase, $LocalSaleLinesTable,
                        LocalSaleLine>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalSaleLinesTableProcessedTableManager = ProcessedTableManager<
    _$LocalDatabase,
    $LocalSaleLinesTable,
    LocalSaleLine,
    $$LocalSaleLinesTableFilterComposer,
    $$LocalSaleLinesTableOrderingComposer,
    $$LocalSaleLinesTableAnnotationComposer,
    $$LocalSaleLinesTableCreateCompanionBuilder,
    $$LocalSaleLinesTableUpdateCompanionBuilder,
    (
      LocalSaleLine,
      BaseReferences<_$LocalDatabase, $LocalSaleLinesTable, LocalSaleLine>
    ),
    LocalSaleLine,
    PrefetchHooks Function()>;
typedef $$LocalPaymentsTableCreateCompanionBuilder = LocalPaymentsCompanion
    Function({
  required String clientSaleId,
  required int orderIndex,
  required int method,
  required double amount,
  Value<String?> reference,
  Value<int> rowid,
});
typedef $$LocalPaymentsTableUpdateCompanionBuilder = LocalPaymentsCompanion
    Function({
  Value<String> clientSaleId,
  Value<int> orderIndex,
  Value<int> method,
  Value<double> amount,
  Value<String?> reference,
  Value<int> rowid,
});

class $$LocalPaymentsTableFilterComposer
    extends Composer<_$LocalDatabase, $LocalPaymentsTable> {
  $$LocalPaymentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientSaleId => $composableBuilder(
      column: $table.clientSaleId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get orderIndex => $composableBuilder(
      column: $table.orderIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get method => $composableBuilder(
      column: $table.method, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reference => $composableBuilder(
      column: $table.reference, builder: (column) => ColumnFilters(column));
}

class $$LocalPaymentsTableOrderingComposer
    extends Composer<_$LocalDatabase, $LocalPaymentsTable> {
  $$LocalPaymentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientSaleId => $composableBuilder(
      column: $table.clientSaleId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get orderIndex => $composableBuilder(
      column: $table.orderIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get method => $composableBuilder(
      column: $table.method, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reference => $composableBuilder(
      column: $table.reference, builder: (column) => ColumnOrderings(column));
}

class $$LocalPaymentsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $LocalPaymentsTable> {
  $$LocalPaymentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientSaleId => $composableBuilder(
      column: $table.clientSaleId, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
      column: $table.orderIndex, builder: (column) => column);

  GeneratedColumn<int> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get reference =>
      $composableBuilder(column: $table.reference, builder: (column) => column);
}

class $$LocalPaymentsTableTableManager extends RootTableManager<
    _$LocalDatabase,
    $LocalPaymentsTable,
    LocalPayment,
    $$LocalPaymentsTableFilterComposer,
    $$LocalPaymentsTableOrderingComposer,
    $$LocalPaymentsTableAnnotationComposer,
    $$LocalPaymentsTableCreateCompanionBuilder,
    $$LocalPaymentsTableUpdateCompanionBuilder,
    (
      LocalPayment,
      BaseReferences<_$LocalDatabase, $LocalPaymentsTable, LocalPayment>
    ),
    LocalPayment,
    PrefetchHooks Function()> {
  $$LocalPaymentsTableTableManager(
      _$LocalDatabase db, $LocalPaymentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalPaymentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalPaymentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalPaymentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientSaleId = const Value.absent(),
            Value<int> orderIndex = const Value.absent(),
            Value<int> method = const Value.absent(),
            Value<double> amount = const Value.absent(),
            Value<String?> reference = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalPaymentsCompanion(
            clientSaleId: clientSaleId,
            orderIndex: orderIndex,
            method: method,
            amount: amount,
            reference: reference,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String clientSaleId,
            required int orderIndex,
            required int method,
            required double amount,
            Value<String?> reference = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalPaymentsCompanion.insert(
            clientSaleId: clientSaleId,
            orderIndex: orderIndex,
            method: method,
            amount: amount,
            reference: reference,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$LocalPaymentsTable, LocalPayment>(table),
                    BaseReferences<_$LocalDatabase, $LocalPaymentsTable,
                        LocalPayment>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalPaymentsTableProcessedTableManager = ProcessedTableManager<
    _$LocalDatabase,
    $LocalPaymentsTable,
    LocalPayment,
    $$LocalPaymentsTableFilterComposer,
    $$LocalPaymentsTableOrderingComposer,
    $$LocalPaymentsTableAnnotationComposer,
    $$LocalPaymentsTableCreateCompanionBuilder,
    $$LocalPaymentsTableUpdateCompanionBuilder,
    (
      LocalPayment,
      BaseReferences<_$LocalDatabase, $LocalPaymentsTable, LocalPayment>
    ),
    LocalPayment,
    PrefetchHooks Function()>;
typedef $$SyncQueueTableCreateCompanionBuilder = SyncQueueCompanion Function({
  required String operationId,
  required String tenantId,
  required String branchId,
  required String deviceId,
  required String operationType,
  required String aggregateType,
  required String aggregateId,
  required String payload,
  required int status,
  Value<int> attemptCount,
  Value<DateTime?> lastAttemptAt,
  Value<DateTime?> nextAttemptAt,
  Value<String?> serverReference,
  Value<String?> errorCode,
  Value<String?> errorMessage,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$SyncQueueTableUpdateCompanionBuilder = SyncQueueCompanion Function({
  Value<String> operationId,
  Value<String> tenantId,
  Value<String> branchId,
  Value<String> deviceId,
  Value<String> operationType,
  Value<String> aggregateType,
  Value<String> aggregateId,
  Value<String> payload,
  Value<int> status,
  Value<int> attemptCount,
  Value<DateTime?> lastAttemptAt,
  Value<DateTime?> nextAttemptAt,
  Value<String?> serverReference,
  Value<String?> errorCode,
  Value<String?> errorMessage,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$SyncQueueTableFilterComposer
    extends Composer<_$LocalDatabase, $SyncQueueTable> {
  $$SyncQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get operationId => $composableBuilder(
      column: $table.operationId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tenantId => $composableBuilder(
      column: $table.tenantId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get operationType => $composableBuilder(
      column: $table.operationType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get aggregateType => $composableBuilder(
      column: $table.aggregateType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get aggregateId => $composableBuilder(
      column: $table.aggregateId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
      column: $table.lastAttemptAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
      column: $table.nextAttemptAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serverReference => $composableBuilder(
      column: $table.serverReference,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get errorCode => $composableBuilder(
      column: $table.errorCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$SyncQueueTableOrderingComposer
    extends Composer<_$LocalDatabase, $SyncQueueTable> {
  $$SyncQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get operationId => $composableBuilder(
      column: $table.operationId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tenantId => $composableBuilder(
      column: $table.tenantId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get operationType => $composableBuilder(
      column: $table.operationType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get aggregateType => $composableBuilder(
      column: $table.aggregateType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get aggregateId => $composableBuilder(
      column: $table.aggregateId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
      column: $table.lastAttemptAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
      column: $table.nextAttemptAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serverReference => $composableBuilder(
      column: $table.serverReference,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get errorCode => $composableBuilder(
      column: $table.errorCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$SyncQueueTableAnnotationComposer
    extends Composer<_$LocalDatabase, $SyncQueueTable> {
  $$SyncQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get operationId => $composableBuilder(
      column: $table.operationId, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get branchId =>
      $composableBuilder(column: $table.branchId, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get operationType => $composableBuilder(
      column: $table.operationType, builder: (column) => column);

  GeneratedColumn<String> get aggregateType => $composableBuilder(
      column: $table.aggregateType, builder: (column) => column);

  GeneratedColumn<String> get aggregateId => $composableBuilder(
      column: $table.aggregateId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
      column: $table.lastAttemptAt, builder: (column) => column);

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
      column: $table.nextAttemptAt, builder: (column) => column);

  GeneratedColumn<String> get serverReference => $composableBuilder(
      column: $table.serverReference, builder: (column) => column);

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SyncQueueTableTableManager extends RootTableManager<
    _$LocalDatabase,
    $SyncQueueTable,
    SyncQueueData,
    $$SyncQueueTableFilterComposer,
    $$SyncQueueTableOrderingComposer,
    $$SyncQueueTableAnnotationComposer,
    $$SyncQueueTableCreateCompanionBuilder,
    $$SyncQueueTableUpdateCompanionBuilder,
    (
      SyncQueueData,
      BaseReferences<_$LocalDatabase, $SyncQueueTable, SyncQueueData>
    ),
    SyncQueueData,
    PrefetchHooks Function()> {
  $$SyncQueueTableTableManager(_$LocalDatabase db, $SyncQueueTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> operationId = const Value.absent(),
            Value<String> tenantId = const Value.absent(),
            Value<String> branchId = const Value.absent(),
            Value<String> deviceId = const Value.absent(),
            Value<String> operationType = const Value.absent(),
            Value<String> aggregateType = const Value.absent(),
            Value<String> aggregateId = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<int> status = const Value.absent(),
            Value<int> attemptCount = const Value.absent(),
            Value<DateTime?> lastAttemptAt = const Value.absent(),
            Value<DateTime?> nextAttemptAt = const Value.absent(),
            Value<String?> serverReference = const Value.absent(),
            Value<String?> errorCode = const Value.absent(),
            Value<String?> errorMessage = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncQueueCompanion(
            operationId: operationId,
            tenantId: tenantId,
            branchId: branchId,
            deviceId: deviceId,
            operationType: operationType,
            aggregateType: aggregateType,
            aggregateId: aggregateId,
            payload: payload,
            status: status,
            attemptCount: attemptCount,
            lastAttemptAt: lastAttemptAt,
            nextAttemptAt: nextAttemptAt,
            serverReference: serverReference,
            errorCode: errorCode,
            errorMessage: errorMessage,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String operationId,
            required String tenantId,
            required String branchId,
            required String deviceId,
            required String operationType,
            required String aggregateType,
            required String aggregateId,
            required String payload,
            required int status,
            Value<int> attemptCount = const Value.absent(),
            Value<DateTime?> lastAttemptAt = const Value.absent(),
            Value<DateTime?> nextAttemptAt = const Value.absent(),
            Value<String?> serverReference = const Value.absent(),
            Value<String?> errorCode = const Value.absent(),
            Value<String?> errorMessage = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncQueueCompanion.insert(
            operationId: operationId,
            tenantId: tenantId,
            branchId: branchId,
            deviceId: deviceId,
            operationType: operationType,
            aggregateType: aggregateType,
            aggregateId: aggregateId,
            payload: payload,
            status: status,
            attemptCount: attemptCount,
            lastAttemptAt: lastAttemptAt,
            nextAttemptAt: nextAttemptAt,
            serverReference: serverReference,
            errorCode: errorCode,
            errorMessage: errorMessage,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SyncQueueTable, SyncQueueData>(table),
                    BaseReferences<_$LocalDatabase, $SyncQueueTable,
                        SyncQueueData>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncQueueTableProcessedTableManager = ProcessedTableManager<
    _$LocalDatabase,
    $SyncQueueTable,
    SyncQueueData,
    $$SyncQueueTableFilterComposer,
    $$SyncQueueTableOrderingComposer,
    $$SyncQueueTableAnnotationComposer,
    $$SyncQueueTableCreateCompanionBuilder,
    $$SyncQueueTableUpdateCompanionBuilder,
    (
      SyncQueueData,
      BaseReferences<_$LocalDatabase, $SyncQueueTable, SyncQueueData>
    ),
    SyncQueueData,
    PrefetchHooks Function()>;

class $LocalDatabaseManager {
  final _$LocalDatabase _db;
  $LocalDatabaseManager(this._db);
  $$MetaEntriesTableTableManager get metaEntries =>
      $$MetaEntriesTableTableManager(_db, _db.metaEntries);
  $$CachedProductsTableTableManager get cachedProducts =>
      $$CachedProductsTableTableManager(_db, _db.cachedProducts);
  $$CachedStockTableTableManager get cachedStock =>
      $$CachedStockTableTableManager(_db, _db.cachedStock);
  $$CachedWarehousesTableTableManager get cachedWarehouses =>
      $$CachedWarehousesTableTableManager(_db, _db.cachedWarehouses);
  $$LocalSalesTableTableManager get localSales =>
      $$LocalSalesTableTableManager(_db, _db.localSales);
  $$LocalSaleLinesTableTableManager get localSaleLines =>
      $$LocalSaleLinesTableTableManager(_db, _db.localSaleLines);
  $$LocalPaymentsTableTableManager get localPayments =>
      $$LocalPaymentsTableTableManager(_db, _db.localPayments);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db, _db.syncQueue);
}
