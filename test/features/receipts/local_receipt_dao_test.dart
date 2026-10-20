import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/config/app_config.dart';
import 'package:jolinx_app/core/network/api_client.dart';
import 'package:jolinx_app/core/storage/local_database.dart';
import 'package:jolinx_app/core/storage/local_receipt_dao.dart';
import 'package:jolinx_app/core/storage/receipt_cache.dart';
import 'package:jolinx_app/features/receipts/data/receipt_repository.dart';
import 'package:jolinx_app/features/receipts/domain/receipt_preview.dart';
import '../../support/fakes.dart';

ApiClient _clientWith(ScriptedAdapter adapter) => ApiClient(
      config: AppConfig.forTest(
        apiBaseUrl: Uri.parse('https://api.test.local'),
        environment: AppEnvironment.dev,
      ),
      tokenStore: InMemoryTokenStore(),
      refresher: (_) async => TokenPair(
        accessToken: 'a',
        refreshToken: 'r',
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 15)),
      ),
      dio: Dio(BaseOptions(baseUrl: 'https://api.test.local'))
        ..httpClientAdapter = adapter,
    );

ReceiptPreview _sampleReceipt({
  String saleId = 'sale-1',
  String saleNumber = 'S-2026-000001',
  int printCount = 0,
}) {
  return ReceiptPreview(
    saleId: saleId,
    saleNumber: saleNumber,
    saleDate: DateTime.utc(2026, 10, 20, 10, 0),
    subtotal: 10000,
    taxAmount: 1800,
    totalAmount: 11800,
    discountAmount: 0,
    amountPaid: 11800,
    change: 0,
    printCount: printCount,
    isReprint: printCount > 0,
    isVoided: false,
    hasMetadata: true,
    businessName: 'Jolinx Hardware',
    tin: '123-456-789',
    address: 'Kariakoo, Dar es Salaam',
    phone: '+255700000000',
    email: 'info@jolinx.co.tz',
    branchName: 'Main Store',
    cashierName: 'John',
    customerName: 'Amani',
    currency: 'TZS',
    qrPayload: 'Jolinx Hardware - $saleNumber',
    lines: const [
      ReceiptLine(
        productName: 'Cement 50kg',
        quantity: 1,
        unitPrice: 10000,
        discountAmount: 0,
        taxCode: 'A',
        taxAmount: 1800,
        lineTotal: 11800,
      ),
    ],
    payments: const [
      ReceiptPayment(
        method: 'Cash',
        amount: 11800,
        reference: null,
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalDatabase db;
  late LocalReceiptDao dao;
  late Directory tempDir;

  setUp(() {
    db = LocalDatabase(NativeDatabase.memory());
    dao = LocalReceiptDao(db);
    tempDir = Directory.systemTemp.createTempSync('receipt_test_');
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('LocalReceiptDao', () {
    test('saveReceipt stores receipt in SQLite and getReceipt recovers it', () async {
      final receipt = _sampleReceipt();
      await dao.saveReceipt(
        saleId: receipt.saleId,
        tenantId: 'tenant-1',
        receiptNumber: receipt.saleNumber,
        receipt: receipt,
        receiptText: '=== JOLINX HARDWARE ===\nTotal: 11,800',
      );

      final retrieved = await dao.getReceipt('sale-1');
      expect(retrieved, isNotNull);
      expect(retrieved!.saleId, 'sale-1');
      expect(retrieved.saleNumber, 'S-2026-000001');
      expect(retrieved.businessName, 'Jolinx Hardware');
      expect(retrieved.totalAmount, 11800);
      expect(retrieved.lines.first.productName, 'Cement 50kg');

      final text = await dao.getReceiptText('sale-1');
      expect(text, '=== JOLINX HARDWARE ===\nTotal: 11,800');
    });

    test('getReceipt by receiptNumber recovers receipt when saleId differs', () async {
      final receipt = _sampleReceipt(saleId: 'client-guid-1', saleNumber: 'S-2026-000099');
      await dao.saveReceipt(
        saleId: receipt.saleId,
        tenantId: 'tenant-1',
        receiptNumber: receipt.saleNumber,
        receipt: receipt,
      );

      final byNumber = await dao.getReceipt('S-2026-000099');
      expect(byNumber, isNotNull);
      expect(byNumber!.saleId, 'client-guid-1');
      expect(byNumber.saleNumber, 'S-2026-000099');
    });

    test('incrementPrintCount increments count and flags reprint', () async {
      final receipt = _sampleReceipt();
      await dao.saveReceipt(
        saleId: receipt.saleId,
        tenantId: 'tenant-1',
        receiptNumber: receipt.saleNumber,
        receipt: receipt,
      );

      await dao.incrementPrintCount('sale-1');
      final updated = await dao.getReceipt('sale-1');
      expect(updated, isNotNull);
      expect(updated!.printCount, 1);
      expect(updated.isReprint, isTrue);

      await dao.incrementPrintCount('sale-1');
      final updatedTwice = await dao.getReceipt('sale-1');
      expect(updatedTwice!.printCount, 2);
    });

    test('updateServerNumber updates provisional receipt with server number', () async {
      final provisional = _sampleReceipt(
        saleId: 'provisional-uuid-1',
        saleNumber: 'PROV-1',
      );
      await dao.saveReceipt(
        saleId: provisional.saleId,
        tenantId: 'tenant-1',
        receiptNumber: provisional.saleNumber,
        receipt: provisional,
      );

      await dao.updateServerNumber(
        saleId: 'provisional-uuid-1',
        serverNumber: 'S-2026-000555',
      );

      final byOldId = await dao.getReceipt('provisional-uuid-1');
      expect(byOldId, isNotNull);
      expect(byOldId!.saleNumber, 'S-2026-000555');

      final byNewNumber = await dao.getReceipt('S-2026-000555');
      expect(byNewNumber, isNotNull);
      expect(byNewNumber!.saleId, 'provisional-uuid-1');
    });
  });

  group('ReceiptRepository offline integration', () {
    test('getPreview serves from local SQLite first without hitting network', () async {
      final adapter = ScriptedAdapter(const [
        ScriptedResponse(200, '{}'),
      ]);
      final client = _clientWith(adapter);
      final cache = ReceiptCache(cacheDir: tempDir);
      final repository = ReceiptRepository(client, cache, localReceiptDao: dao);

      // Seed SQLite
      final receipt = _sampleReceipt();
      await dao.saveReceipt(
        saleId: receipt.saleId,
        tenantId: 'tenant-1',
        receiptNumber: receipt.saleNumber,
        receipt: receipt,
      );

      final result = await repository.getPreview('sale-1');
      expect(result.saleNumber, 'S-2026-000001');
      // Zero HTTP network calls made!
      expect(adapter.requests, isEmpty);
    });

    test('getPreview fetches from API on local miss and saves to SQLite for future offline use', () async {
      final remoteReceipt = _sampleReceipt(saleId: 'remote-1', saleNumber: 'S-2026-REMOTE');
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, jsonEncode(remoteReceipt.toJson())),
      ]);
      final client = _clientWith(adapter);
      final cache = ReceiptCache(cacheDir: tempDir);
      final repository = ReceiptRepository(client, cache, localReceiptDao: dao);

      // First call hits network
      final result = await repository.getPreview('remote-1');
      expect(result.saleNumber, 'S-2026-REMOTE');
      expect(adapter.requests, hasLength(1));

      // Now verify it was persisted in SQLite
      final savedInDb = await dao.getReceipt('remote-1');
      expect(savedInDb, isNotNull);
      expect(savedInDb!.saleNumber, 'S-2026-REMOTE');

      // Second call serves from SQLite with no extra network calls
      final secondResult = await repository.getPreview('remote-1');
      expect(secondResult.saleNumber, 'S-2026-REMOTE');
      expect(adapter.requests, hasLength(1));
    });
  });
}
