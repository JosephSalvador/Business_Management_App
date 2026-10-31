enum InvoiceStatus {
  unpaid(0),
  partiallyPaid(1),
  paid(2),
  voided(3);

  const InvoiceStatus(this.code);

  final int code;

  bool get isOpen =>
      this == InvoiceStatus.unpaid || this == InvoiceStatus.partiallyPaid;

  static InvoiceStatus fromCode(Object? value) {
    final code = _requiredInt(value, 'status');
    return values.firstWhere(
      (status) => status.code == code,
      orElse: () => throw FormatException('Unknown invoice status: $code'),
    );
  }
}

class InvoiceLine {
  const InvoiceLine({
    required this.id,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.taxRatePercent,
    required this.lineTotal,
    required this.taxAmount,
    this.unitOfMeasure = 'Pcs',
    this.discountAmount = 0,
  });

  final String id;
  final String description;
  final String unitOfMeasure;
  final double quantity;
  final double unitPrice;
  final double discountAmount;
  final double taxRatePercent;
  final double lineTotal;
  final double taxAmount;

  double get grossTotal => quantity * unitPrice;

  factory InvoiceLine.fromJson(Map<String, dynamic> json) => InvoiceLine(
        id: _requiredString(json, 'id'),
        description: _requiredString(json, 'description'),
        unitOfMeasure: _optionalString(json, 'unitOfMeasure') ?? 'Pcs',
        quantity: _requiredDouble(json, 'quantity'),
        unitPrice: _requiredDouble(json, 'unitPrice'),
        discountAmount: _optionalDouble(json, 'discountAmount') ?? 0,
        taxRatePercent: _optionalDouble(json, 'taxRatePercent') ?? 0,
        lineTotal: _requiredDouble(json, 'lineTotal'),
        taxAmount: _optionalDouble(json, 'taxAmount') ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'unitOfMeasure': unitOfMeasure,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'discountAmount': discountAmount,
        'taxRatePercent': taxRatePercent,
        'lineTotal': lineTotal,
        'taxAmount': taxAmount,
      };
}

class CustomerInvoice {
  const CustomerInvoice({
    required this.id,
    required this.number,
    required this.customerId,
    required this.customerName,
    required this.currency,
    required this.issueDate,
    required this.dueDate,
    required this.notes,
    required this.status,
    required this.subtotal,
    required this.taxAmount,
    required this.totalAmount,
    required this.amountPaid,
    required this.balanceDue,
    required this.paymentMethod,
    required this.paymentReference,
    required this.paidAtUtc,
    required this.lines,
    this.documentTitle = 'INVOICE',
    this.referenceNumber,
    this.paymentTerms,
    this.customerAttention,
    this.customerPhone,
    this.customerEmail,
    this.customerAddress,
    this.customerTin,
    this.discountAmount = 0,
    this.paymentInstructions,
    this.authorizedSignatoryName,
    this.authorizedSignatoryTitle,
  });

  final String id;
  final String number;
  final String documentTitle;
  final String? referenceNumber;
  final String? paymentTerms;
  final String? customerId;
  final String? customerName;
  final String? customerAttention;
  final String? customerPhone;
  final String? customerEmail;
  final String? customerAddress;
  final String? customerTin;
  final String currency;
  final DateTime issueDate;
  final DateTime? dueDate;
  final String? notes;
  final String? paymentInstructions;
  final String? authorizedSignatoryName;
  final String? authorizedSignatoryTitle;
  final InvoiceStatus status;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double totalAmount;
  final double amountPaid;
  final double balanceDue;
  final String? paymentMethod;
  final String? paymentReference;
  final DateTime? paidAtUtc;
  final List<InvoiceLine> lines;

  String get customerLabel =>
      customerName != null && customerName!.isNotEmpty ? customerName! : '—';

  bool get canTakePayment => status.isOpen && balanceDue > 0;

  bool get canVoid =>
      status != InvoiceStatus.paid && status != InvoiceStatus.voided;

  bool get isOverdue {
    final due = dueDate;
    if (due == null || !status.isOpen) return false;
    return due.isBefore(DateTime.now());
  }

  CustomerInvoiceSummary toSummary() => CustomerInvoiceSummary(
        id: id,
        number: number,
        customerId: customerId,
        customerName: customerName,
        status: status,
        issueDate: issueDate,
        dueDate: dueDate,
        totalAmount: totalAmount,
        amountPaid: amountPaid,
        balanceDue: balanceDue,
        documentTitle: documentTitle,
        referenceNumber: referenceNumber,
        currency: currency,
      );

