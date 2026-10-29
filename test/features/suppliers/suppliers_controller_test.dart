import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/features/suppliers/application/suppliers_controller.dart';
import 'package:jolinx_app/features/suppliers/data/supplier_repository.dart';
import 'package:jolinx_app/app/providers.dart';

class FakeSupplierRepository implements SupplierRepository {
  List<Map<String, dynamic>> suppliers = [
    {'id': 's1', 'name': 'Acme Supplies'},
    {'id': 's2', 'name': 'Beta Co'},
  ];
  Object? listError;
  String? lastSearch;

  @override
  Future<PagedSuppliers> list({
    int page = 1,
    int pageSize = 20,
    String? search,
  }) async {
    if (listError != null) throw listError as Exception;
    lastSearch = search;
    return PagedSuppliers(items: suppliers, total: suppliers.length);
  }

  @override
  Future<Map<String, dynamic>> getById(String id) async {
    return suppliers.firstWhere((s) => s['id'] == id);
  }

  @override
  Future<Map<String, dynamic>> create(
    Map<String, dynamic> body, {
    String? id,
    bool remoteOnly = false,
  }) async {
    final newSupplier = {...body, 'id': id ?? 's${suppliers.length + 1}'};
    suppliers = [...suppliers, newSupplier];
    return newSupplier;
  }

  @override
  Future<Map<String, dynamic>> update(
    String id,
    Map<String, dynamic> body, {
    bool remoteOnly = false,
  }) async {
    return {...body, 'id': id};
  }
}

void main() {
  group('SuppliersController', () {
    late FakeSupplierRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = FakeSupplierRepository();
      container = ProviderContainer(overrides: [
        supplierRepositoryProvider.overrideWithValue(repository),
      ]);
    });

    tearDown(() => container.dispose());

    SuppliersController controller() =>
        container.read(suppliersControllerProvider.notifier);

    test('initial state is Loading', () {
      expect(
        container.read(suppliersControllerProvider),
        isA<SuppliersLoading>(),
      );
    });

    test('load() transitions to Loaded with items', () async {
      await controller().load();

      final state = container.read(suppliersControllerProvider);
      expect(state, isA<SuppliersLoaded>());
      final loaded = state as SuppliersLoaded;
      expect(loaded.items, hasLength(2));
      expect(loaded.total, 2);
      expect(loaded.items[0]['name'], 'Acme Supplies');
    });

    test('load() with search passes search through', () async {
      await controller().load(search: 'Acme');

      final state =
          container.read(suppliersControllerProvider) as SuppliersLoaded;
      expect(state.search, 'Acme');
      expect(repository.lastSearch, 'Acme');
    });

    test('load() failure transitions to Failure', () async {
      repository.listError = ServerException('Server unavailable');

      await controller().load();

      final state = container.read(suppliersControllerProvider);
      expect(state, isA<SuppliersFailure>());
      expect((state as SuppliersFailure).message, 'Server unavailable');
    });

    test('create() calls repository then reloads', () async {
      await controller().load();
      expect(
        (container.read(suppliersControllerProvider) as SuppliersLoaded).total,
        2,
      );

      await controller().create({'name': 'New Supplier'});

      final state =
          container.read(suppliersControllerProvider) as SuppliersLoaded;
      expect(state.total, 3);
      expect(state.items.last['name'], 'New Supplier');
    });

    test('reset() returns to Loading', () async {
      await controller().load();
      expect(
          container.read(suppliersControllerProvider), isA<SuppliersLoaded>());

      controller().reset();

      final state = container.read(suppliersControllerProvider);
      expect(state, isA<SuppliersLoading>());
      expect((state as SuppliersLoading).search, '');
    });
  });
}
