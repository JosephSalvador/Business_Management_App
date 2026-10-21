import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/storage/local_database.dart';
import 'package:jolinx_app/core/storage/offline_cache_dao.dart';
import 'package:jolinx_app/features/sales/data/offline_parked_cart_service.dart';
import 'package:jolinx_app/features/sales/domain/sale.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalDatabase db;
  late OfflineCacheDao cache;
  late OfflineParkedCartService service;

  setUp(() {
    db = LocalDatabase(NativeDatabase.memory());
    cache = OfflineCacheDao(db);
    service = OfflineParkedCartService(cache: cache);
  });

  tearDown(() async => db.close());

  test('parkCart stores draft lines and restores them accurately', () async {
    final lines = [
      CartLine(productId: 'p-1', name: 'Sukari 1kg', unitPrice: 3200, quantity: 2),
      CartLine(productId: 'p-2', name: 'Chai Bora', unitPrice: 1500, quantity: 1),
    ];

    final parked = await service.parkCart(
      lines: lines,
      customerName: 'Mama Neema',
    );

    expect(parked.label, 'Mama Neema');
    expect(parked.total, 7900.0);
    expect(parked.itemCount, 3);

    final all = await service.listParkedCarts();
    expect(all, hasLength(1));
    expect(all.first.id, parked.id);

    // Restore cart
    final restored = await service.restoreCart(parked.id);
    expect(restored, isNotNull);
    expect(restored!.lines, hasLength(2));
    expect(restored.lines.first.name, 'Sukari 1kg');

    // After restore, parked list is empty
    final remaining = await service.listParkedCarts();
    expect(remaining, isEmpty);
  });

  test('discardCart removes draft permanently', () async {
    final parked = await service.parkCart(
      lines: [CartLine(productId: 'p-1', name: 'Maji', unitPrice: 1000)],
    );

    expect(await service.listParkedCarts(), hasLength(1));

    await service.discardCart(parked.id);

    expect(await service.listParkedCarts(), isEmpty);
  });
}
