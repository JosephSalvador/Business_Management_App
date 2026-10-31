import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> _syncSingleDeliveryNote(DeliveryNote note) async {
    try {
      final payload = <String, dynamic>{
        'id': note.id,
        'customerName': note.customerName,
        'issueDate': note.issueDate.toUtc().toIso8601String(),
        if (note.invoiceId != null) 'invoiceId': note.invoiceId,
        if (note.customerId != null) 'customerId': note.customerId,
        if (note.customerPhone != null) 'customerPhone': note.customerPhone,
        if (note.customerAddress != null) 'customerAddress': note.customerAddress,
        if (note.deliveryAddress != null) 'deliveryAddress': note.deliveryAddress,
        if (note.carrierName != null) 'carrierName': note.carrierName,
        if (note.trackingNumber != null) 'trackingNumber': note.trackingNumber,
        if (note.vehicleNumber != null) 'vehicleNumber': note.vehicleNumber,
        if (note.driverName != null) 'driverName': note.driverName,
        if (note.driverPhone != null) 'driverPhone': note.driverPhone,
        if (note.notes != null) 'notes': note.notes,
        'items': [for (final item in note.items) item.toJson()],
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
