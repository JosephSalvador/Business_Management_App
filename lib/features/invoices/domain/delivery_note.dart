enum DeliveryNoteStatus {
  draft(0),
  dispatched(1),
  delivered(2),
  cancelled(3);

  const DeliveryNoteStatus(this.code);
  final int code;

  static DeliveryNoteStatus fromCode(Object? value) {
    if (value is int) {
      return values.firstWhere(
        (status) => status.code == value,
        orElse: () => DeliveryNoteStatus.draft,
      );
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return fromCode(parsed);
      return values.firstWhere(
        (status) => status.name.toLowerCase() == value.toLowerCase(),
        orElse: () => DeliveryNoteStatus.draft,
      );
    }
    return DeliveryNoteStatus.draft;
  }
}

class DeliveryNoteItem {
  const DeliveryNoteItem({
    required this.id,
    required this.productName,
    required this.quantityToDeliver,
    this.productId,
    this.sku,
    this.quantityOrdered = 0,
    this.unitOfMeasure = 'Pcs',
    this.notes,
  });

  final String id;
  final String? productId;
  final String productName;
  final String? sku;
  final double quantityOrdered;
  final double quantityToDeliver;
  final String unitOfMeasure;
  final String? notes;

  factory DeliveryNoteItem.fromJson(Map<String, dynamic> json) =>
      DeliveryNoteItem(
        id: (json['id'] ?? '').toString(),
        productId: json['productId']?.toString(),
        productName: (json['productName'] ?? json['description'] ?? 'Bidhaa').toString(),
        sku: json['sku']?.toString(),
        quantityOrdered: (json['quantityOrdered'] as num?)?.toDouble() ?? 0,
        quantityToDeliver:
            (json['quantityToDeliver'] ?? json['quantity'] as num?)?.toDouble() ?? 1,
        unitOfMeasure: (json['unitOfMeasure'] ?? 'Pcs').toString(),
        notes: json['notes']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        if (productId != null) 'productId': productId,
        'productName': productName,
        if (sku != null) 'sku': sku,
        'quantityOrdered': quantityOrdered,
        'quantityToDeliver': quantityToDeliver,
        'unitOfMeasure': unitOfMeasure,
        if (notes != null) 'notes': notes,
      };
}

class DeliveryNote {
  const DeliveryNote({
    required this.id,
    required this.number,
    required this.customerName,
    required this.issueDate,
    required this.status,
    required this.items,
    this.tenantId,
    this.invoiceId,
    this.customerId,
    this.customerPhone,
    this.customerAddress,
    this.deliveryAddress,
    this.carrierName,
    this.trackingNumber,
    this.vehicleNumber,
    this.driverName,
    this.driverPhone,
    this.dispatchedAt,
    this.deliveredAt,
    this.notes,
    this.recipientName,
    this.recipientSignature,
    this.isSynced = true,
  });

  final String id;
  final String number;
  final String? tenantId;
  final String? invoiceId;
  final String? customerId;
  final String customerName;
  final String? customerPhone;
  final String? customerAddress;
  final String? deliveryAddress;
  final String? carrierName;
  final String? trackingNumber;
  final String? vehicleNumber;
  final String? driverName;
  final String? driverPhone;
  final DeliveryNoteStatus status;
  final DateTime issueDate;
  final DateTime? dispatchedAt;
  final DateTime? deliveredAt;
  final String? notes;
  final String? recipientName;
  final String? recipientSignature;
  final List<DeliveryNoteItem> items;
  final bool isSynced;

  double get totalQuantity =>
      items.fold<double>(0, (sum, item) => sum + item.quantityToDeliver);

  DeliveryNoteSummary toSummary() => DeliveryNoteSummary(
        id: id,
        number: number,
        customerName: customerName,
        status: status,
        issueDate: issueDate,
        itemCount: items.length,
        totalQuantity: totalQuantity,
        carrierName: carrierName,
        isSynced: isSynced,
      );

