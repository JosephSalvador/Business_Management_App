import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/features/customers/application/customers_controller.dart';
import 'package:jolinx_app/features/customers/data/customer_repository.dart';
import 'package:jolinx_app/app/providers.dart';

class FakeCustomerRepository implements CustomerRepository {
  List<Map<String, dynamic>> customers = [
    {'id': 'c1', 'name': 'John Doe'},
    {'id': 'c2', 'name': 'Jane Smith'},
  ];
  Object? listError;
  String? lastSearch;

  @override
  Future<PagedCustomers> list({
    int page = 1,
    int pageSize = 20,
    String? search,
  }) async {
    if (listError != null) throw listError as Exception;
    lastSearch = search;
    return PagedCustomers(items: customers, total: customers.length);
  }

  @override
  Future<Map<String, dynamic>> getById(String id) async {
    return customers.firstWhere((c) => c['id'] == id);
  }

  @override
  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final newCustomer = {...body, 'id': 'c${customers.length + 1}'};
    customers = [...customers, newCustomer];
    return newCustomer;
  }

  @override
  Future<Map<String, dynamic>> update(
      String id, Map<String, dynamic> body) async {
    return {...body, 'id': id};
  }

  @override
  Future<Map<String, dynamic>?> getCredit(String customerId) async {
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> getOutstandingCredit() async {
    return [];
  }

  @override
  Future<Map<String, dynamic>> recordPayment(
      String customerId, double amount, String description) async {
    return {'customerId': customerId, 'amount': amount, 'balance': 0};
  }
}

void main() {
  group('CustomersController', () {
    late FakeCustomerRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = FakeCustomerRepository();
      container = ProviderContainer(overrides: [
        customerRepositoryProvider.overrideWithValue(repository),
      ]);
    });

    tearDown(() => container.dispose());

    CustomersController controller() =>
        container.read(customersControllerProvider.notifier);

    test('initial state is Loading', () {
      expect(
        container.read(customersControllerProvider),
        isA<CustomersLoading>(),
      );
    });

    test('load() transitions to Loaded with items', () async {
      await controller().load();

      final state = container.read(customersControllerProvider);
      expect(state, isA<CustomersLoaded>());
      final loaded = state as CustomersLoaded;
      expect(loaded.items, hasLength(2));
      expect(loaded.total, 2);
      expect(loaded.items[0]['name'], 'John Doe');
    });

    test('load() with search passes search through', () async {
      await controller().load(search: 'John');

      final state =
          container.read(customersControllerProvider) as CustomersLoaded;
      expect(state.search, 'John');
      expect(repository.lastSearch, 'John');
    });

    test('load() failure transitions to Failure', () async {
      repository.listError = ServerException('Server down');

      await controller().load();

      final state = container.read(customersControllerProvider);
      expect(state, isA<CustomersFailure>());
      expect((state as CustomersFailure).message, 'Server down');
    });

    test('create() calls repository then reloads', () async {
      await controller().load();
      expect(
        (container.read(customersControllerProvider) as CustomersLoaded).total,
        2,
      );

      await controller().create({'name': 'New Customer'});

      final state =
          container.read(customersControllerProvider) as CustomersLoaded;
      expect(state.total, 3);
      expect(state.items.last['name'], 'New Customer');
    });

    test('reset() returns to Loading', () async {
      await controller().load();
      expect(
          container.read(customersControllerProvider), isA<CustomersLoaded>());

      controller().reset();

      final state = container.read(customersControllerProvider);
      expect(state, isA<CustomersLoading>());
      expect((state as CustomersLoading).search, '');
    });
  });
}
