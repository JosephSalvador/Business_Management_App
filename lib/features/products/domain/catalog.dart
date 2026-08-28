class UnitOfMeasure {
  const UnitOfMeasure({required this.id, required this.name, required this.abbreviation});

  final String id;
  final String name;
  final String abbreviation;

  factory UnitOfMeasure.fromJson(Map<String, dynamic> json) => UnitOfMeasure(
        id: json['id'] as String,
        name: json['name'] as String,
        abbreviation: json['abbreviation'] as String,
      );
}

class TaxCategory {
  const TaxCategory({required this.id, required this.code, required this.name});

  final String id;
  final String code;
  final String name;

  factory TaxCategory.fromJson(Map<String, dynamic> json) => TaxCategory(
        id: json['id'] as String,
        code: json['code'] as String,
        name: json['name'] as String,
      );
}

class Warehouse {
  const Warehouse({required this.id, required this.name, required this.code});

  final String id;
  final String name;
  final String code;

  factory Warehouse.fromJson(Map<String, dynamic> json) => Warehouse(
        id: json['id'] as String,
        name: json['name'] as String,
        code: json['code'] as String,
      );
}

/// One row of `GET /inventory/stock` — quantity of a product in one location.
class StockBalance {
  const StockBalance({
    required this.warehouseId,
    required this.productId,
    this.quantity = 0,
  });

  final String warehouseId;
  final String productId;
  final double quantity;

  factory StockBalance.fromJson(Map<String, dynamic> json) => StockBalance(
        warehouseId: json['warehouseId'] as String,
        productId: json['productId'] as String,
        quantity: (json['quantity'] as num).toDouble(),
      );
}

class PriceList {
  const PriceList({
    required this.id,
    required this.name,
    required this.currency,
    required this.isDefault,
  });

  final String id;
  final String name;
  final String currency;
  final bool isDefault;

  factory PriceList.fromJson(Map<String, dynamic> json) => PriceList(
        id: json['id'] as String,
        name: json['name'] as String,
        currency: json['currency'] as String,
        isDefault: json['isDefault'] as bool,
      );
}

/// A price row on a price list. [priceType] mirrors the backend int enum
/// (0 = Retail, 1 = Wholesale).
class ProductPrice {
  const ProductPrice({
    this.id,
    required this.productId,
    required this.priceType,
    required this.price,
    required this.currency,
    this.minQuantity = 1,
  });

  final String? id;
  final String productId;
  final int priceType;
  final double price;
  final String currency;
  final double minQuantity;

  factory ProductPrice.fromJson(Map<String, dynamic> json) => ProductPrice(
        id: json['id'] as String?,
        productId: json['productId'] as String,
        priceType: (json['priceType'] as num).toInt(),
        price: (json['price'] as num).toDouble(),
        currency: json['currency'] as String,
        minQuantity: (json['minQuantity'] as num?)?.toDouble() ?? 1,
      );

  Map<String, dynamic> toBody() => {
        if (id != null) 'id': id,
        'productId': productId,
        'priceType': priceType,
        'price': price,
        'currency': currency,
        'minQuantity': minQuantity,
        'isActive': true,
      };
}
