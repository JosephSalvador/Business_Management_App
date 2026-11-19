import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/core_providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_routes.dart';
import '../../../core/network/connectivity_monitor.dart';
import '../../sales/data/sales_providers.dart' show connectivityMonitorProvider;
import '../data/delivery_note_repository.dart';
import '../data/invoice_providers.dart';
import '../data/invoice_repository.dart';
import '../domain/delivery_note.dart';
import '../domain/invoice.dart';
import 'invoices_controller.dart';

final syncQueueProcessorProvider = Provider<SyncQueueProcessor>((ref) {
  final processor = SyncQueueProcessor(
    invoiceRepository: ref.watch(invoiceRepositoryProvider),
    deliveryNoteRepository: ref.watch(deliveryNoteRepositoryProvider),
    apiClient: ref.watch(apiClientProvider),
    ref: ref,
  );
  ref.onDispose(() => processor.dispose());
  return processor;
});

/// Autonomous background worker listening to ConnectivityMonitor.
/// The moment connection transitions to Online, queries local un-synced
/// rows (isSynced == false), bundles & dispatches them to .NET cloud API,
/// and atomically marks them isSynced = true upon HTTP 200/201.
class SyncQueueProcessor {
  SyncQueueProcessor({
    required InvoiceRepository invoiceRepository,
    required DeliveryNoteRepository deliveryNoteRepository,
    required ApiClient apiClient,
    required Ref ref,
  })  : _invoiceRepository = invoiceRepository,
        _deliveryNoteRepository = deliveryNoteRepository,
        _apiClient = apiClient,
        _ref = ref {
    _initListener();
  }

  final InvoiceRepository _invoiceRepository;
  final DeliveryNoteRepository _deliveryNoteRepository;
  final ApiClient _apiClient;
  final Ref _ref;

  ProviderSubscription<ConnectionQuality>? _connectivitySubscription;
  Timer? _heartbeatTimer;
  bool _isSyncing = false;