  DeliveryNote copyWith({
    DeliveryNoteStatus? status,
    DateTime? dispatchedAt,
    DateTime? deliveredAt,
    String? recipientName,
    String? recipientSignature,
    bool? isSynced,
  }) =>
      DeliveryNote(
        id: id,
        number: number,
        tenantId: tenantId,
        invoiceId: invoiceId,
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        customerAddress: customerAddress,
        deliveryAddress: deliveryAddress,
        carrierName: carrierName,
        trackingNumber: trackingNumber,
        vehicleNumber: vehicleNumber,
        driverName: driverName,
        driverPhone: driverPhone,
        status: status ?? this.status,
        issueDate: issueDate,
        dispatchedAt: dispatchedAt ?? this.dispatchedAt,
        deliveredAt: deliveredAt ?? this.deliveredAt,
        notes: notes,
        recipientName: recipientName ?? this.recipientName,
        recipientSignature: recipientSignature ?? this.recipientSignature,
        items: items,
        isSynced: isSynced ?? this.isSynced,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        if (tenantId != null) 'tenantId': tenantId,
        if (invoiceId != null) 'invoiceId': invoiceId,
        if (customerId != null) 'customerId': customerId,
        'customerName': customerName,
        if (customerPhone != null) 'customerPhone': customerPhone,
        if (customerAddress != null) 'customerAddress': customerAddress,
        if (deliveryAddress != null) 'deliveryAddress': deliveryAddress,
        if (carrierName != null) 'carrierName': carrierName,
        if (trackingNumber != null) 'trackingNumber': trackingNumber,
        if (vehicleNumber != null) 'vehicleNumber': vehicleNumber,
        if (driverName != null) 'driverName': driverName,
        if (driverPhone != null) 'driverPhone': driverPhone,
        'status': status.code,
        'issueDate': issueDate.toIso8601String(),
        if (dispatchedAt != null) 'dispatchedAt': dispatchedAt!.toIso8601String(),
        if (deliveredAt != null) 'deliveredAt': deliveredAt!.toIso8601String(),
        if (notes != null) 'notes': notes,
        if (recipientName != null) 'recipientName': recipientName,
        if (recipientSignature != null) 'recipientSignature': recipientSignature,
        'items': [for (final item in items) item.toJson()],
        'isSynced': isSynced,
      };

  factory DeliveryNote.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return DeliveryNote(
      id: (json['id'] ?? '').toString(),
      number: (json['number'] ?? '').toString(),
      tenantId: json['tenantId']?.toString(),
      invoiceId: json['invoiceId']?.toString(),
      customerId: json['customerId']?.toString(),
      customerName: (json['customerName'] ?? '—').toString(),
      customerPhone: json['customerPhone']?.toString(),
      customerAddress: json['customerAddress']?.toString(),
      deliveryAddress: json['deliveryAddress']?.toString(),
      carrierName: json['carrierName']?.toString(),
      trackingNumber: json['trackingNumber']?.toString(),
      vehicleNumber: json['vehicleNumber']?.toString(),
      driverName: json['driverName']?.toString(),
      driverPhone: json['driverPhone']?.toString(),
      status: DeliveryNoteStatus.fromCode(json['status']),
      issueDate: json['issueDate'] != null
          ? DateTime.parse(json['issueDate'].toString())
          : DateTime.now(),
      dispatchedAt: json['dispatchedAt'] != null
          ? DateTime.tryParse(json['dispatchedAt'].toString())
          : null,
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.tryParse(json['deliveredAt'].toString())
          : null,
      notes: json['notes']?.toString(),
      recipientName: json['recipientName']?.toString(),
      recipientSignature: json['recipientSignature']?.toString(),
      isSynced: (json['isSynced'] as bool?) ?? true,
      items: rawItems is List
          ? rawItems
              .whereType<Map<dynamic, dynamic>>()
              .map((raw) =>
                  DeliveryNoteItem.fromJson(Map<String, dynamic>.from(raw)))
              .toList(growable: false)
          : const [],
    );
  }
}

class DeliveryNoteSummary {
  const DeliveryNoteSummary({
    required this.id,
    required this.number,
    required this.customerName,
    required this.status,
    required this.issueDate,
    required this.itemCount,
    required this.totalQuantity,
    this.carrierName,
    this.isSynced = true,
  });

  final String id;
  final String number;
  final String customerName;
  final DeliveryNoteStatus status;
  final DateTime issueDate;
  final int itemCount;
  final double totalQuantity;
  final String? carrierName;
  final bool isSynced;

  factory DeliveryNoteSummary.fromJson(Map<String, dynamic> json) =>
      DeliveryNoteSummary(
        id: (json['id'] ?? '').toString(),
        number: (json['number'] ?? '').toString(),
        customerName: (json['customerName'] ?? '—').toString(),
        status: DeliveryNoteStatus.fromCode(json['status']),
        issueDate: json['issueDate'] != null
            ? DateTime.parse(json['issueDate'].toString())
            : DateTime.now(),
        itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
        totalQuantity: (json['totalQuantity'] as num?)?.toDouble() ?? 0,
        carrierName: json['carrierName']?.toString(),
        isSynced: (json['isSynced'] as bool?) ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'customerName': customerName,
        'status': status.code,
        'issueDate': issueDate.toIso8601String(),
        'itemCount': itemCount,
        'totalQuantity': totalQuantity,
        if (carrierName != null) 'carrierName': carrierName,
        'isSynced': isSynced,
      };
}

class DeliveryNotePage {
  const DeliveryNotePage({
    required this.items,
    required this.total,
    required this.page,
  });

  final List<DeliveryNoteSummary> items;
  final int total;
  final int page;
}
