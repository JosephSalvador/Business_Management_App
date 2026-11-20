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
    double taxRatePercent = 0,
    double? taxRate,
    required this.lineTotal,
    required this.taxAmount,
    this.unitOfMeasure = 'Pcs',
    this.discountAmount = 0,
    this.productId,
    this.sku,
  }) : taxRatePercent = taxRate ?? taxRatePercent;

  final String id;
  final String? productId;
  final String? sku;
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
        productId: _optionalString(json, 'productId'),
        sku: _optionalString(json, 'sku'),
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
        if (productId != null) 'productId': productId,
        if (sku != null) 'sku': sku,
        'description': description,
        'unitOfMeasure': unitOfMeasure,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'discountAmount': discountAmount,
        'taxRatePercent': taxRatePercent,
        'lineTotal': lineTotal,
        'taxAmount': taxAmount,
      };

  InvoiceLine copyWith({
    String? id,
    String? productId,
    String? sku,
    String? description,
    String? unitOfMeasure,
    double? quantity,
    double? unitPrice,
    double? discountAmount,
    double? taxRatePercent,
    double? lineTotal,
    double? taxAmount,
  }) =>
      InvoiceLine(
        id: id ?? this.id,
        productId: productId ?? this.productId,
        sku: sku ?? this.sku,
        description: description ?? this.description,
        unitOfMeasure: unitOfMeasure ?? this.unitOfMeasure,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
        discountAmount: discountAmount ?? this.discountAmount,
        taxRatePercent: taxRatePercent ?? this.taxRatePercent,
        lineTotal: lineTotal ?? this.lineTotal,
        taxAmount: taxAmount ?? this.taxAmount,
      );
}

typedef CustomerInvoiceLine = InvoiceLine;

class CustomerInvoicePayment {
  CustomerInvoicePayment({
    required this.id,
    required this.amount,
    String? paymentMethod,
    String? method,
    this.reference,
    DateTime? paidAt,
    DateTime? paidAtUtc,
  })  : paymentMethod = paymentMethod ?? method ?? 'Malipo',
        paidAt = paidAt ?? paidAtUtc ?? DateTime.now();

  final String id;
  final double amount;
  final String paymentMethod;
  final String? reference;
  final DateTime paidAt;

  String get method => paymentMethod;
  DateTime get paidAtUtc => paidAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'method': paymentMethod,
        'reference': reference,
        'paidAt': paidAt.toIso8601String(),
        'paidAtUtc': paidAt.toIso8601String(),
      };

  factory CustomerInvoicePayment.fromJson(Map<String, dynamic> json) =>
      CustomerInvoicePayment(
        id: (json['id'] as String?) ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        paymentMethod: (json['paymentMethod'] as String?) ??
            (json['method'] as String?) ??
            'Malipo',
        reference: json['reference'] as String?,
        paidAt: json['paidAt'] != null
            ? DateTime.tryParse(json['paidAt'].toString()) ?? DateTime.now()
            : (json['paidAtUtc'] != null
                ? DateTime.tryParse(json['paidAtUtc'].toString()) ??
                    DateTime.now()
                : DateTime.now()),
      );
}

class CustomerInvoice {
  const CustomerInvoice({
    required this.id,
    String? number,
    String? invoiceNumber,
    this.customerId,
    this.customerName,
    this.currency = 'TZS',
    required this.issueDate,
    this.dueDate,
    this.notes,
    required this.status,
    required this.subtotal,
    this.taxAmount = 0,
    required this.totalAmount,
    this.amountPaid = 0,
    this.balanceDue = 0,
    this.paymentMethod,
    this.paymentReference,
    this.paidAtUtc,
    this.lines = const [],
    this.payments = const [],
    this.documentTitle = 'INVOICE',
    this.referenceNumber,
    this.paymentTerms,
    this.customerAttention,
    this.customerPhone,
    this.customerEmail,
    this.customerAddress,
    this.customerTin,
    this.customerVrn,
    this.discountAmount = 0,
    this.paymentInstructions,
    this.authorizedSignatoryName,
    this.authorizedSignatoryTitle,
    this.isSynced = true,
    this.verificationToken,
  }) : number = number ?? invoiceNumber ?? '';

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
  final String? customerVrn;
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
  final List<CustomerInvoicePayment> payments;
  final bool isSynced;
  final String? verificationToken;

