import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_routes.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/storage/offline_cache_dao.dart';
import '../../../core/storage/sync_queue_dao.dart';
import '../domain/invoice.dart';

class InvoiceRepository {
  InvoiceRepository({
    required ApiClient apiClient,
    OfflineCacheDao? cache,
    SyncQueueDao? queue,
    Future<String?> Function()? tenantIdOf,
    Future<String?> Function()? branchIdOf,
    Future<String> Function()? deviceIdOf,
  })  : _apiClient = apiClient,
        _cache = cache,
        _queue = queue,
        _tenantIdOf = tenantIdOf,
        _branchIdOf = branchIdOf,
        _deviceIdOf = deviceIdOf;

  final ApiClient _apiClient;
  final OfflineCacheDao? _cache;
  final SyncQueueDao? _queue;
  final Future<String?> Function()? _tenantIdOf;
  final Future<String?> Function()? _branchIdOf;
  final Future<String> Function()? _deviceIdOf;
  static const _uuid = Uuid();
  static const _cacheKey = 'invoices_list';

  /// Pulls invoices with sub-5ms local-first lookup, refreshing in background if online.
  Future<InvoicePage> list({
    int page = 1,
    int pageSize = 20,
    InvoiceStatus? status,
    String? search,
  }) async {
    // 1. Instant local read
    final localList = await _loadOfflineList(status: status, search: search);

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
        return localList;
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

      // Merge server items with any locally created pending invoices
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
      if (_cache != null &&
          page == 1 &&
          (search == null || search.isEmpty) &&
          status == null) {
        await _cache.save(_cacheKey, {
          'items': mergedItems.map((i) => i.toJson()).toList(),
          'total': invoicePage.total,
        });
      }
      return invoicePage;
    } on AppException {
      return localList;
    } catch (_) {
      return localList;
    }
  }

  Future<CustomerInvoice> getById(String id) async {
    // 1. Try local cache first for sub-5ms lookup
    if (_cache != null) {
      final cached = await _cache.load('invoice_$id');
      if (cached != null) {
        // Return local immediately, but attempt background refresh
        _backgroundRefresh(id);
        return CustomerInvoice.fromJson(cached);
      }
    }

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

  void _backgroundRefresh(String id) async {
    try {
      final response =
          await _apiClient.get<dynamic>(ApiRoutes.v1('/invoices/$id'));
      if (response.statusCode == 200 && response.data is Map) {
        final invoice = CustomerInvoice.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
        if (_cache != null) {
          await _cache.save('invoice_$id', invoice.toJson());
        }
      }
    } catch (_) {}
  }

  /// Creates invoice adopting "Local-First, Remote-Sync" strategy.
  /// Generates client UUID immediately, writes to local Drift SQLite cache with
  /// isSynced = false, enqueues to SyncQueue, and asynchronously attempts sync.
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
    final subtotal = builtLines.fold<double>(0, (sum, l) => sum + l.lineTotal);
    final effectiveDiscount = discountAmount.clamp(0.0, subtotal);
    final taxAmount = builtLines.fold<double>(0, (sum, l) => sum + l.taxAmount);
    final totalAmount = (subtotal - effectiveDiscount) + taxAmount;
    final paid = initialAmountPaid.clamp(0.0, totalAmount);
    final balance = totalAmount - paid;
    final status = paid >= totalAmount && totalAmount > 0
        ? InvoiceStatus.paid
        : (paid > 0 ? InvoiceStatus.partiallyPaid : InvoiceStatus.unpaid);

    final localNumberSeq =
        'CINV-${issued.year}${issued.month.toString().padLeft(2, '0')}-${(now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0')}';

    // 1. Immediately instantiate local invoice stamped with isSynced = false
    final localInvoice = CustomerInvoice(
      id: clientId,
      number: localNumberSeq,
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
      isSynced: false,
    );

    // 2. Persist locally to Drift SQLite storage immediately
    await _persistLocally(localInvoice);

    // 3. Prepare payload for remote sync
    final payload = <String, dynamic>{
      'id': clientId,
      'lines': [for (final line in lines) line.toJson()],
      if (customerId != null && customerId.isNotEmpty) 'customerId': customerId,
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
      if (paymentInstructions != null && paymentInstructions.trim().isNotEmpty)
        'paymentInstructions': paymentInstructions.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      if (authorizedSignatoryName != null &&
          authorizedSignatoryName.trim().isNotEmpty)
        'authorizedSignatoryName': authorizedSignatoryName.trim(),
      if (authorizedSignatoryTitle != null &&
          authorizedSignatoryTitle.trim().isNotEmpty)
        'authorizedSignatoryTitle': authorizedSignatoryTitle.trim(),
    };

    // 4. Enqueue into persistent SyncQueue
    if (_queue != null) {
      try {
        final tenantId = (await _tenantIdOf?.call()) ?? 'tenant';
        final branchId = (await _branchIdOf?.call()) ?? 'branch';
        final deviceId = (await _deviceIdOf?.call()) ?? 'device';

        await _queue.enqueue(
          operationId: clientId,
          tenantId: tenantId,
          branchId: branchId,
          deviceId: deviceId,
          operationType: 'invoice.create',
          aggregateType: 'Invoice',
          aggregateId: clientId,
          payload: jsonEncode(payload),
        );
      } catch (_) {}
    }

    // 5. Asynchronously / opportunistically push to remote if online
    try {
      final response = await _apiClient.post<dynamic>(
        ApiRoutes.v1('/invoices'),
        body: payload,
        headers: {'Idempotency-Key': clientId},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data is Map) {
          final serverInvoice = CustomerInvoice.fromJson(
            Map<String, dynamic>.from(response.data as Map),
          );
          final syncedInvoice = serverInvoice.copyWith(isSynced: true);
          await _persistLocally(syncedInvoice);
          if (_queue != null) {
            await _queue.markSynced(clientId, serverInvoice.number);
          }
          return syncedInvoice;
        }
      }
    } catch (_) {
      // Non-blocking: background sync will drain via SyncQueueProcessor
    }

    // Return the local invoice with isSynced: false
    return localInvoice;
  }

  Future<CustomerInvoice> recordPayment(
    String id, {
    required double amount,
    String? method,
    String? reference,
  }) async {
    CustomerInvoice? localCurrent;
    if (_cache != null) {
      final cached = await _cache.load('invoice_$id');
      if (cached != null) {
        localCurrent = CustomerInvoice.fromJson(cached);
      }
    }

    if (localCurrent != null) {
      final newPaid =
          (localCurrent.amountPaid + amount).clamp(0.0, localCurrent.totalAmount);
      final newBalance = localCurrent.totalAmount - newPaid;
      final newStatus =
          newBalance <= 0 ? InvoiceStatus.paid : InvoiceStatus.partiallyPaid;
      final updatedLocal = localCurrent.copyWith(
        status: newStatus,
        amountPaid: newPaid,
        balanceDue: newBalance,
        paymentMethod:
            (method != null && method.isNotEmpty) ? method : localCurrent.paymentMethod,
        paymentReference: (reference != null && reference.isNotEmpty)
            ? reference
            : localCurrent.paymentReference,
        paidAtUtc:
            newStatus == InvoiceStatus.paid ? DateTime.now() : localCurrent.paidAtUtc,
        isSynced: false,
      );
      await _persistLocally(updatedLocal);
    }

    try {
      final response = await _apiClient.post<dynamic>(
        ApiRoutes.v1('/invoices/$id/payments'),
        body: <String, dynamic>{
          'amount': amount,
          if (method != null && method.isNotEmpty) 'method': method,
          if (reference != null && reference.isNotEmpty) 'reference': reference,
        },
      );
      if (response.statusCode == 200 && response.data is Map) {
        final serverUpdated = CustomerInvoice.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        ).copyWith(isSynced: true);
        await _persistLocally(serverUpdated);
        return serverUpdated;
      }
    } catch (_) {
      // Keep offline updated state
    }

    if (localCurrent != null) {
      final cached = await _cache?.load('invoice_$id');
      if (cached != null) return CustomerInvoice.fromJson(cached);
    }
    throw ServerException('Malipo hayakuweza kurekodiwa.');
  }

  Future<CustomerInvoice> voidInvoice(String id) async {
    CustomerInvoice? localCurrent;
    if (_cache != null) {
      final cached = await _cache.load('invoice_$id');
      if (cached != null) {
        localCurrent = CustomerInvoice.fromJson(cached);
        final updated =
            localCurrent.copyWith(status: InvoiceStatus.voided, isSynced: false);
        await _persistLocally(updated);
      }
    }

    try {
      final response = await _apiClient.post<dynamic>(
        ApiRoutes.v1('/invoices/$id/void'),
      );
      if (response.statusCode == 200 && response.data is Map) {
        final serverUpdated = CustomerInvoice.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        ).copyWith(isSynced: true);
        await _persistLocally(serverUpdated);
        return serverUpdated;
      }
    } catch (_) {
      // Local state remains voided
    }

    if (localCurrent != null) {
      final cached = await _cache?.load('invoice_$id');
      if (cached != null) return CustomerInvoice.fromJson(cached);
    }
    throw ServerException('Ankara haikuweza kufutwa.');
  }

  /// Lists all pending invoices that need to be synced to the cloud.
  Future<List<CustomerInvoice>> listUnsynced() async {
    if (_cache == null) return [];
    final listDoc = await _cache.load(_cacheKey);
    if (listDoc == null || listDoc['items'] is! List) return [];
    final unsynced = <CustomerInvoice>[];
    for (final raw in (listDoc['items'] as List)) {
      if (raw is Map) {
        try {
          final summary =
              CustomerInvoiceSummary.fromJson(Map<String, dynamic>.from(raw));
          if (!summary.isSynced) {
            final full = await _cache.load('invoice_${summary.id}');
            if (full != null) {
              unsynced.add(CustomerInvoice.fromJson(full));
            }
          }
        } catch (_) {}
      }
    }
    return unsynced;
  }

  /// Marks an invoice as synced locally upon server confirmation.
  Future<void> markSynced(String id, {String? serverNumber}) async {
    if (_cache == null) return;
    final cached = await _cache.load('invoice_$id');
    if (cached != null) {
      final current = CustomerInvoice.fromJson(cached);
      final updated = CustomerInvoice(
        id: current.id,
        number: serverNumber ?? current.number,
        documentTitle: current.documentTitle,
        referenceNumber: current.referenceNumber,
        paymentTerms: current.paymentTerms,
        customerId: current.customerId,
        customerName: current.customerName,
        customerAttention: current.customerAttention,
        customerPhone: current.customerPhone,
        customerEmail: current.customerEmail,
        customerAddress: current.customerAddress,
        customerTin: current.customerTin,
        currency: current.currency,
        issueDate: current.issueDate,
        dueDate: current.dueDate,
        notes: current.notes,
        paymentInstructions: current.paymentInstructions,
        authorizedSignatoryName: current.authorizedSignatoryName,
        authorizedSignatoryTitle: current.authorizedSignatoryTitle,
        status: current.status,
        subtotal: current.subtotal,
        discountAmount: current.discountAmount,
        taxAmount: current.taxAmount,
        totalAmount: current.totalAmount,
        amountPaid: current.amountPaid,
        balanceDue: current.balanceDue,
        paymentMethod: current.paymentMethod,
        paymentReference: current.paymentReference,
        paidAtUtc: current.paidAtUtc,
        lines: current.lines,
        isSynced: true,
      );
      await _persistLocally(updated);
    }
  }

  Future<void> _persistLocally(CustomerInvoice invoice) async {
    if (_cache == null) return;
    await _cache.save('invoice_${invoice.id}', invoice.toJson());
    final listDoc = await _cache.load(_cacheKey);
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
    await _cache.save(_cacheKey, {
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
    final listDoc = await _cache.load(_cacheKey);
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
      final cached = await _cache.load(_cacheKey);
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
