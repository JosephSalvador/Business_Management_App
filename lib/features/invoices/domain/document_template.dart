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

/// Visual layout archetypes for A4 corporate invoices.
/// Works 100% offline in both [InvoiceA4PreviewCard] and [LocalPdfDocumentGenerator].
enum InvoiceLayoutStyle {
  /// Matches the Modern Ribbon design: stacked logo + business name top-left,
  /// large Invoice # top-right, 4-cell colored highlight ribbon (Primary + Secondary),
  /// clean horizontal-rule table, signature image under totals, and bottom contact bar.
  modernRibbon(
    id: 'tpl-invoice-modern-ribbon',
    titleEn: 'Modern Ribbon (Gold & Charcoal)',
    titleSw: 'Kisasa chenye Ukanda wa Rangi (Modern Ribbon)',
    subtitleEn:
        'Highlight summary bar, clean borderless table, signature & bottom contact bar',
    subtitleSw:
        'Ukanda wa muhtasari wa rangi, jedwali safi, sahihi na mawasiliano chini',
    defaultPrimaryHex: '#F5B041',
    defaultSecondaryHex: '#333333',
  ),

  /// Executive corporate layout: top brand bar, boxed metadata card, tinted Bill-To card,
  /// striped table header, Bank/Mobile Money box, and official Stamp/Signatory box.
  executiveCorporate(
    id: 'tpl-invoice-executive-corporate',
    titleEn: 'Executive Corporate',
    titleSw: 'Rasmi ya Kampuni (Executive Corporate)',
    subtitleEn:
        'Structured corporate header, tinted Bill-To box, bank instructions & stamp box',
    subtitleSw:
        'Muundo rasmi wa kampuni, kisanduku cha mteja, maelekezo ya benki na muhuri',
    defaultPrimaryHex: '#0F172A',
    defaultSecondaryHex: '#0D9488',
  ),

  /// Traditional wholesale / Tally-style full grid layout with outer and inner table borders
  /// and dual signature lines (Prepared By & Received By).
  classicGrid(
    id: 'tpl-invoice-classic-grid',
    titleEn: 'Classic Wholesale Grid',
    titleSw: 'Jedwali Kamili la Jumla (Classic Grid)',
    subtitleEn:
        'Full bordered grid around seller, customer, and items with dual signatures',
    subtitleSw:
        'Mistari kamili ya jedwali kwa muuzaji, mteja na bidhaa pamoja na sahihi mbili',
    defaultPrimaryHex: '#1E3A8A',
    defaultSecondaryHex: '#475569',
  ),

  /// Custom Letterhead / Pre-Printed Stationery mode: either renders an uploaded
  /// full-width top header graphic or leaves a configurable top margin for physical letterhead paper.
  customLetterhead(
    id: 'tpl-invoice-custom-letterhead',
    titleEn: 'Custom Letterhead / Pre-Printed Paper',
    titleSw: 'nembo ya Juu / Karatasi Iliyochapishwa (Letterhead)',
    subtitleEn:
        'Upload your designer header banner or leave top space for pre-printed paper',
    subtitleSw:
        'Weka picha ya kichwa cha karatasi (letterhead) au acha nafasi ya juu kwa karatasi maalum',
    defaultPrimaryHex: '#0F172A',
    defaultSecondaryHex: '#334155',
  );

  const InvoiceLayoutStyle({
    required this.id,
    required this.titleEn,
    required this.titleSw,
    required this.subtitleEn,
    required this.subtitleSw,
    required this.defaultPrimaryHex,
    required this.defaultSecondaryHex,
  });

  final String id;
  final String titleEn;
  final String titleSw;
  final String subtitleEn;
  final String subtitleSw;
  final String defaultPrimaryHex;
  final String defaultSecondaryHex;

  String get templateId => id;
  String title(bool isSw) => isSw ? titleSw : titleEn;
  String subtitle(bool isSw) => isSw ? subtitleSw : subtitleEn;

  static InvoiceLayoutStyle resolve({
    String? templateId,
    String? templateName,
  }) {
    final combined =
        '${templateId ?? ''} ${templateName ?? ''}'.trim().toLowerCase();
    if (combined.contains('ribbon') ||
        combined.contains('modern') ||
        combined.contains('minimalist') ||
        combined.contains('11111111-1111-1111-1111-111111111101')) {
      return InvoiceLayoutStyle.modernRibbon;
    }
    if (combined.contains('grid') ||
        combined.contains('classic') ||
        combined.contains('wholesale') ||
        combined.contains('11111111-1111-1111-1111-111111111102')) {
      return InvoiceLayoutStyle.classicGrid;
    }
    if (combined.contains('letterhead') || combined.contains('preprinted')) {
      return InvoiceLayoutStyle.customLetterhead;
    }
    return InvoiceLayoutStyle.executiveCorporate;
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

  InvoiceLayoutStyle get layoutStyle => InvoiceLayoutStyle.resolve(
        templateId: id,
        templateName: name,
      );

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
    this.id = '',
    this.tenantId = '',
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

  InvoiceLayoutStyle get layoutStyle => InvoiceLayoutStyle.resolve(
        templateId: activeTemplateId,
        templateName: activeTemplateName,
      );

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenantId': tenantId,
        'documentType': documentType.value,
        'activeTemplateId': activeTemplateId,
        'activeTemplateName': activeTemplateName,
        'customLiquidOverride': customLiquidOverride,
        'themePrimaryHex': themePrimaryHex,
        'themeSecondaryHex': themeSecondaryHex,
        'logoUrl': logoUrl,
        'showLogo': showLogo,
        'footerNotes': footerNotes,
      };

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
