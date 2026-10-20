/// Domain model for tenant receipt header and footer customization.
library;

/// Configuration options for customizing a tenant's receipt header and footer.
class ReceiptCustomization {
  const ReceiptCustomization({
    this.headerTagline,
    this.footerThanks,
    this.footerPolicy,
    this.footerContact,
    this.showTin = true,
    this.showCashier = true,
    this.showCustomer = true,
  });

  /// Optional tagline or subtitle printed below the business name (e.g. "Wholesale & Retail").
  final String? headerTagline;

  /// Custom thank you message printed in the footer.
  final String? footerThanks;

  /// Custom return / warranty policy (e.g. "Goods once sold not returned" or "Return within 3 days").
  final String? footerPolicy;

  /// Optional contact line (e.g. "Lipa kwa M-Pesa Till: 554433" or "Instagram: @duka_letu").
  final String? footerContact;

  /// Whether to display the business TIN number in the header (if present).
  final bool showTin;

  /// Whether to display the cashier's name in the metadata block.
  final bool showCashier;

  /// Whether to display the customer's name in the metadata block.
  final bool showCustomer;

  ReceiptCustomization copyWith({
    String? headerTagline,
    String? footerThanks,
    String? footerPolicy,
    String? footerContact,
    bool? showTin,
    bool? showCashier,
    bool? showCustomer,
  }) {
    return ReceiptCustomization(
      headerTagline: headerTagline ?? this.headerTagline,
      footerThanks: footerThanks ?? this.footerThanks,
      footerPolicy: footerPolicy ?? this.footerPolicy,
      footerContact: footerContact ?? this.footerContact,
      showTin: showTin ?? this.showTin,
      showCashier: showCashier ?? this.showCashier,
      showCustomer: showCustomer ?? this.showCustomer,
    );
  }

  Map<String, dynamic> toJson() => {
        'headerTagline': headerTagline,
        'footerThanks': footerThanks,
        'footerPolicy': footerPolicy,
        'footerContact': footerContact,
        'showTin': showTin,
        'showCashier': showCashier,
        'showCustomer': showCustomer,
      };

  factory ReceiptCustomization.fromJson(Map<String, dynamic> json) {
    return ReceiptCustomization(
      headerTagline: json['headerTagline'] as String?,
      footerThanks: json['footerThanks'] as String?,
      footerPolicy: json['footerPolicy'] as String?,
      footerContact: json['footerContact'] as String?,
      showTin: json['showTin'] as bool? ?? true,
      showCashier: json['showCashier'] as bool? ?? true,
      showCustomer: json['showCustomer'] as bool? ?? true,
    );
  }

  /// Default configuration with sensible blank overrides.
  static const defaultConfiguration = ReceiptCustomization();
}
