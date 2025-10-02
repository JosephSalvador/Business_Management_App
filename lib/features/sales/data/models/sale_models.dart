class Sale {
  final String id;
  final String customerName;
  final String customerTin;
  final String customerMobile;
  final DateTime date;
  final double amount;
  final double vatAmount;
  final double totalAmount;
  final String vatRate;
  final String status;
  final String paymentMethod;
  final String paymentReference;
  final String paymentChannel;
  final List<SaleItem> items;
  final String vfdSerial;
  final String receiptNumber;

  Sale({
    required this.id,
    required this.customerName,
    required this.customerTin,
    required this.customerMobile,
    required this.date,
    required this.amount,
    required this.vatAmount,
    required this.totalAmount,
    required this.vatRate,
    required this.status,
    required this.paymentMethod,
    required this.paymentReference,
    required this.paymentChannel,
    required this.items,
    required this.vfdSerial,
    required this.receiptNumber,
  });
}

class SaleItem {
  final String id;
  final String productName;
  final String productCode;
  final int quantity;
  final double unitPrice;
  final double vatRate;
  final double vatAmount;
  final double totalAmount;

  SaleItem({
    required this.id,
    required this.productName,
    required this.productCode,
    required this.quantity,
    required this.unitPrice,
    required this.vatRate,
    required this.vatAmount,
    required this.totalAmount,
  });

  SaleItem copyWith({
    String? id,
    String? productName,
    String? productCode,
    int? quantity,
    double? unitPrice,
    double? vatRate,
    double? vatAmount,
    double? totalAmount,
  }) {
    return SaleItem(
      id: id ?? this.id,
      productName: productName ?? this.productName,
      productCode: productCode ?? this.productCode,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      vatRate: vatRate ?? this.vatRate,
      vatAmount: vatAmount ?? this.vatAmount,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }
}

class VatCalculationResult {
  final double originalAmount;
  final double vatExclusiveAmount;
  final double newVatAmount;
  final double newTotalAmount;
  final String appliedVatRate;

  VatCalculationResult({
    required this.originalAmount,
    required this.vatExclusiveAmount,
    required this.newVatAmount,
    required this.newTotalAmount,
    required this.appliedVatRate,
  });
}

class TinValidationResult {
  final String taxpayerId;
  final String firstName;
  final String middleName;
  final String lastName;
  final String tradingName;
  final bool hasVAT;
  final String? vrn;
  final bool isValid;

  TinValidationResult({
    required this.taxpayerId,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.tradingName,
    required this.hasVAT,
    this.vrn,
    required this.isValid,
  });
}