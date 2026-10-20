import 'dart:convert';

import 'package:drift/drift.dart';

import '../../features/receipts/domain/receipt_preview.dart';
import 'local_database.dart';

/// Data Access Object for locally stored receipt snapshots.
/// Enables 100% offline receipt preview, reprint, and sharing.
class LocalReceiptDao {
  LocalReceiptDao(this._db);

  final LocalDatabase _db;

  /// Saves or updates the rendered receipt snapshot in local SQLite.
  Future<void> saveReceipt({
    required String saleId,
    required String tenantId,
    required String receiptNumber,
    required ReceiptPreview receipt,
    String? receiptText,
  }) async {
    await _db.into(_db.localReceipts).insertOnConflictUpdate(
          LocalReceiptsCompanion(
            saleId: Value(saleId),
            tenantId: Value(tenantId),
            receiptNumber: Value(receiptNumber),
            receiptDataJson: Value(jsonEncode(receipt.toJson())),
            receiptText: Value(receiptText),
            issuedAt: Value(receipt.saleDate),
            printCount: Value(receipt.printCount),
          ),
        );
  }

  /// Retrieves a saved receipt snapshot by [saleId] or [receiptNumber].
  Future<ReceiptPreview?> getReceipt(String identifier) async {
    final row = await (_db.select(_db.localReceipts)
          ..where((t) =>
              t.saleId.equals(identifier) | t.receiptNumber.equals(identifier)))
        .getSingleOrNull();
    if (row == null) return null;

    try {
      final decoded = jsonDecode(row.receiptDataJson) as Map<String, dynamic>;
      final receipt = ReceiptPreview.fromJson(decoded);
      // Ensure the latest printCount is reflected
      if (receipt.printCount != row.printCount) {
        return ReceiptPreview(
          saleId: receipt.saleId,
          saleNumber: row.receiptNumber.isNotEmpty ? row.receiptNumber : receipt.saleNumber,
          saleDate: receipt.saleDate,
          isVoided: receipt.isVoided,
          hasMetadata: receipt.hasMetadata,
          isReprint: row.printCount > 0,
          printCount: row.printCount,
          businessName: receipt.businessName,
          tin: receipt.tin,
          address: receipt.address,
          phone: receipt.phone,
          email: receipt.email,
          branchName: receipt.branchName,
          cashierName: receipt.cashierName,
          customerName: receipt.customerName,
          currency: receipt.currency,
          layoutId: receipt.layoutId,
          fiscalHash: receipt.fiscalHash,
          qrPayload: receipt.qrPayload,
          lines: receipt.lines,
          payments: receipt.payments,
          subtotal: receipt.subtotal,
          taxAmount: receipt.taxAmount,
          discountAmount: receipt.discountAmount,
          totalAmount: receipt.totalAmount,
          amountPaid: receipt.amountPaid,
          change: receipt.change,
        );
      }
      return receipt;
    } catch (_) {
      return null;
    }
  }

  /// Returns the pre-rendered monospace thermal text if available.
  Future<String?> getReceiptText(String saleId) async {
    final row = await (_db.select(_db.localReceipts)
          ..where((t) => t.saleId.equals(saleId)))
        .getSingleOrNull();
    return row?.receiptText;
  }

  /// Atomically increments the print count for a locally stored receipt.
  Future<void> incrementPrintCount(String saleId) async {
    final row = await (_db.select(_db.localReceipts)
          ..where((t) => t.saleId.equals(saleId)))
        .getSingleOrNull();
    if (row != null) {
      final nextCount = row.printCount + 1;
      await (_db.update(_db.localReceipts)
            ..where((t) => t.saleId.equals(saleId)))
          .write(
        LocalReceiptsCompanion(
          printCount: Value(nextCount),
        ),
      );
    }
  }

  /// Updates receipt number once the server confirms the sale during sync.
  Future<void> updateServerNumber({
    required String saleId,
    required String serverNumber,
  }) async {
    final row = await (_db.select(_db.localReceipts)
          ..where((t) => t.saleId.equals(saleId)))
        .getSingleOrNull();
    if (row != null) {
      try {
        final decoded = jsonDecode(row.receiptDataJson) as Map<String, dynamic>;
        decoded['saleNumber'] = serverNumber;
        await (_db.update(_db.localReceipts)
              ..where((t) => t.saleId.equals(saleId)))
            .write(
          LocalReceiptsCompanion(
            receiptNumber: Value(serverNumber),
            receiptDataJson: Value(jsonEncode(decoded)),
          ),
        );
      } catch (_) {}
    }
  }
}
