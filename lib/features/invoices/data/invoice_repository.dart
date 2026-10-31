import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_routes.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/storage/offline_cache_dao.dart';
import '../domain/invoice.dart';

class InvoiceRepository {
  InvoiceRepository({
    required ApiClient apiClient,
    OfflineCacheDao? cache,
  })  : _apiClient = apiClient,
        _cache = cache;

  final ApiClient _apiClient;
  final OfflineCacheDao? _cache;
  static const _uuid = Uuid();

  Future<InvoicePage> list({
    int page = 1,
    int pageSize = 20,
    InvoiceStatus? status,
    String? search,
  }) async {
    try {
      final response = await _apiClient.get<dynamic>(
        ApiRoutes.v1('/invoices'),
        query: <String, dynamic>{
          'page': page,
          'pageSize': pageSize,
          if (status != null) 'status': status.code,
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
        },
      );
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Jibu la mfumo halijui muundo sahihi.');
      }
      final doc = Map<String, dynamic>.from(response.data as Map);
      final rawItems = doc['items'];
      final serverItems = rawItems is List
          ? rawItems
              .whereType<Map<dynamic, dynamic>>()
              .map((raw) => CustomerInvoiceSummary.fromJson(
                  Map<String, dynamic>.from(raw)))
              .toList(growable: false)
          : <CustomerInvoiceSummary>[];

      // Merge any locally created offline invoices not yet on the server
      final mergedItems = await _mergeWithCachedList(
        serverItems,
        status: status,
        search: search,
      );

      final invoicePage = InvoicePage(
        items: mergedItems,
        total: (doc['total'] as num?)?.toInt() ?? mergedItems.length,
        page: (doc['page'] as num?)?.toInt() ?? page,
      );
      if (_cache != null && page == 1 && (search == null || search.isEmpty) && status == null) {
        await _cache.save('invoices_list', {
          'items': mergedItems.map((i) => i.toJson()).toList(),
          'total': invoicePage.total,
        });
      }
      return invoicePage;
    } on AppException {
      return _loadOfflineList(status: status, search: search);
    }
  }

  Future<CustomerInvoice> getById(String id) async {
    try {
      final response =
          await _apiClient.get<dynamic>(ApiRoutes.v1('/invoices/$id'));
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Ankara hazipatikani.');
      }
      final invoice = CustomerInvoice.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      if (_cache != null) {
        await _cache.save('invoice_$id', invoice.toJson());
      }
      return invoice;
    } on AppException {
      if (_cache != null) {
        final cached = await _cache.load('invoice_$id');
        if (cached != null) {
          return CustomerInvoice.fromJson(cached);
        }
      }
      rethrow;
    }
  }

  Future<CustomerInvoice> create({
    required List<InvoiceDraftLine> lines,
    String? customerId,
    String? customerName,
    String? customerAttention,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    String? customerTin,
    String currency = 'TZS',
    String documentTitle = 'INVOICE',
    String? referenceNumber,
    String? paymentTerms,
    DateTime? issueDate,
    DateTime? dueDate,
    double discountAmount = 0,
    double initialAmountPaid = 0,
    String? paymentMethod,
    String? paymentReference,
    String? paymentInstructions,
    String? notes,
    String? authorizedSignatoryName,
    String? authorizedSignatoryTitle,
  }) async {
    final clientId = _uuid.v4();
    final now = DateTime.now();
    final issued = issueDate ?? now;

    try {
      final response = await _apiClient.post<dynamic>(
        ApiRoutes.v1('/invoices'),
        body: <String, dynamic>{
          'id': clientId,
          'lines': [for (final line in lines) line.toJson()],
          if (customerId != null && customerId.isNotEmpty)
            'customerId': customerId,
          if (customerName != null && customerName.trim().isNotEmpty)
            'customerName': customerName.trim(),
          if (customerAttention != null && customerAttention.trim().isNotEmpty)
            'customerAttention': customerAttention.trim(),
          if (customerPhone != null && customerPhone.trim().isNotEmpty)
            'customerPhone': customerPhone.trim(),
          if (customerEmail != null && customerEmail.trim().isNotEmpty)
            'customerEmail': customerEmail.trim(),
          if (customerAddress != null && customerAddress.trim().isNotEmpty)
            'customerAddress': customerAddress.trim(),
          if (customerTin != null && customerTin.trim().isNotEmpty)
            'customerTin': customerTin.trim(),
          'currency': currency,
          'documentTitle': documentTitle,
          if (referenceNumber != null && referenceNumber.trim().isNotEmpty)
            'referenceNumber': referenceNumber.trim(),
          if (paymentTerms != null && paymentTerms.trim().isNotEmpty)
            'paymentTerms': paymentTerms.trim(),
          'issueDate': issued.toUtc().toIso8601String(),
          if (dueDate != null) 'dueDate': dueDate.toUtc().toIso8601String(),
          'discountAmount': discountAmount,
          'initialAmountPaid': initialAmountPaid,
          if (paymentMethod != null && paymentMethod.trim().isNotEmpty)
            'paymentMethod': paymentMethod.trim(),
          if (paymentReference != null && paymentReference.trim().isNotEmpty)
            'paymentReference': paymentReference.trim(),
          if (paymentInstructions != null &&
              paymentInstructions.trim().isNotEmpty)
            'paymentInstructions': paymentInstructions.trim(),
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
          if (authorizedSignatoryName != null &&
              authorizedSignatoryName.trim().isNotEmpty)
            'authorizedSignatoryName': authorizedSignatoryName.trim(),
          if (authorizedSignatoryTitle != null &&
              authorizedSignatoryTitle.trim().isNotEmpty)
            'authorizedSignatoryTitle': authorizedSignatoryTitle.trim(),
        },
      );
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Ankara haikuweza kuhifadhiwa.');
      }
      final created = CustomerInvoice.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      await _persistLocally(created);
      return created;
    } on AppException {
      // Offline-first fallback: generate local invoice immediately so user can
      // view, print, or share the A4 PDF even without internet!
      final builtLines = <InvoiceLine>[
        for (var i = 0; i < lines.length; i++)
          InvoiceLine(
            id: _uuid.v4(),
            description: lines[i].description.trim(),
            unitOfMeasure: lines[i].unitOfMeasure.trim().isEmpty
                ? 'Pcs'
                : lines[i].unitOfMeasure.trim(),
            quantity: lines[i].quantity,
            unitPrice: lines[i].unitPrice,
            discountAmount: lines[i].effectiveDiscount,
            taxRatePercent: lines[i].taxRatePercent,
            lineTotal: lines[i].lineTotal,
            taxAmount: lines[i].lineTax,
          ),
      ];
      final subtotal =
          builtLines.fold<double>(0, (sum, l) => sum + l.lineTotal);
      final effectiveDiscount = discountAmount.clamp(0.0, subtotal);
      final taxAmount =
          builtLines.fold<double>(0, (sum, l) => sum + l.taxAmount);
      final totalAmount = (subtotal - effectiveDiscount) + taxAmount;
      final paid = initialAmountPaid.clamp(0.0, totalAmount);
      final balance = totalAmount - paid;
      final status = paid >= totalAmount && totalAmount > 0
          ? InvoiceStatus.paid
          : (paid > 0 ? InvoiceStatus.partiallyPaid : InvoiceStatus.unpaid);

      final numberSeq =
          'CINV-${issued.year}${issued.month.toString().padLeft(2, '0')}-${(now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0')}';

      final localInvoice = CustomerInvoice(
        id: clientId,
        number: numberSeq,
        documentTitle: documentTitle,
        referenceNumber: referenceNumber?.trim(),
        paymentTerms: paymentTerms?.trim(),
        customerId: customerId,
        customerName: customerName?.trim(),
        customerAttention: customerAttention?.trim(),
        customerPhone: customerPhone?.trim(),
        customerEmail: customerEmail?.trim(),
        customerAddress: customerAddress?.trim(),
        customerTin: customerTin?.trim(),
        currency: currency,
        issueDate: issued,
        dueDate: dueDate,
        notes: notes?.trim(),
        paymentInstructions: paymentInstructions?.trim(),
        authorizedSignatoryName: authorizedSignatoryName?.trim(),
        authorizedSignatoryTitle: authorizedSignatoryTitle?.trim(),
        status: status,
        subtotal: subtotal,
        discountAmount: effectiveDiscount,
        taxAmount: taxAmount,
        totalAmount: totalAmount,
        amountPaid: paid,
        balanceDue: balance,
        paymentMethod: paymentMethod?.trim(),
        paymentReference: paymentReference?.trim(),
        paidAtUtc: status == InvoiceStatus.paid ? now : null,
        lines: builtLines,
      );
      await _persistLocally(localInvoice);
      return localInvoice;
    }
  }

  Future<CustomerInvoice> recordPayment(
    String id, {
    required double amount,
    String? method,
    String? reference,
  }) async {
    try {
      final response = await _apiClient.post<dynamic>(
        ApiRoutes.v1('/invoices/$id/payments'),
        body: <String, dynamic>{
          'amount': amount,
          if (method != null && method.isNotEmpty) 'method': method,
          if (reference != null && reference.isNotEmpty) 'reference': reference,
        },
      );
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Malipo hayakuweza kurekodiwa.');
      }
      final updated = CustomerInvoice.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      await _persistLocally(updated);
      return updated;
    } on AppException {
      if (_cache != null) {
        final cached = await _cache.load('invoice_$id');
        if (cached != null) {
          final current = CustomerInvoice.fromJson(cached);
          final newPaid =
              (current.amountPaid + amount).clamp(0.0, current.totalAmount);
          final newBalance = current.totalAmount - newPaid;
          final newStatus = newBalance <= 0
              ? InvoiceStatus.paid
              : InvoiceStatus.partiallyPaid;
          final updated = current.copyWith(
            status: newStatus,
            amountPaid: newPaid,
            balanceDue: newBalance,
            paymentMethod:
                (method != null && method.isNotEmpty) ? method : current.paymentMethod,
            paymentReference: (reference != null && reference.isNotEmpty)
                ? reference
                : current.paymentReference,
            paidAtUtc:
                newStatus == InvoiceStatus.paid ? DateTime.now() : current.paidAtUtc,
          );
          await _persistLocally(updated);
          return updated;
        }
      }
      rethrow;
    }
  }

  Future<CustomerInvoice> voidInvoice(String id) async {
    try {
      final response = await _apiClient.post<dynamic>(
        ApiRoutes.v1('/invoices/$id/void'),
      );
      if (response.statusCode != 200 || response.data is! Map) {
        throw ServerException('Ankara haikuweza kufutwa.');
      }
      final updated = CustomerInvoice.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      await _persistLocally(updated);
      return updated;
    } on AppException {
      if (_cache != null) {
        final cached = await _cache.load('invoice_$id');
        if (cached != null) {
          final current = CustomerInvoice.fromJson(cached);
          final updated = current.copyWith(status: InvoiceStatus.voided);
          await _persistLocally(updated);
          return updated;
        }
      }
      rethrow;
    }
  }

  Future<void> _persistLocally(CustomerInvoice invoice) async {
    if (_cache == null) return;
    await _cache.save('invoice_${invoice.id}', invoice.toJson());
    final listDoc = await _cache.load('invoices_list');
    final existing = <CustomerInvoiceSummary>[];
    if (listDoc != null && listDoc['items'] is List) {
      for (final raw in (listDoc['items'] as List)) {
        if (raw is Map) {
          try {
            existing.add(
              CustomerInvoiceSummary.fromJson(Map<String, dynamic>.from(raw)),
            );
          } catch (_) {}
        }
      }
    }
    final summary = invoice.toSummary();
    final idx = existing.indexWhere((i) => i.id == invoice.id);
    if (idx >= 0) {
      existing[idx] = summary;
    } else {
      existing.insert(0, summary);
    }
    await _cache.save('invoices_list', {
      'items': existing.map((i) => i.toJson()).toList(),
      'total': existing.length,
    });
  }

  Future<List<CustomerInvoiceSummary>> _mergeWithCachedList(
    List<CustomerInvoiceSummary> serverItems, {
    InvoiceStatus? status,
    String? search,
  }) async {
    if (_cache == null) return serverItems;
    final listDoc = await _cache.load('invoices_list');
    if (listDoc == null || listDoc['items'] is! List) return serverItems;
    final serverIds = {for (final item in serverItems) item.id};
    final localOnly = <CustomerInvoiceSummary>[];
    for (final raw in (listDoc['items'] as List)) {
      if (raw is Map) {
        try {
          final item =
              CustomerInvoiceSummary.fromJson(Map<String, dynamic>.from(raw));
          if (!serverIds.contains(item.id)) {
            localOnly.add(item);
          }
        } catch (_) {}
      }
    }
    final combined = [...localOnly, ...serverItems];
    return _filterList(combined, status: status, search: search);
  }

  Future<InvoicePage> _loadOfflineList({
    InvoiceStatus? status,
    String? search,
  }) async {
    if (_cache != null) {
      final cached = await _cache.load('invoices_list');
      if (cached != null && cached['items'] is List) {
        final items = (cached['items'] as List)
            .whereType<Map<dynamic, dynamic>>()
            .map((raw) =>
                CustomerInvoiceSummary.fromJson(Map<String, dynamic>.from(raw)))
            .toList(growable: false);
        final filtered = _filterList(items, status: status, search: search);
        return InvoicePage(items: filtered, total: filtered.length, page: 1);
      }
    }
    return const InvoicePage(items: [], total: 0, page: 1);
  }

  List<CustomerInvoiceSummary> _filterList(
    List<CustomerInvoiceSummary> items, {
    InvoiceStatus? status,
    String? search,
  }) {
    var result = items;
    if (status != null) {
      result = result.where((i) => i.status == status).toList();
    }
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      result = result
          .where((i) =>
              i.number.toLowerCase().contains(q) ||
              i.customerLabel.toLowerCase().contains(q) ||
              (i.referenceNumber?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return result;
  }
}
