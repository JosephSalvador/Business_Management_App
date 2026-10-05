/// Receipt preview data models for displaying and printing receipts.
library;

/// Complete receipt preview data as returned by the backend API.
class ReceiptPreview {
  const ReceiptPreview({
    required this.saleId,
    required this.saleNumber,
    required this.saleDate,
    required this.isVoided,
    required this.hasMetadata,
    required this.isReprint,
    required this.printCount,
    required this.businessName,
    this.tin,
    this.address,
    this.phone,
    this.email,
    this.branchName,
    this.cashierName,
    this.customerName,
    required this.currency,
    this.layoutId,
    this.fiscalHash,
    required this.qrPayload,
    required this.lines,
    required this.payments,
    required this.subtotal,
    required this.taxAmount,
    required this.discountAmount,
    required this.totalAmount,
    required this.amountPaid,
    required this.change,
  });

  factory ReceiptPreview.fromJson(Map<String, dynamic> json) => ReceiptPreview(
        saleId: json['saleId'] as String,
        saleNumber: json['saleNumber'] as String,
        saleDate: DateTime.parse(json['saleDate'] as String),
        isVoided: json['isVoided'] as bool,
        hasMetadata: json['hasMetadata'] as bool,
        isReprint: json['isReprint'] as bool,
        printCount: json['printCount'] as int,
        businessName: json['businessName'] as String,
        tin: json['tin'] as String?,
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        branchName: json['branchName'] as String?,
        cashierName: json['cashierName'] as String?,
        customerName: json['customerName'] as String?,
        currency: json['currency'] as String? ?? 'TZS',
        layoutId: json['layoutId'] as String?,
        fiscalHash: json['fiscalHash'] as String?,
        qrPayload: json['qrPayload'] as String? ?? '',
        lines: (json['lines'] as List<dynamic>)
            .map((e) => ReceiptLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        payments: (json['payments'] as List<dynamic>)
            .map((e) => ReceiptPayment.fromJson(e as Map<String, dynamic>))
            .toList(),
        subtotal: (json['subtotal'] as num).toDouble(),
        taxAmount: (json['taxAmount'] as num).toDouble(),
        discountAmount: (json['discountAmount'] as num).toDouble(),
        totalAmount: (json['totalAmount'] as num).toDouble(),
        amountPaid: (json['amountPaid'] as num).toDouble(),
        change: (json['change'] as num).toDouble(),
      );

  /// Serializes back to the exact shape [fromJson] reads, so the local cache
  /// round-trips without a hand-maintained copy of the field list.
  Map<String, dynamic> toJson() => {
        'saleId': saleId,
        'saleNumber': saleNumber,
        'saleDate': saleDate.toIso8601String(),
        'isVoided': isVoided,
        'hasMetadata': hasMetadata,
        'isReprint': isReprint,
        'printCount': printCount,
        'businessName': businessName,
        'tin': tin,
        'address': address,
        'phone': phone,
        'email': email,
        'branchName': branchName,
        'cashierName': cashierName,
        'customerName': customerName,
        'currency': currency,
        'layoutId': layoutId,
        'fiscalHash': fiscalHash,
        'qrPayload': qrPayload,
        'lines': lines.map((l) => l.toJson()).toList(),
        'payments': payments.map((p) => p.toJson()).toList(),
        'subtotal': subtotal,
        'taxAmount': taxAmount,
        'discountAmount': discountAmount,
        'totalAmount': totalAmount,
        'amountPaid': amountPaid,
        'change': change,
      };

  final String saleId;
  final String saleNumber;
  final DateTime saleDate;
  final bool isVoided;
  final bool hasMetadata;
  final bool isReprint;
  final int printCount;
  final String businessName;
  final String? tin;
  final String? address;
  final String? phone;
  final String? email;
  final String? branchName;
  final String? cashierName;
  final String? customerName;
  final String currency;
  final String? layoutId;
  final String? fiscalHash;
  final String qrPayload;
  final List<ReceiptLine> lines;
  final List<ReceiptPayment> payments;
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double totalAmount;
  final double amountPaid;
  final double change;
}

/// A single line item on the receipt.
class ReceiptLine {
  const ReceiptLine({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.discountAmount,
    required this.lineTotal,
    required this.taxCode,
    required this.taxAmount,
  });

  factory ReceiptLine.fromJson(Map<String, dynamic> json) => ReceiptLine(
        productName: json['productName'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        unitPrice: (json['unitPrice'] as num).toDouble(),
        discountAmount: (json['discountAmount'] as num).toDouble(),
        lineTotal: (json['lineTotal'] as num).toDouble(),
        taxCode: json['taxCode'] as String,
        taxAmount: (json['taxAmount'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'productName': productName,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'discountAmount': discountAmount,
        'lineTotal': lineTotal,
        'taxCode': taxCode,
        'taxAmount': taxAmount,
      };

  final String productName;
  final double quantity;
  final double unitPrice;
  final double discountAmount;
  final double lineTotal;
  final String taxCode;
  final double taxAmount;
}

/// A payment method entry on the receipt.
class ReceiptPayment {
  const ReceiptPayment({
    required this.method,
    required this.amount,
    this.reference,
  });

  factory ReceiptPayment.fromJson(Map<String, dynamic> json) => ReceiptPayment(
        method: json['method'] as String,
        amount: (json['amount'] as num).toDouble(),
        reference: json['reference'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'method': method,
        'amount': amount,
        'reference': reference,
      };

  final String method;
  final double amount;

  /// Tender reference from the gateway (transaction id), when the method has one.
  final String? reference;
}

/// Result of recording a print event.
class PrintEventRecorded {
  const PrintEventRecorded({
    required this.eventId,
    required this.saleId,
    required this.type,
    required this.printedAt,
  });

  factory PrintEventRecorded.fromJson(Map<String, dynamic> json) =>
      PrintEventRecorded(
        eventId: json['eventId'] as String,
        saleId: json['saleId'] as String,
        type: json['type'] as String,
        printedAt: DateTime.parse(json['printedAt'] as String),
      );

  final String eventId;
  final String saleId;
  final String type;
  final DateTime printedAt;
}
