import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/storage/local_database.dart';
import 'package:jolinx_app/core/storage/offline_cache_dao.dart';
import 'package:jolinx_app/core/storage/sync_queue_dao.dart';
import 'package:jolinx_app/features/finance/data/offline_expense_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalDatabase db;
  late SyncQueueDao queue;
  late OfflineCacheDao cache;
  late OfflineExpenseService service;

  setUp(() {
    db = LocalDatabase(NativeDatabase.memory());
    queue = SyncQueueDao(db);
    cache = OfflineCacheDao(db);
    service = OfflineExpenseService(
      queue: queue,
      cache: cache,
      tenantIdOf: () async => 'tenant-1',
      branchIdOf: () async => 'branch-1',
      deviceIdOf: () async => 'device-1',
      userIdOf: () async => 'user-1',
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('recordOffline stages expense in SyncQueue with pendingLocally flag',
      () async {
    final expense = await service.recordOffline({
      'description': 'Luku ya dukani',
      'amount': 25000.0,
      'paymentMethod': 'Pesa Taslimu',
      'expenseDate': DateTime.now().toUtc().toIso8601String(),
    });

    expect(expense['pendingLocally'], isTrue);
    expect(expense['id'], isNotNull);

    final pending = await service.listPendingExpenses();
    expect(pending, hasLength(1));
    expect(pending.single['description'], 'Luku ya dukani');
    expect(pending.single['amount'], 25000.0);
  });

  test('getTodayCashExpensesTotal calculates only today cash expenses',
      () async {
    final today = DateTime.now();
    // Cash today
    await service.recordOffline({
      'description': 'Chakula cha mchana',
      'amount': 8000.0,
      'paymentMethod': 'Pesa Taslimu',
      'expenseDate': today.toUtc().toIso8601String(),
    });

    // M-Pesa today (electronic, not from physical till cash)
    await service.recordOffline({
      'description': 'Vocha internet',
      'amount': 15000.0,
      'paymentMethod': 'M-Pesa',
      'expenseDate': today.toUtc().toIso8601String(),
    });

    // Cash yesterday
    final yesterday = today.subtract(const Duration(days: 1));
    await service.recordOffline({
      'description': 'Maji ya jana',
      'amount': 5000.0,
      'paymentMethod': 'Pesa Taslimu',
      'expenseDate': yesterday.toUtc().toIso8601String(),
    });

    final cashTotal = await service.getTodayCashExpensesTotal(today: today);
    expect(cashTotal, 8000.0);
  });

  test('getCategoriesWithCache falls back to defaults when offline', () async {
    final categories = await service.getCategoriesWithCache(() async {
      throw Exception('Network down');
    });

    expect(categories, isNotEmpty);
    expect(
      categories.any((c) => c.name.contains('Matumizi ya Dukani')),
      isTrue,
    );
  });
}
