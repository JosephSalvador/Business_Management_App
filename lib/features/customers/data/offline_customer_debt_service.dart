import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../../../core/storage/local_receipt_dao.dart';
import '../../../core/storage/offline_cache_dao.dart';
import '../../../core/storage/sync_queue_dao.dart';
import '../../receipts/domain/receipt_preview.dart';

/// Handles offline customer debt payments ("Malipo ya Madeni"),
/// issues local debt receipts, and feeds cash collections into till balancing.
class OfflineCustomerDebtService {
  OfflineCustomerDebtService({
    required SyncQueueDao queue,
    required OfflineCacheDao cache,
    required LocalReceiptDao receipts,
    required Future<String?> Function() tenantIdOf,
    required Future<String?> Function() branchIdOf,
    required Future<String> Function() deviceIdOf,
    required Future<String?> Function() userIdOf,
    Uuid uuid = const Uuid(),
  })  : _queue = queue,
        _cache = cache,
        _receipts = receipts,
        _tenantIdOf = tenantIdOf,
        _branchIdOf = branchIdOf,
        _deviceIdOf = deviceIdOf,
        _userIdOf = userIdOf,
        _uuid = uuid;

  final SyncQueueDao _queue;
  final OfflineCacheDao _cache;
  final LocalReceiptDao _receipts;
  final Future<String?> Function() _tenantIdOf;
  final Future<String?> Function() _branchIdOf;
  final Future<String> Function() _deviceIdOf;
  final Future<String?> Function() _userIdOf;
  final Uuid _uuid;

  /// Records an offline debt payment and creates an offline payment receipt.
  Future<Map<String, dynamic>> recordOfflinePayment({
    required String customerId,
    required String customerName,
    required double amount,
    required String description,
    String paymentMethod = 'Pesa Taslimu',
  }) async {
    final paymentId = _uuid.v4();
    final tenantId = (await _tenantIdOf()) ?? 'unknown';
    final branchId = (await _branchIdOf()) ?? tenantId;
    final deviceId = await _deviceIdOf();
    final userId = await _userIdOf();
    final now = DateTime.now().toUtc();
    final receiptNumber =
        'RCP-PAY-${paymentId.substring(0, 8).toUpperCase()}';

    final payload = {
      'paymentId': paymentId,
      'customerId': customerId,
      'customerName': customerName,
      'amount': amount,
      'description': description,
      'paymentMethod': paymentMethod,
      'receiptNumber': receiptNumber,
      'collectedBy': userId,
      'createdAt': now.toIso8601String(),
    };

    // 1. Queue for sync
    await _queue.enqueue(
      operationId: paymentId,
      tenantId: tenantId,
      branchId: branchId,
      deviceId: deviceId,
      operationType: 'customer.debt_payment',
      aggregateType: 'customer',
      aggregateId: customerId,
      payload: jsonEncode(payload),
    );

    // 2. Cache latest payment for customer
    await _cache.save('last_debt_payment_$customerId', payload);

    // 3. Save offline receipt so the customer gets a receipt immediately
    final receiptPreview = ReceiptPreview(
      saleId: paymentId,
      saleNumber: receiptNumber,
      saleDate: now,
      isVoided: false,
      hasMetadata: true,
      isReprint: false,
      printCount: 0,
      businessName: 'STAKABADHI YA MALIPO YA DENI',
      customerName: customerName,
      currency: 'TZS',
      qrPayload: '',
      subtotal: amount,
      taxAmount: 0,
      discountAmount: 0,
      totalAmount: amount,
      amountPaid: amount,
      change: 0,
      lines: [
        ReceiptLine(
          productName: 'Malipo ya Deni - $description',
          quantity: 1,
          unitPrice: amount,
          discountAmount: 0,
          lineTotal: amount,
          taxCode: 'EX',
          taxAmount: 0,
        ),
      ],
      payments: [
        ReceiptPayment(
          method: paymentMethod,
          amount: amount,
        ),
      ],
    );

    await _receipts.saveReceipt(
      saleId: paymentId,
      tenantId: tenantId,
      receiptNumber: receiptNumber,
      receipt: receiptPreview,
    );

    return payload;
  }

  /// Returns total pending payments made for a given customer offline.
  Future<double> getPendingDebtDeduction(String customerId) async {
    final ops = await _queue.listByOperationType('customer.debt_payment');
    double deducted = 0;
    for (final op in ops) {
      if (op.aggregateId == customerId) {
        try {
          final decoded = jsonDecode(op.payload);
          deducted += (decoded['amount'] as num?)?.toDouble() ?? 0.0;
        } catch (_) {}
      }
    }
    return deducted;
  }

  /// Calculates total cash collected from customer debts today for till balancing.
  Future<double> getTodayCashDebtPaymentsTotal({DateTime? today}) async {
    final now = today ?? DateTime.now();
    final ops = await _queue.listByOperationType('customer.debt_payment');
    double total = 0;

    for (final op in ops) {
      try {
        final decoded = jsonDecode(op.payload);
        final method =
            (decoded['paymentMethod'] ?? '').toString().toLowerCase();
        final isCash = method.contains('taslimu') || method.contains('cash');
        if (!isCash) continue;

        final createdStr = decoded['createdAt'];
        if (createdStr != null) {
          final dt = DateTime.tryParse(createdStr.toString())?.toLocal();
          if (dt != null &&
              dt.year == now.year &&
              dt.month == now.month &&
              dt.day == now.day) {
            total += (decoded['amount'] as num?)?.toDouble() ?? 0.0;
          }
        }
      } catch (_) {}
    }

    return total;
  }
}
