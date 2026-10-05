/// Receipt layout definition models. Layouts describe the structure of a receipt
/// (sections, fields, styling) without storing the receipt itself.
library;

/// A receipt layout definition as returned by the backend.
class ReceiptLayout {
  const ReceiptLayout({
    required this.id,
    required this.layoutId,
    required this.version,
    required this.isActive,
    this.specJson,
    this.createdAt,
    this.updatedAt,
  });

  factory ReceiptLayout.fromJson(Map<String, dynamic> json) => ReceiptLayout(
        id: json['id'] as String,
        layoutId: json['layoutId'] as String,
        version: json['version'] as int,
        isActive: json['isActive'] as bool,
        specJson: json['specJson'] as String?,
        createdAt: json['createdAt'] as String?,
        updatedAt: json['updatedAt'] as String?,
      );

  final String id;
  final String layoutId;
  final int version;
  final bool isActive;
  final String? specJson;
  final String? createdAt;
  final String? updatedAt;
}