  CustomerInvoice copyWith({
    InvoiceStatus? status,
    double? amountPaid,
    double? balanceDue,
    String? paymentMethod,
    String? paymentReference,
    DateTime? paidAtUtc,
  }) =>
      CustomerInvoice(
        id: id,
        number: number,
        documentTitle: documentTitle,
        referenceNumber: referenceNumber,
        paymentTerms: paymentTerms,
        customerId: customerId,
        customerName: customerName,
        customerAttention: customerAttention,
        customerPhone: customerPhone,
        customerEmail: customerEmail,
        customerAddress: customerAddress,
        customerTin: customerTin,
        currency: currency,
        issueDate: issueDate,
        dueDate: dueDate,
        notes: notes,
        paymentInstructions: paymentInstructions,
        authorizedSignatoryName: authorizedSignatoryName,
        authorizedSignatoryTitle: authorizedSignatoryTitle,
        status: status ?? this.status,
        subtotal: subtotal,
        discountAmount: discountAmount,
        taxAmount: taxAmount,
        totalAmount: totalAmount,
        amountPaid: amountPaid ?? this.amountPaid,
        balanceDue: balanceDue ?? this.balanceDue,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        paymentReference: paymentReference ?? this.paymentReference,
        paidAtUtc: paidAtUtc ?? this.paidAtUtc,
        lines: lines,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'documentTitle': documentTitle,
        'referenceNumber': referenceNumber,
        'paymentTerms': paymentTerms,
        'customerId': customerId,
        'customerName': customerName,
        'customerAttention': customerAttention,
        'customerPhone': customerPhone,
        'customerEmail': customerEmail,
        'customerAddress': customerAddress,
        'customerTin': customerTin,
        'currency': currency,
        'issueDate': issueDate.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'notes': notes,
        'paymentInstructions': paymentInstructions,
        'authorizedSignatoryName': authorizedSignatoryName,
        'authorizedSignatoryTitle': authorizedSignatoryTitle,
        'status': status.code,
        'subtotal': subtotal,
        'discountAmount': discountAmount,
        'taxAmount': taxAmount,
        'totalAmount': totalAmount,
        'amountPaid': amountPaid,
        'balanceDue': balanceDue,
        'paymentMethod': paymentMethod,
        'paymentReference': paymentReference,
        'paidAtUtc': paidAtUtc?.toIso8601String(),
        'lines': [for (final line in lines) line.toJson()],
      };

  factory CustomerInvoice.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    return CustomerInvoice(
      id: _requiredString(json, 'id'),
      number: _requiredString(json, 'number'),
      documentTitle: _optionalString(json, 'documentTitle') ?? 'INVOICE',
      referenceNumber: _optionalString(json, 'referenceNumber'),
      paymentTerms: _optionalString(json, 'paymentTerms'),
      customerId: _optionalString(json, 'customerId'),
      customerName: _optionalString(json, 'customerName'),
      customerAttention: _optionalString(json, 'customerAttention'),
      customerPhone: _optionalString(json, 'customerPhone'),
      customerEmail: _optionalString(json, 'customerEmail'),
      customerAddress: _optionalString(json, 'customerAddress'),
      customerTin: _optionalString(json, 'customerTin'),
      currency: _optionalString(json, 'currency') ?? 'TZS',
      issueDate: _requiredDateTime(json, 'issueDate'),
      dueDate: _optionalDateTime(json, 'dueDate'),
      notes: _optionalString(json, 'notes'),
      paymentInstructions: _optionalString(json, 'paymentInstructions'),
      authorizedSignatoryName: _optionalString(json, 'authorizedSignatoryName'),
      authorizedSignatoryTitle:
          _optionalString(json, 'authorizedSignatoryTitle'),
      status: InvoiceStatus.fromCode(json['status']),
      subtotal: _requiredDouble(json, 'subtotal'),
      discountAmount: _optionalDouble(json, 'discountAmount') ?? 0,
      taxAmount: _optionalDouble(json, 'taxAmount') ?? 0,
      totalAmount: _requiredDouble(json, 'totalAmount'),
      amountPaid: _requiredDouble(json, 'amountPaid'),
      balanceDue: _requiredDouble(json, 'balanceDue'),
      paymentMethod: _optionalString(json, 'paymentMethod'),
      paymentReference: _optionalString(json, 'paymentReference'),
      paidAtUtc: _optionalDateTime(json, 'paidAtUtc'),
      lines: rawLines is List
          ? rawLines
              .whereType<Map<dynamic, dynamic>>()
              .map(
                  (raw) => InvoiceLine.fromJson(Map<String, dynamic>.from(raw)))
              .toList(growable: false)
          : const [],
    );
  }
}

