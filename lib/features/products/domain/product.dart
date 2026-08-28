/// Product status codes exactly as the backend serializes them (ints).
abstract final class ProductStatus {
  static const draft = 0;
  static const active = 1;
  static const inactive = 2;
}

/// Product type codes exactly as the backend serializes them (ints).
abstract final class ProductType {
  static const goods = 0;
  static const service = 1;
}

class Product {
  const Product({
    required this.id,
    required this.name,
    this.description,
    this.sku,
    this.barcode,
    this.categoryId,
    required this.unitOfMeasureId,
    required this.productType,
    required this.status,
    this.taxCategoryId,
  });

  final String id;
  final String name;
  final String? description;
  final String? sku;
  final String? barcode;
  final String? categoryId;
  final String unitOfMeasureId;
  final int productType;
  final int status;
  final String? taxCategoryId;

  bool get isActive => status == ProductStatus.active;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        sku: json['sku'] as String?,
        barcode: json['barcode'] as String?,
        categoryId: json['categoryId'] as String?,
        unitOfMeasureId: json['unitOfMeasureId'] as String,
        productType: (json['productType'] as num).toInt(),
        status: (json['status'] as num).toInt(),
        taxCategoryId: json['taxCategoryId'] as String?,
      );

  Map<String, dynamic> toCreateBody() => {
        'name': name.trim(),
        if (hasText(description)) 'description': description!.trim(),
        if (hasText(sku)) 'sku': sku!.trim(),
        if (hasText(barcode)) 'barcode': barcode!.trim(),
        if (categoryId != null) 'categoryId': categoryId,
        'unitOfMeasureId': unitOfMeasureId,
        'productType': productType,
        // New products must be sellable immediately.
        'status': ProductStatus.active,
        if (taxCategoryId != null) 'taxCategoryId': taxCategoryId,
      };

  Map<String, dynamic> toUpdateBody() {
    final body = toCreateBody()..remove('status');
    return body;
  }

  static bool hasText(String? value) =>
      value != null && value.trim().isNotEmpty;
}