  String get effectiveVerificationToken {
    if (verificationToken != null && verificationToken!.trim().isNotEmpty) {
      return verificationToken!.trim();
    }
    final cleanId = id.replaceAll('-', '');
    return cleanId.length >= 16 ? cleanId.substring(0, 16) : cleanId;
  }

  String get invoiceNumber => number;

  String displayNumber([String? customPrefix]) {
    if (customPrefix == null || customPrefix.trim().isEmpty) {
      return number;
    }
    final prefix = customPrefix.trim().toUpperCase();
    final dashIndex = number.indexOf('-');
    if (dashIndex > 0) {
      final firstSegment = number.substring(0, dashIndex).toUpperCase();
      if (firstSegment == prefix) return number;
      if (firstSegment == 'CINV' || firstSegment == 'INV') {
        return '$prefix-${number.substring(dashIndex + 1)}';
      }
    }
    return number;
  }

  String get customerLabel =>
      customerName != null && customerName!.isNotEmpty ? customerName! : '—';

  bool get isTaxInvoice =>
      documentTitle.toUpperCase().contains('TAX') ||
      documentTitle.toUpperCase().contains('KODI');

  bool get isProforma =>
      documentTitle.toUpperCase().contains('PROFORMA');

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
        isSynced: isSynced,
        verificationToken: effectiveVerificationToken,
        customerVrn: customerVrn,
      );

  CustomerInvoice copyWith({
    String? number,
    String? invoiceNumber,
    String? documentTitle,
    String? referenceNumber,
    String? paymentTerms,
    String? customerId,
    String? customerName,
    String? customerAttention,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    String? customerTin,
    String? customerVrn,
    DateTime? issueDate,
    DateTime? dueDate,
    String? notes,
    String? paymentInstructions,
    String? authorizedSignatoryName,
    String? authorizedSignatoryTitle,
    InvoiceStatus? status,
    double? subtotal,
    double? discountAmount,
    double? taxAmount,
    double? totalAmount,
    double? amountPaid,
    double? balanceDue,
    String? paymentMethod,
    String? paymentReference,
    DateTime? paidAtUtc,
    List<InvoiceLine>? lines,
    List<CustomerInvoicePayment>? payments,
    bool? isSynced,
    String? verificationToken,
  }) =>
      CustomerInvoice(
        id: id,
        number: number ?? invoiceNumber ?? this.number,
        documentTitle: documentTitle ?? this.documentTitle,
        referenceNumber: referenceNumber ?? this.referenceNumber,
        paymentTerms: paymentTerms ?? this.paymentTerms,
        customerId: customerId ?? this.customerId,
        customerName: customerName ?? this.customerName,
        customerAttention: customerAttention ?? this.customerAttention,
        customerPhone: customerPhone ?? this.customerPhone,
        customerEmail: customerEmail ?? this.customerEmail,
        customerAddress: customerAddress ?? this.customerAddress,
        customerTin: customerTin ?? this.customerTin,
        customerVrn: customerVrn ?? this.customerVrn,
        currency: currency,
        issueDate: issueDate ?? this.issueDate,
        dueDate: dueDate ?? this.dueDate,
        notes: notes ?? this.notes,
        paymentInstructions: paymentInstructions ?? this.paymentInstructions,
        authorizedSignatoryName:
            authorizedSignatoryName ?? this.authorizedSignatoryName,
        authorizedSignatoryTitle:
            authorizedSignatoryTitle ?? this.authorizedSignatoryTitle,
        status: status ?? this.status,
        subtotal: subtotal ?? this.subtotal,
        discountAmount: discountAmount ?? this.discountAmount,
        taxAmount: taxAmount ?? this.taxAmount,
        totalAmount: totalAmount ?? this.totalAmount,
        amountPaid: amountPaid ?? this.amountPaid,
        balanceDue: balanceDue ?? this.balanceDue,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        paymentReference: paymentReference ?? this.paymentReference,
        paidAtUtc: paidAtUtc ?? this.paidAtUtc,
        lines: lines ?? this.lines,
        payments: payments ?? this.payments,
        isSynced: isSynced ?? this.isSynced,
        verificationToken: verificationToken ?? this.verificationToken,
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
        'customerVrn': customerVrn,
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
        'payments': [for (final p in payments) p.toJson()],
        'isSynced': isSynced,
        'verificationToken': effectiveVerificationToken,
      };

  factory CustomerInvoice.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    final rawPayments = json['payments'];
    var paymentsList = <CustomerInvoicePayment>[];
    if (rawPayments is List) {
      paymentsList = rawPayments
          .whereType<Map<dynamic, dynamic>>()
          .map((raw) =>
              CustomerInvoicePayment.fromJson(Map<String, dynamic>.from(raw)))
          .toList();
    }

    final amountPaid = _requiredDouble(json, 'amountPaid');
    final paymentMethod = _optionalString(json, 'paymentMethod');
    final paymentReference = _optionalString(json, 'paymentReference');
    final paidAtUtc = _optionalDateTime(json, 'paidAtUtc');
    final issueDate = _requiredDateTime(json, 'issueDate');

    if (paymentsList.isEmpty && amountPaid > 0) {
      paymentsList.add(CustomerInvoicePayment(
        id: 'legacy_initial_payment',
        amount: amountPaid,
        paymentMethod: paymentMethod ?? 'Malipo ya Awali',
        reference: paymentReference,
        paidAt: paidAtUtc ?? issueDate,
      ));
    }

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
      customerVrn: _optionalString(json, 'customerVrn'),
      currency: _optionalString(json, 'currency') ?? 'TZS',
      issueDate: issueDate,
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
      amountPaid: amountPaid,
      balanceDue: _requiredDouble(json, 'balanceDue'),
      paymentMethod: paymentMethod,
      paymentReference: paymentReference,
      paidAtUtc: paidAtUtc,
      isSynced: (json['isSynced'] as bool?) ?? true,
      verificationToken: _optionalString(json, 'verificationToken'),
      lines: rawLines is List
          ? rawLines
              .whereType<Map<dynamic, dynamic>>()
              .map(
                  (raw) => InvoiceLine.fromJson(Map<String, dynamic>.from(raw)))
              .toList(growable: false)
          : const [],
      payments: paymentsList,
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
    this.isSynced = true,
    this.verificationToken,
    this.customerVrn,
  });

  final String id;
  final String number;
  final String documentTitle;
  final String? referenceNumber;
  final String currency;
  final String? customerId;
  final String? customerName;
  final String? customerVrn;
  final InvoiceStatus status;
  final DateTime issueDate;
  final DateTime? dueDate;
  final double totalAmount;
  final double amountPaid;
  final double balanceDue;
  final bool isSynced;
  final String? verificationToken;

  bool get isTaxInvoice =>
      documentTitle.toUpperCase().contains('TAX') ||
      documentTitle.toUpperCase().contains('KODI');

  bool get isProforma =>
      documentTitle.toUpperCase().contains('PROFORMA');

  String get effectiveVerificationToken {
    if (verificationToken != null && verificationToken!.trim().isNotEmpty) {
      return verificationToken!.trim();
    }
    final cleanId = id.replaceAll('-', '');
    return cleanId.length >= 16 ? cleanId.substring(0, 16) : cleanId;
  }

  String get customerLabel =>
      customerName != null && customerName!.isNotEmpty ? customerName! : '—';

  String get invoiceNumber => number;

  String displayNumber([String? customPrefix]) {
    if (customPrefix == null || customPrefix.trim().isEmpty) {
      return number;
    }
    final prefix = customPrefix.trim().toUpperCase();
    final dashIndex = number.indexOf('-');
    if (dashIndex > 0) {
      final firstSegment = number.substring(0, dashIndex).toUpperCase();
      if (firstSegment == prefix) return number;
      if (firstSegment == 'CINV' || firstSegment == 'INV') {
        return '$prefix-${number.substring(dashIndex + 1)}';
      }
    }
    return number;
  }

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
      isSynced: (json['isSynced'] as bool?) ?? true,
      verificationToken: _optionalString(json, 'verificationToken'),
      customerVrn: _optionalString(json, 'customerVrn'),
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
        'customerVrn': customerVrn,
        'status': status.code,
        'issueDate': issueDate.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'totalAmount': totalAmount,
        'amountPaid': amountPaid,
        'balanceDue': balanceDue,
        'isSynced': isSynced,
        'verificationToken': effectiveVerificationToken,
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
    this.productId,
    this.sku,
    this.description = '',
    this.unitOfMeasure = 'Pcs',
    this.quantity = 1,
    this.unitPrice = 0,
    this.discountAmount = 0,
    this.taxRatePercent = 0,
  });

  String? productId;
  String? sku;
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
        if (productId != null) 'productId': productId,
        if (sku != null && sku!.isNotEmpty) 'sku': sku,
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
