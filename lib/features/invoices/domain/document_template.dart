enum DocumentType {
  invoice(1, 'Invoice'),
  deliveryNote(2, 'DeliveryNote');

  const DocumentType(this.value, this.name);

  final int value;
  final String name;

  static DocumentType fromValue(int value) {
    return DocumentType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => DocumentType.invoice,
    );
  }

  static DocumentType fromString(String name) {
    final lower = name.trim().toLowerCase();
    if (lower == 'deliverynote' || lower == 'delivery_note' || lower == '2') {
      return DocumentType.deliveryNote;
    }
    return DocumentType.invoice;
  }
}

class DocumentTemplateSummary {
  const DocumentTemplateSummary({
    required this.id,
    required this.name,
    this.description,
    required this.documentType,
    this.thumbnailBase64,
    this.isDefault = false,
    this.displayOrder = 0,
  });

  final String id;
  final String name;
  final String? description;
  final DocumentType documentType;
  final String? thumbnailBase64;
  final bool isDefault;
  final int displayOrder;

  bool get isThermal =>
      name.toLowerCase().contains('thermal') ||
      (description?.toLowerCase().contains('thermal') ?? false) ||
      (description?.toLowerCase().contains('80mm') ?? false);

  factory DocumentTemplateSummary.fromJson(Map<String, dynamic> json) {
    final docTypeVal = json['documentType'];
    final docType = docTypeVal is int
        ? DocumentType.fromValue(docTypeVal)
        : DocumentType.fromString(docTypeVal?.toString() ?? '1');

    return DocumentTemplateSummary(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      documentType: docType,
      thumbnailBase64: json['thumbnailBase64']?.toString(),
      isDefault: json['isDefault'] as bool? ?? false,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
    );
  }
}

class DocumentTemplateDetail {
  const DocumentTemplateDetail({
    required this.id,
    required this.name,
    this.description,
    required this.documentType,
    required this.liquidLayout,
    this.thumbnailBase64,
    required this.engineVersion,
    this.isActive = true,
    this.isDefault = false,
    this.displayOrder = 0,
  });

  final String id;
  final String name;
  final String? description;
  final DocumentType documentType;
  final String liquidLayout;
  final String? thumbnailBase64;
  final String engineVersion;
  final bool isActive;
  final bool isDefault;
  final int displayOrder;

  bool get isThermal =>
      name.toLowerCase().contains('thermal') ||
      liquidLayout.contains('width: 80mm') ||
      liquidLayout.contains('max-width: 80mm');

  factory DocumentTemplateDetail.fromJson(Map<String, dynamic> json) {
    final docTypeVal = json['documentType'];
    final docType = docTypeVal is int
        ? DocumentType.fromValue(docTypeVal)
        : DocumentType.fromString(docTypeVal?.toString() ?? '1');

    return DocumentTemplateDetail(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      documentType: docType,
      liquidLayout: json['liquidLayout']?.toString() ?? '',
      thumbnailBase64: json['thumbnailBase64']?.toString(),
      engineVersion: json['engineVersion']?.toString() ?? 'Fluid-v2.0',
      isActive: json['isActive'] as bool? ?? true,
      isDefault: json['isDefault'] as bool? ?? false,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
    );
  }
}

class TenantDocumentConfiguration {
  const TenantDocumentConfiguration({
    required this.id,
    required this.tenantId,
    required this.documentType,
    required this.activeTemplateId,
    this.activeTemplateName,
    this.customLiquidOverride,
    this.themePrimaryHex = '#0F172A',
    this.themeSecondaryHex = '#0D9488',
    this.logoUrl,
    this.showLogo = true,
    this.footerNotes,
  });

  final String id;
  final String tenantId;
  final DocumentType documentType;
  final String activeTemplateId;
  final String? activeTemplateName;
  final String? customLiquidOverride;
  final String? themePrimaryHex;
  final String? themeSecondaryHex;
  final String? logoUrl;
  final bool showLogo;
  final String? footerNotes;

  factory TenantDocumentConfiguration.fromJson(Map<String, dynamic> json) {
    final docTypeVal = json['documentType'];
    final docType = docTypeVal is int
        ? DocumentType.fromValue(docTypeVal)
        : DocumentType.fromString(docTypeVal?.toString() ?? '1');

    return TenantDocumentConfiguration(
      id: json['id']?.toString() ?? '',
      tenantId: json['tenantId']?.toString() ?? '',
      documentType: docType,
      activeTemplateId: json['activeTemplateId']?.toString() ?? '',
      activeTemplateName: json['activeTemplateName']?.toString(),
      customLiquidOverride: json['customLiquidOverride']?.toString(),
      themePrimaryHex: json['themePrimaryHex']?.toString() ?? '#0F172A',
      themeSecondaryHex: json['themeSecondaryHex']?.toString() ?? '#0D9488',
      logoUrl: json['logoUrl']?.toString(),
      showLogo: json['showLogo'] as bool? ?? true,
      footerNotes: json['footerNotes']?.toString(),
    );
  }

  Map<String, dynamic> toUpdateRequestJson() => {
        'activeTemplateId': activeTemplateId,
        'customLiquidOverride': customLiquidOverride?.trim().isEmpty ?? true
            ? null
            : customLiquidOverride!.trim(),
        'themePrimaryHex': themePrimaryHex?.trim().isEmpty ?? true
            ? null
            : themePrimaryHex!.trim(),
        'themeSecondaryHex': themeSecondaryHex?.trim().isEmpty ?? true
            ? null
            : themeSecondaryHex!.trim(),
        'logoUrl': logoUrl?.trim().isEmpty ?? true ? null : logoUrl!.trim(),
        'showLogo': showLogo,
        'footerNotes':
            footerNotes?.trim().isEmpty ?? true ? null : footerNotes!.trim(),
      };

  TenantDocumentConfiguration copyWith({
    String? id,
    String? tenantId,
    DocumentType? documentType,
    String? activeTemplateId,
    String? activeTemplateName,
    String? customLiquidOverride,
    String? themePrimaryHex,
    String? themeSecondaryHex,
    String? logoUrl,
    bool? showLogo,
    String? footerNotes,
  }) {
    return TenantDocumentConfiguration(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      documentType: documentType ?? this.documentType,
      activeTemplateId: activeTemplateId ?? this.activeTemplateId,
      activeTemplateName: activeTemplateName ?? this.activeTemplateName,
      customLiquidOverride: customLiquidOverride ?? this.customLiquidOverride,
      themePrimaryHex: themePrimaryHex ?? this.themePrimaryHex,
      themeSecondaryHex: themeSecondaryHex ?? this.themeSecondaryHex,
      logoUrl: logoUrl ?? this.logoUrl,
      showLogo: showLogo ?? this.showLogo,
      footerNotes: footerNotes ?? this.footerNotes,
    );
  }
}