class CustomerInvoiceSummary {
  const CustomerInvoiceSummary({
    required this.id,
    required this.number,
    required this.customerId,
    required this.customerName,
    required this.status,
    required this.issueDate,
    required this.dueDate,
    required this.totalAmount,
    required this.amountPaid,
    required this.balanceDue,
    this.documentTitle = 'INVOICE',
    this.referenceNumber,
    this.currency = 'TZS',
  });

  final String id;
  final String number;
  final String documentTitle;
  final String? referenceNumber;
  final String currency;
  final String? customerId;
  final String? customerName;
  final InvoiceStatus status;
  final DateTime issueDate;
  final DateTime? dueDate;
  final double totalAmount;
  final double amountPaid;
  final double balanceDue;

  String get customerLabel =>
      customerName != null && customerName!.isNotEmpty ? customerName! : '—';

  bool get isOverdue {
    final due = dueDate;
    if (due == null || !status.isOpen) return false;
    return due.isBefore(DateTime.now());
  }

  factory CustomerInvoiceSummary.fromJson(Map<String, dynamic> json) {
    return CustomerInvoiceSummary(
      id: _requiredString(json, 'id'),
      number: _requiredString(json, 'number'),
      documentTitle: _optionalString(json, 'documentTitle') ?? 'INVOICE',
      referenceNumber: _optionalString(json, 'referenceNumber'),
      currency: _optionalString(json, 'currency') ?? 'TZS',
      customerId: _optionalString(json, 'customerId'),
      customerName: _optionalString(json, 'customerName'),
      status: InvoiceStatus.fromCode(json['status']),
      issueDate: _requiredDateTime(json, 'issueDate'),
      dueDate: _optionalDateTime(json, 'dueDate'),
      totalAmount: _requiredDouble(json, 'totalAmount'),
      amountPaid: _requiredDouble(json, 'amountPaid'),
      balanceDue: _requiredDouble(json, 'balanceDue'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'documentTitle': documentTitle,
        'referenceNumber': referenceNumber,
        'currency': currency,
        'customerId': customerId,
        'customerName': customerName,
        'status': status.code,
        'issueDate': issueDate.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'totalAmount': totalAmount,
        'amountPaid': amountPaid,
        'balanceDue': balanceDue,
      };
}

class InvoicePage {
  const InvoicePage(
      {required this.items, required this.total, required this.page});

  final List<CustomerInvoiceSummary> items;
  final int total;
  final int page;

  bool get hasMore => items.length < total;
}

class InvoiceDraftLine {
  InvoiceDraftLine({
    this.description = '',
    this.unitOfMeasure = 'Pcs',
    this.quantity = 1,
    this.unitPrice = 0,
    this.discountAmount = 0,
    this.taxRatePercent = 0,
  });

  String description;
  String unitOfMeasure;
  double quantity;
  double unitPrice;
  double discountAmount;
  double taxRatePercent;

  double get grossTotal => quantity * unitPrice;

  double get effectiveDiscount =>
      discountAmount.clamp(0, grossTotal).toDouble();

  double get lineTotal => grossTotal - effectiveDiscount;

  double get lineTax => lineTotal * taxRatePercent / 100;

  Map<String, dynamic> toJson() => {
        'description': description.trim(),
        'unitOfMeasure':
            unitOfMeasure.trim().isEmpty ? 'Pcs' : unitOfMeasure.trim(),
        'quantity': quantity,
        'unitPrice': unitPrice,
        'discountAmount': effectiveDiscount,
        'taxRatePercent': taxRatePercent,
      };
}

int _requiredInt(Object? value, String field) {
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  throw FormatException('$field must be an integer.');
}

String _requiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('$field must be a non-empty string.');
}

String? _optionalString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null || value is String) return value as String?;
  throw FormatException('$field must be a string.');
}

double _requiredDouble(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is num && value.isFinite) return value.toDouble();
  throw FormatException('$field must be a number.');
}

double? _optionalDouble(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null) return null;
  if (value is num && value.isFinite) return value.toDouble();
  throw FormatException('$field must be a number.');
}

DateTime _requiredDateTime(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! String) throw FormatException('$field must be a date.');
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('$field must be a date.');
  return parsed;
}

DateTime? _optionalDateTime(Map<String, dynamic> json, String field) {
  if (json[field] == null) return null;
  return _requiredDateTime(json, field);
}