  void _initListener() {
    _connectivitySubscription = _ref.listen<ConnectionQuality>(
      connectivityMonitorProvider,
      (previous, next) {
        if (next == ConnectionQuality.online &&
            previous != ConnectionQuality.online) {
          triggerSync();
        }
      },
    );

    // 45-second heartbeat sweep
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => triggerSync(),
    );
  }

  Future<void> triggerSync() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final unSyncedInvoices = await _invoiceRepository.listUnsynced();
      for (final invoice in unSyncedInvoices) {
        await _syncSingleInvoice(invoice);
      }

      final unSyncedDeliveryNotes =
          await _deliveryNoteRepository.listUnsynced();
      for (final note in unSyncedDeliveryNotes) {
        await _syncSingleDeliveryNote(note);
      }

      if (unSyncedInvoices.isNotEmpty) {
        try {
          _ref.read(invoicesControllerProvider.notifier).refresh();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[SyncQueueProcessor] Sync sweep encountered: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncSingleInvoice(CustomerInvoice invoice) async {
    try {
      final payload = <String, dynamic>{
        'id': invoice.id,
        'lines': [for (final line in invoice.lines) line.toJson()],
        if (invoice.customerId != null && invoice.customerId!.isNotEmpty)
          'customerId': invoice.customerId,
        if (invoice.customerName != null && invoice.customerName!.isNotEmpty)
          'customerName': invoice.customerName,
        if (invoice.customerAttention != null)
          'customerAttention': invoice.customerAttention,
        if (invoice.customerPhone != null) 'customerPhone': invoice.customerPhone,
        if (invoice.customerEmail != null) 'customerEmail': invoice.customerEmail,
        if (invoice.customerAddress != null)
          'customerAddress': invoice.customerAddress,
        if (invoice.customerTin != null) 'customerTin': invoice.customerTin,
        'currency': invoice.currency,
        'documentTitle': invoice.documentTitle,
        if (invoice.referenceNumber != null)
          'referenceNumber': invoice.referenceNumber,
        if (invoice.paymentTerms != null)
          'paymentTerms': invoice.paymentTerms,
        'issueDate': invoice.issueDate.toUtc().toIso8601String(),
        if (invoice.dueDate != null)
          'dueDate': invoice.dueDate!.toUtc().toIso8601String(),
        'discountAmount': invoice.discountAmount,
        'initialAmountPaid': invoice.amountPaid,
        if (invoice.paymentMethod != null)
          'paymentMethod': invoice.paymentMethod,
        if (invoice.paymentReference != null)
          'paymentReference': invoice.paymentReference,
        if (invoice.paymentInstructions != null)
          'paymentInstructions': invoice.paymentInstructions,
        if (invoice.notes != null) 'notes': invoice.notes,
        if (invoice.authorizedSignatoryName != null)
          'authorizedSignatoryName': invoice.authorizedSignatoryName,
        if (invoice.authorizedSignatoryTitle != null)
          'authorizedSignatoryTitle': invoice.authorizedSignatoryTitle,
      };

      final response = await _apiClient.post<dynamic>(
        ApiRoutes.v1('/invoices'),
        body: payload,
        headers: {'Idempotency-Key': invoice.id},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        String? serverNumber;
        if (response.data is Map) {
          serverNumber = response.data['number']?.toString();
        }
        await _invoiceRepository.markSynced(invoice.id,
            serverNumber: serverNumber);
        debugPrint('[SyncQueueProcessor] Synced invoice: ${invoice.id}');
      }
    } catch (e) {
      debugPrint('[SyncQueueProcessor] Failed to sync invoice ${invoice.id}: $e');
    }
  }

  static bool _isValidGuid(String val) {
    final guidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return guidRegex.hasMatch(val.trim());
  }

  Future<void> _syncSingleDeliveryNote(DeliveryNote note) async {
    try {
      final payload = <String, dynamic>{
        'id': note.id,
        'customerName': note.customerName,
        'issueDate': note.issueDate.toUtc().toIso8601String(),
        if (note.invoiceId != null &&
            note.invoiceId!.isNotEmpty &&
            _isValidGuid(note.invoiceId!))
          'invoiceId': note.invoiceId,
        if (note.invoiceNumber != null && note.invoiceNumber!.isNotEmpty)
          'invoiceNumber': note.invoiceNumber,
        if (note.customerId != null &&
            note.customerId!.isNotEmpty &&
            _isValidGuid(note.customerId!))
          'customerId': note.customerId,
        if (note.customerPhone != null && note.customerPhone!.trim().isNotEmpty)
          'customerPhone': note.customerPhone!.trim(),
        if (note.customerAddress != null &&
            note.customerAddress!.trim().isNotEmpty)
          'customerAddress': note.customerAddress!.trim(),
        if (note.deliveryAddress != null &&
            note.deliveryAddress!.trim().isNotEmpty)
          'deliveryAddress': note.deliveryAddress!.trim(),
        if (note.carrierName != null && note.carrierName!.trim().isNotEmpty)
          'carrierName': note.carrierName!.trim(),
        if (note.trackingNumber != null &&
            note.trackingNumber!.trim().isNotEmpty)
          'trackingNumber': note.trackingNumber!.trim(),
        if (note.vehicleNumber != null && note.vehicleNumber!.trim().isNotEmpty)
          'vehicleNumber': note.vehicleNumber!.trim(),
        if (note.driverName != null && note.driverName!.trim().isNotEmpty)
          'driverName': note.driverName!.trim(),
        if (note.driverPhone != null && note.driverPhone!.trim().isNotEmpty)
          'driverPhone': note.driverPhone!.trim(),
        if (note.notes != null && note.notes!.trim().isNotEmpty)
          'notes': note.notes!.trim(),
        'items': [
          for (final item in note.items)
            {
              'description': item.productName,
              'productName': item.productName,
              if (item.productId != null &&
                  item.productId!.isNotEmpty &&
                  _isValidGuid(item.productId!))
                'productId': item.productId,
              if (item.sku != null && item.sku!.isNotEmpty) 'sku': item.sku,
              'unitOfMeasure':
                  item.unitOfMeasure.isNotEmpty ? item.unitOfMeasure : 'Pcs',
              'quantityOrdered': item.quantityOrdered,
              'quantityDelivered': item.quantityToDeliver,
              'quantityToDeliver': item.quantityToDeliver,
            }
        ],
      };

      final response = await _apiClient.post<dynamic>(
        ApiRoutes.v1('/delivery-notes'),
        body: payload,
        headers: {'Idempotency-Key': note.id},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        String? serverNumber;
        if (response.data is Map) {
          serverNumber = response.data['number']?.toString();
        }
        await _deliveryNoteRepository.markSynced(note.id,
            serverNumber: serverNumber);
        debugPrint('[SyncQueueProcessor] Synced delivery note: ${note.id}');
      }
    } catch (e) {
      debugPrint('[SyncQueueProcessor] Failed to sync delivery note ${note.id}: $e');
    }
  }

  void dispose() {
    _connectivitySubscription?.close();
    _heartbeatTimer?.cancel();
  }
}
