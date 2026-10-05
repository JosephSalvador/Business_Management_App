import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jolinx_app/core/storage/local_database.dart';
import 'package:jolinx_app/core/storage/quick_sale_memory.dart';

void main() {
  late LocalDatabase db;
  late QuickSaleMemoryDao memory;

  const tenantA = 'tenant-1';
  const tenantB = 'tenant-2';

  setUp(() {
    db = LocalDatabase(NativeDatabase.memory());
    memory = QuickSaleMemoryDao(db);
  });

  tearDown(() async => db.close());

  test('starts empty and remembers the newest item first', () async {
    expect(await memory.recent(tenantA), isEmpty);

    await memory.remember(tenantA, 'Mchicha', 2000);
    await memory.remember(tenantA, 'Dagaa', 5000);

    final recent = await memory.recent(tenantA);
    expect(recent.map((e) => e.name), ['Dagaa', 'Mchicha']);
    expect(recent.first.price, 5000);
    expect(recent.first.count, 1);
  });

  test('re-remembering the same name bumps its count and price', () async {
    await memory.remember(tenantA, 'Mchicha', 2000);
    await memory.remember(tenantA, 'Mchicha', 2500);

    final recent = await memory.recent(tenantA);
    expect(recent, hasLength(1));
    expect(recent.single.name, 'Mchicha');
    expect(recent.single.price, 2500);
    expect(recent.single.count, 2);
  });

  test('cap keeps at most eight entries, dropping the oldest', () async {
    for (var i = 1; i <= 10; i++) {
      await memory.remember(tenantA, 'Bidhaa $i', i * 1000.0);
    }

    final recent = await memory.recent(tenantA);
    expect(recent, hasLength(8));
    expect(recent.first.name, 'Bidhaa 10');
    expect(recent.last.name, 'Bidhaa 3', reason: '1 and 2 were evicted');
  });

  test('memories are isolated per tenant', () async {
    await memory.remember(tenantA, 'Mchicha', 2000);

    expect(await memory.recent(tenantB), isEmpty);
  });

  test('matches names case-insensitively without merging distinct ones',
      () async {
    await memory.remember(tenantA, 'Mchicha', 2000);
    await memory.remember(tenantA, 'mchicha', 3000);

    expect(await memory.recent(tenantA), hasLength(1));
  });

  test('remembered quick-sale product id is empty until saved', () async {
    expect(await memory.productId(tenantA), isNull);
  });

  test('remembering the product id persists it per tenant', () async {
    await memory.rememberProductId(tenantA, 'p-123');
    await memory.rememberProductId(tenantB, 'p-456');

    expect(await memory.productId(tenantA), 'p-123');
    expect(await memory.productId(tenantB), 'p-456');
  });

  test('re-remembering the product id overwrites the previous one', () async {
    await memory.rememberProductId(tenantA, 'p-123');
    await memory.rememberProductId(tenantA, 'p-456');

    expect(await memory.productId(tenantA), 'p-456');
  });
}
