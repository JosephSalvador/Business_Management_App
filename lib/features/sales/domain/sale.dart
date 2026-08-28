/// POS cart and sale models. The client never sends money amounts for lines:
/// the backend re-resolves prices, computes tax, validates stock and issues the
/// receipt number. Cart totals are indicative only until the sale completes.
library;

/// Payment methods supported by the backend `PaymentMethod` enum (bound as
/// ints over JSON). M4 ships Cash and Mobile Money in the UI.
abstract final class PaymentMethod {
  static const cash = 0;
  static const mobileMoney = 1;
  static const card = 2;
  static const bankTransfer = 3;
  static const credit = 4;
  static const other = 5;

  static String label(int method) => switch (method) {
        cash => 'Cash',
        mobileMoney => 'Mobile Money',
        card => 'Kadi',
        bankTransfer => 'Benki',
        credit => 'Mkopo',
        _ => 'Nyingine',
      };

  /// Electronic tenders change the tax rate selection in some localizations.
  static bool isElectronic(int method) => method != cash;
}

/// One row in the POS cart: a product snapshot plus the chosen quantity.
class CartLine {
  CartLine({
    required this.productId,
    required this.name,
    required this.unitPrice,
    this.quantity = 1,
  });

  final String productId;
  final String name;

  /// Resolved selling price per unit (tax-inclusive shelf price).
  double unitPrice;
  double quantity;

  double get lineTotal => unitPrice * quantity;
}

/// Body of `POST /api/v1/sales`. Contains only what the client is allowed to
/// provide; totals, tax and stock are server-computed.
Map<String, dynamic> buildCreateSaleBody({
  required String branchId,
  required String clientSaleId,
  required List<CartLine> lines,
  required int paymentMethod,
  required double total,
  DateTime? effectiveAt,
}) {
  return {
    'branchId': branchId,
    'clientSaleId': clientSaleId,
    'source': 0,
    'effectiveAt': (effectiveAt ?? DateTime.now().toUtc()).toIso8601String(),
    'isElectronicPayment': PaymentMethod.isElectronic(paymentMethod),
    'lines': [
      for (final line in lines)
        {'productId': line.productId, 'quantity': line.quantity},
    ],
    'payments': [
      {
        'method': paymentMethod,
        'amount': total,
      },
    ],
  };
}

class SaleLineData {
  const SaleLineData({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.discountAmount,
    required this.taxCode,
    required this.taxAmount,
    required this.lineTotal,
    this.sku,
    this.unitOfMeasureName,
  });

  factory SaleLineData.fromJson(Map<String, dynamic> json) => SaleLineData(
        productName: json['productName'] as String? ?? '',
        sku: json['sku'] as String?,
        quantity: (json['quantity'] as num).toDouble(),
        unitPrice: (json['unitPrice'] as num).toDouble(),
        discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
        taxCode: json['taxCode'] as String? ?? '',
        taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0,
        lineTotal: (json['lineTotal'] as num).toDouble(),
        unitOfMeasureName: json['unitOfMeasureName'] as String?,
      );

  final String productName;
  final String? sku;
  final String? unitOfMeasureName;
  final double quantity;
  final double unitPrice;
  final double discountAmount;
  final String taxCode;
  final double taxAmount;
  final double lineTotal;
}

class SalePaymentData {
  const SalePaymentData({
    required this.method,
    required this.amount,
    this.reference,
  });

  factory SalePaymentData.fromJson(Map<String, dynamic> json) =>
      SalePaymentData(
        method: json['method'] as int,
        amount: (json['amount'] as num).toDouble(),
        reference: json['reference'] as String?,
      );

  final int method;
  final double amount;
  final String? reference;

  String get label => PaymentMethod.label(method);
}

/// A completed sale as returned by the backend. All amounts are authoritative.
/// [pendingLocally] marks a provisional offline sale recorded before the
/// server has confirmed it — the receipt number and tax split are not final.
class SaleDto {
  const SaleDto({
    this.pendingLocally = false,
    required this.id,
    required this.number,
    required this.status,
    required this.saleDate,
    required this.currency,
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.totalAmount,
    required this.amountPaid,
    required this.change,
    required this.lines,
    required this.payments,
    this.customerName,
  });

  factory SaleDto.fromJson(Map<String, dynamic> json) => SaleDto(
        id: json['id'] as String,
        number: json['number'] as String? ?? '',
        status: json['status'] as int? ?? 0,
        saleDate:
            DateTime.tryParse(json['saleDate'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
        currency: json['currency'] as String? ?? '',
        subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
        discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
        taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0,
        totalAmount: (json['totalAmount'] as num).toDouble(),
        amountPaid: (json['amountPaid'] as num?)?.toDouble() ?? 0,
        change: (json['change'] as num?)?.toDouble() ?? 0,
        customerName: json['customer']?['name'] as String?,
        lines: [
          if (json['lines'] != null)
            for (final line in json['lines'] as List)
              SaleLineData.fromJson(line as Map<String, dynamic>),
        ],
        payments: [
          if (json['payments'] != null)
            for (final payment in json['payments'] as List)
              SalePaymentData.fromJson(payment as Map<String, dynamic>),
        ],
      );

  final String id;
  final String number;
  final int status;
  final DateTime saleDate;
  final String currency;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double totalAmount;
  final double amountPaid;
  final double change;
  final String? customerName;
  final List<SaleLineData> lines;
  final List<SalePaymentData> payments;

  /// True while the sale exists only in the local pending queue.
  final bool pendingLocally;

  bool get isVoided => status == 1;
}

/// Page envelope of `GET /api/v1/sales`.
class PagedSales {
  const PagedSales({required this.items, required this.total});

  factory PagedSales.fromJson(Map<String, dynamic> json) => PagedSales(
        items: [
          for (final item in json['items'] as List? ?? [])
            SaleDto.fromJson(item as Map<String, dynamic>),
        ],
        total: json['total'] as int? ?? 0,
      );

  final List<SaleDto> items;
  final int total;
}
