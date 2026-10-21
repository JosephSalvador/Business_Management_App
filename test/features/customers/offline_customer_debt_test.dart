import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/storage/local_database.dart';
import 'package:jolinx_app/core/storage/local_receipt_dao.dart';
import 'package:jolinx_app/core/storage/offline_cache_dao.dart';
import 'package:jolinx_app/core/storage/sync_queue_dao.dart';
import 'package:jolinx_app/features/customers/data/offline_customer_debt_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalDatabase db;
  late SyncQueueDao queue;
  late OfflineCacheDao cache;
  late LocalReceiptDao receipts;
  late OfflineCustomerDebtService service;

  setUp(() {
    db = LocalDatabase(NativeDatabase.memory());
    queue = SyncQueueDao(db);
    cache = OfflineCacheDao(db);
    receipts = LocalReceiptDao(db);
    service = OfflineCustomerDebtService(
      queue: queue,
      cache: cache,
      receipts: receipts,
      tenantIdOf: () async => 'tenant-1',
      branchIdOf: () async => 'branch-1',
      deviceIdOf: () async => 'device-1',
      userIdOf: () async => 'user-1',
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('recordOfflinePayment queues operation and saves offline debt receipt',
      () async {
    final payload = await service.recordOfflinePayment(
      customerId: 'cust-123',
      customerName: 'Juma Mussa',
      amount: 45000.0,
      description: 'Malipo ya sukari',
    );

    expect(payload['paymentId'], isNotNull);
    expect(payload['receiptNumber'], startsWith('RCP-PAY-'));

    // Check sync queue
    final ops = await queue.listByOperationType('customer.debt_payment');
    expect(ops, hasLength(1));
    expect(ops.single.aggregateId, 'cust-123');

    // Check offline receipt
    final receipt = await receipts.getReceipt(payload['paymentId'] as String);
    expect(receipt, isNotNull);
    expect(receipt!.customerName, 'Juma Mussa');
    expect(receipt.totalAmount, 45000.0);
  });

  test('getPendingDebtDeduction returns sum for specific customer', () async {
    await service.recordOfflinePayment(
      customerId: 'cust-1',
      customerName: 'Customer 1',
      amount: 20000.0,
      description: 'Part 1',
    );

    await service.recordOfflinePayment(
      customerId: 'cust-1',
      customerName: 'Customer 1',
      amount: 15000.0,
      description: 'Part 2',
    );

    await service.recordOfflinePayment(
      customerId: 'cust-2',
      customerName: 'Customer 2',
      amount: 50000.0,
      description: 'Other customer',
    );

    final deduction1 = await service.getPendingDebtDeduction('cust-1');
    expect(deduction1, 35000.0);

    final deduction2 = await service.getPendingDebtDeduction('cust-2');
    expect(deduction2, 50000.0);
  });

  test('getTodayCashDebtPaymentsTotal calculates today cash collections',
      () async {
    final today = DateTime.now();
    await service.recordOfflinePayment(
      customerId: 'cust-1',
      customerName: 'Customer 1',
      amount: 30000.0,
      description: 'Pesa Taslimu',
      paymentMethod: 'Pesa Taslimu',
    );

    await service.recordOfflinePayment(
      customerId: 'cust-2',
      customerName: 'Customer 2',
      amount: 10000.0,
      description: 'M-Pesa Lipa Namba',
      paymentMethod: 'M-Pesa',
    );

    final cashTotal = await service.getTodayCashDebtPaymentsTotal(today: today);
    expect(cashTotal, 30000.0);
  });
}
