import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/storage/local_database.dart';
import 'package:jolinx_app/core/storage/local_receipt_dao.dart';
import 'package:jolinx_app/core/storage/local_sales_dao.dart';
import 'package:jolinx_app/core/storage/offline_cache_dao.dart';
import 'package:jolinx_app/core/storage/sync_queue_dao.dart';
import 'package:jolinx_app/features/customers/data/offline_customer_debt_service.dart';
import 'package:jolinx_app/features/finance/data/offline_expense_service.dart';
import 'package:jolinx_app/features/sales/data/offline_shift_register_service.dart';
import 'package:jolinx_app/features/sales/domain/sale.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalDatabase db;
  late LocalSalesDao salesDao;
  late SyncQueueDao queue;
  late OfflineCacheDao cache;
  late LocalReceiptDao receipts;
  late OfflineExpenseService expenseService;
  late OfflineCustomerDebtService debtService;
  late OfflineShiftRegisterService shiftService;

  setUp(() {
    db = LocalDatabase(NativeDatabase.memory());
    salesDao = LocalSalesDao(db);
    queue = SyncQueueDao(db);
    cache = OfflineCacheDao(db);
    receipts = LocalReceiptDao(db);

    expenseService = OfflineExpenseService(
      queue: queue,
      cache: cache,
      tenantIdOf: () async => 'tenant-1',
      branchIdOf: () async => 'branch-1',
      deviceIdOf: () async => 'dev-1',
      userIdOf: () async => 'usr-1',
    );

    debtService = OfflineCustomerDebtService(
      queue: queue,
      cache: cache,
      receipts: receipts,
      tenantIdOf: () async => 'tenant-1',
      branchIdOf: () async => 'branch-1',
      deviceIdOf: () async => 'dev-1',
      userIdOf: () async => 'usr-1',
    );

    shiftService = OfflineShiftRegisterService(
      salesDao: salesDao,
      expenseService: expenseService,
      debtService: debtService,
      queue: queue,
      cache: cache,
      tenantIdOf: () async => 'tenant-1',
      branchIdOf: () async => 'branch-1',
      deviceIdOf: () async => 'dev-1',
      userIdOf: () async => 'usr-1',
    );
  });

  tearDown(() async => db.close());

  test('computeShiftSummary reconciles sales, expenses, and debt collections',
      () async {
    final now = DateTime.now();

    // 1. Cash sale: 30,000
    await salesDao.recordOfflineSale(
      tenantId: 'tenant-1',
      branchId: 'branch-1',
      deviceId: 'dev-1',
      userId: 'usr-1',
      paymentMethod: PaymentMethod.cash,
      subtotalEstimate: 30000,
      taxEstimate: 0,
      totalEstimate: 30000,
      effectiveAt: now,
      lines: [
        const OfflineSaleLineInput(
          productId: 'p-1',
          productName: 'Mchele',
          quantity: 10,
          unitPriceSnapshot: 3000,
        ),
      ],
    );

    // 2. Mobile money sale: 20,000
    await salesDao.recordOfflineSale(
      tenantId: 'tenant-1',
      branchId: 'branch-1',
      deviceId: 'dev-1',
      userId: 'usr-1',
      paymentMethod: PaymentMethod.mobileMoney,
      subtotalEstimate: 20000,
      taxEstimate: 0,
      totalEstimate: 20000,
      effectiveAt: now,
      lines: [
        const OfflineSaleLineInput(
          productId: 'p-2',
          productName: 'Mafuta',
          quantity: 2,
          unitPriceSnapshot: 10000,
        ),
      ],
    );

    // 3. Petty cash expense: 5,000 (Chakula)
    await expenseService.recordOffline({
      'description': 'Chakula cha mchana',
      'amount': 5000.0,
      'paymentMethod': 'Pesa Taslimu',
      'expenseDate': now.toUtc().toIso8601String(),
    });

    // 4. Debt collection in cash: 10,000
    await debtService.recordOfflinePayment(
      customerId: 'cust-1',
      customerName: 'Amina Ali',
      amount: 10000.0,
      description: 'Lipa deni la jana',
      paymentMethod: 'Pesa Taslimu',
    );

    // 5. Compute shift summary with opening cash 15,000 and counted cash 50,000
    // Expected cash = opening (15,000) + cashSales (30,000) + debtCash (10,000) - cashExpenses (5,000) = 50,000
    final summary = await shiftService.computeShiftSummary(
      date: now,
      openingCash: 15000,
      countedCash: 50000,
    );

    expect(summary.saleCount, 2);
    expect(summary.cashSales, 30000);
    expect(summary.electronicSales, 20000);
    expect(summary.totalSales, 50000);
    expect(summary.cashExpenses, 5000);
    expect(summary.debtCashCollected, 10000);
    expect(summary.expectedCash, 50000);
    expect(summary.variance, 0); // Exact match!
  });

  test('generateZReportText produces clean thermal output with Swahili headers',
      () async {
    final summary = ShiftSummary(
      date: DateTime.now(),
      saleCount: 5,
      cashSales: 150000,
      electronicSales: 50000,
      creditSales: 20000,
      totalSales: 220000,
      debtCashCollected: 15000,
      cashExpenses: 10000,
      openingCash: 20000,
      expectedCash: 175000,
      countedCash: 175000,
      variance: 0,
      closedAt: DateTime.now(),
    );

    final text = shiftService.generateZReportText(
      summary,
      businessName: 'DUKA LA NEEMA',
    );

    expect(text, contains('RIPOTI YA Z-HESABU'));
    expect(text, contains('DUKA LA NEEMA'));
    expect(text, contains('JUMLA YA MAUZO'));
    expect(text, contains('PESA INAYOTARAJIWA'));
    expect(text, contains('ZIADA (+)'));
  });

  test('saveShiftClose enqueues shift.close into SyncQueue', () async {
    final summary = ShiftSummary(
      date: DateTime.now(),
      saleCount: 1,
      cashSales: 10000,
      electronicSales: 0,
      creditSales: 0,
      totalSales: 10000,
      debtCashCollected: 0,
      cashExpenses: 0,
      openingCash: 0,
      expectedCash: 10000,
      countedCash: 10000,
      variance: 0,
    );

    await shiftService.saveShiftClose(summary);

    final ops = await queue.listByOperationType('shift.close');
    expect(ops, hasLength(1));
    expect(ops.single.operationType, 'shift.close');
  });
}
