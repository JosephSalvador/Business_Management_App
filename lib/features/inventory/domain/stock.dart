/// Mirrors the backend `StockMovementType` int enum.
abstract final class StockMovementType {
  static const int openingStock = 0;
  static const int sale = 1;
  static const int saleVoid = 2;
  static const int adjustment = 3;
  static const int transferIn = 4;
  static const int transferOut = 5;
  static const int count = 6;
}

/// One row of `GET /inventory/stock` — the enriched read projection returned
/// by the backend. Unlike the POS-focused [StockBalance], it carries the
/// human-readable names needed to render stock without N+1 lookups.
class StockBalanceItem {
  const StockBalanceItem({
    required this.warehouseId,
    required this.warehouseName,
    required this.stockLocationId,
    required this.stockLocationName,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.barcode,
    required this.unitOfMeasureName,
    required this.quantity,
    this.variantId,
  });

  final String warehouseId;
  final String warehouseName;
  final String stockLocationId;
  final String stockLocationName;
  final String productId;
  final String productName;
  final String? sku;
  final String? barcode;
  final String? variantId;
  final String unitOfMeasureName;
  final double quantity;

  factory StockBalanceItem.fromJson(Map<String, dynamic> json) =>
      StockBalanceItem(
        warehouseId: json['warehouseId'] as String,
        warehouseName: json['warehouseName'] as String? ?? '',
        stockLocationId: json['stockLocationId'] as String? ?? '',
        stockLocationName: json['stockLocationName'] as String? ?? '',
        productId: json['productId'] as String,
        productName: json['productName'] as String? ?? '',
        sku: json['sku'] as String?,
        barcode: json['barcode'] as String?,
        variantId: json['variantId'] as String?,
        unitOfMeasureName: json['unitOfMeasureName'] as String? ?? '',
        quantity: (json['quantity'] as num).toDouble(),
      );
}

/// One row of `GET /inventory/movements` — the enriched history projection.
class StockMovementItem {
  const StockMovementItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.warehouseId,
    required this.warehouseName,
    required this.stockLocationId,
    required this.stockLocationName,
    required this.type,
    required this.quantityDelta,
    required this.effectiveAt,
    required this.createdAt,
    this.sku,
    this.barcode,
    this.reason,
    this.createdBy,
    this.variantId,
  });

  final String id;
  final String productId;
  final String productName;
  final String? sku;
  final String? barcode;
  final String warehouseId;
  final String warehouseName;
  final String stockLocationId;
  final String stockLocationName;
  final String? variantId;
  final int type;
  final double quantityDelta;
  final String? reason;
  final DateTime effectiveAt;
  final String? createdBy;
  final DateTime createdAt;

  bool get isAdd => quantityDelta > 0;
  bool get isRemove => quantityDelta < 0;

  factory StockMovementItem.fromJson(Map<String, dynamic> json) =>
      StockMovementItem(
        id: json['id'] as String,
        productId: json['productId'] as String,
        productName: json['productName'] as String? ?? '',
        sku: json['sku'] as String?,
        barcode: json['barcode'] as String?,
        warehouseId: json['warehouseId'] as String,
        warehouseName: json['warehouseName'] as String? ?? '',
        stockLocationId: json['stockLocationId'] as String? ?? '',
        stockLocationName: json['stockLocationName'] as String? ?? '',
        variantId: json['variantId'] as String?,
        type: (json['type'] as num).toInt(),
        quantityDelta: (json['quantityDelta'] as num).toDouble(),
        reason: json['reason'] as String?,
        effectiveAt: DateTime.parse(json['effectiveAt'] as String),
        createdBy: json['createdBy'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
