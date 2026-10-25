import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/features/purchases/application/purchases_controller.dart';
import 'package:jolinx_app/features/purchases/data/purchase_providers.dart';
import 'package:jolinx_app/features/purchases/data/purchase_repository.dart';

class FakePurchaseRepository implements PurchaseRepository {
  PagedPurchases? pageToReturn;
  Object? loadError;
  int listCallCount = 0;
  int createCallCount = 0;
  int submitCallCount = 0;
  int cancelCallCount = 0;
  String? lastSearch;
  Map<String, dynamic>? lastCreateBody;
  String? lastSubmitId;
  String? lastCancelId;
  String? lastUpdateId;
  String? lastReceiveId;

  @override
  Future<PagedPurchases> list({
    int page = 1,
    int pageSize = 20,
    String? search,
  }) async {
    listCallCount++;
    lastSearch = search;
    if (loadError != null) throw loadError!;
    return pageToReturn ?? PagedPurchases(items: const [], total: 0);
  }

  @override
  Future<void> create(
    Map<String, dynamic> body, {
    bool remoteOnly = false,
  }) async {
    createCallCount++;
    lastCreateBody = body;
  }

  @override
  Future<void> submit(String id) async {
    submitCallCount++;
    lastSubmitId = id;
  }

  @override
  Future<void> cancel(String id) async {
    cancelCallCount++;
    lastCancelId = id;
  }

  @override
  Future<void> update(String id, Map<String, dynamic> body) async {
    lastUpdateId = id;
  }

  @override
  Future<void> receive(String id) async {
    lastReceiveId = id;
  }

  @override
  Future<Map<String, dynamic>> getById(String id) async => {};

  @override
  Future<PagedSuppliers> suppliers({int page = 1, int pageSize = 100}) async =>
      PagedSuppliers(items: const [], total: 0);

  @override
  Future<List<Map<String, dynamic>>> warehouses() async => [];
}

void main() {
  late FakePurchaseRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = FakePurchaseRepository();
    container = ProviderContainer(overrides: [
      purchaseRepositoryProvider.overrideWithValue(fakeRepo),
    ]);
    addTearDown(container.dispose);
  });

  PurchasesController controller() =>
      container.read(purchasesControllerProvider.notifier);

  group('PurchasesController', () {
    test('initial state is Loading', () {
      expect(
        container.read(purchasesControllerProvider),
        isA<PurchasesLoading>(),
      );
    });

    test('load() transitions to Loaded', () async {
      fakeRepo.pageToReturn = PagedPurchases(
        items: [
          {'id': 'po1', 'number': 'PO-001'},
          {'id': 'po2', 'number': 'PO-002'},
        ],
        total: 2,
      );

      await controller().load();

      final state = controller().state as PurchasesLoaded;
      expect(state.items.length, 2);
      expect(state.total, 2);
      expect(fakeRepo.listCallCount, 1);
    });

    test('load() with search passes search', () async {
      fakeRepo.pageToReturn = PagedPurchases(items: [
        {'id': 'po1'}
      ], total: 1);

      await controller().load(search: 'mchele');

      expect(fakeRepo.lastSearch, 'mchele');
      final state = controller().state as PurchasesLoaded;
      expect(state.search, 'mchele');
    });

    test('load() failure transitions to Failure', () async {
      fakeRepo.loadError = ServerException('Timeout');

      await controller().load();

      final state = controller().state;
      expect(state, isA<PurchasesFailure>());
      expect((state as PurchasesFailure).message, 'Timeout');
    });

    test('create() calls repository then reloads', () async {
      fakeRepo.pageToReturn = PagedPurchases(
        items: [
          {'id': 'po1'}
        ],
        total: 1,
      );

      final body = {'supplierId': 's1', 'warehouseId': 'w1'};
      await controller().create(body);

      expect(fakeRepo.createCallCount, 1);
      expect(fakeRepo.lastCreateBody, body);
      expect(fakeRepo.listCallCount, 1);
      final state = controller().state as PurchasesLoaded;
      expect(state.items.first['id'], 'po1');
    });

    test('submit() calls repository then reloads', () async {
      fakeRepo.pageToReturn = PagedPurchases(items: [
        {'id': 'po1'}
      ], total: 1);

      await controller().submit('po1');

      expect(fakeRepo.submitCallCount, 1);
      expect(fakeRepo.lastSubmitId, 'po1');
      expect(fakeRepo.listCallCount, 1);
    });

    test('cancel() calls repository then reloads', () async {
      fakeRepo.pageToReturn = PagedPurchases(items: [
        {'id': 'po1'}
      ], total: 1);

      await controller().cancel('po2');

      expect(fakeRepo.cancelCallCount, 1);
      expect(fakeRepo.lastCancelId, 'po2');
      expect(fakeRepo.listCallCount, 1);
    });

    test('reset() returns to Loading', () async {
      fakeRepo.pageToReturn = PagedPurchases(items: [
        {'id': 'po1'}
      ], total: 1);
      await controller().load();
      expect(controller().state, isA<PurchasesLoaded>());

      controller().reset();

      expect(controller().state, isA<PurchasesLoading>());
    });
  });
}
