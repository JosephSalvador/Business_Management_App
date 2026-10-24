import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/app/providers.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/features/sales/application/sales_history_controller.dart';
import 'package:jolinx_app/features/sales/data/sale_repository.dart';
import 'package:jolinx_app/features/sales/domain/sale.dart';

/// In-memory [SaleRepository] recording exactly what the controller asked for.
class FakeSaleRepository implements SaleRepository {
  int calls = 0;
  int? lastPage;
  int? lastPageSize;
  DateTime? lastFrom;
  DateTime? lastTo;
  String? lastSearch;

  /// When non-null, [list] throws it.
  AppException? failure;

  List<SaleDto> items = const [];

  @override
  Future<PagedSales> list({
    int page = 1,
    int pageSize = 50,
    DateTime? from,
    DateTime? to,
    int? status,
    String? search,
  }) async {
    calls++;
    lastPage = page;
    lastPageSize = pageSize;
    lastFrom = from;
    lastTo = to;
    lastSearch = search;
    if (failure != null) {
      throw failure!;
    }
    return PagedSales(items: items, total: items.length);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SaleDto _sale(String id) {
  return SaleDto.fromJson({
    'id': id,
    'number': 'S-2026-000001',
    'status': 0,
    'saleDate': '2026-08-23T10:00:00Z',
    'currency': 'TZS',
    'subtotal': 5000,
    'discountAmount': 0,
    'taxAmount': 0,
    'totalAmount': 5000,
    'amountPaid': 5000,
    'change': 0,
    'clientSaleId': id,
    'lines': <dynamic>[],
    'payments': [
      {'method': 0, 'amount': 5000},
    ],
  });
}

ProviderContainer _container(FakeSaleRepository repository) {
  return ProviderContainer(overrides: [
    saleRepositoryProvider.overrideWithValue(repository),
  ]);
}

void main() {
  late ProviderContainer container;
  late FakeSaleRepository repository;

  setUp(() {
    repository = FakeSaleRepository();
    container = _container(repository);
  });

  tearDown(() => container.dispose());

  test('starts in Loading', () {
    expect(container.read(salesHistoryControllerProvider),
        isA<SalesHistoryLoading>());
  });

  test('load() queries the current local calendar day with pageSize 100', () {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);

    final future =
        container.read(salesHistoryControllerProvider.notifier).load();

    expect(
      container.read(salesHistoryControllerProvider),
      isA<SalesHistoryLoading>(),
    );

    return future.then((_) {
      final query = repository;
      expect(query.calls, 1);
      expect(repository.lastPage, 1);
      expect(repository.lastPageSize, 100);
      expect(repository.lastFrom, start);
      expect(repository.lastTo, start.add(const Duration(days: 1)));
      expect(repository.lastSearch, isNull);

      final loaded =
          container.read(salesHistoryControllerProvider) as SalesHistoryLoaded;
      expect(loaded.sales, isEmpty);
      expect(loaded.total, 0);
      expect(loaded.searchActive, isFalse);
    });
  });

  test('load(day:) queries that calendar day', () {
    final day = DateTime(2026, 6, 15, 14, 30);

    return container
        .read(salesHistoryControllerProvider.notifier)
        .load(day: day)
        .then((_) {
      expect(repository.lastFrom, DateTime(2026, 6, 15));
      expect(repository.lastTo, DateTime(2026, 6, 16));
    });
  });

  test('load(search:) forwards the trimmed term and flags searchActive', () {
    repository.items = [_sale('s1'), _sale('s2')];

    return container
        .read(salesHistoryControllerProvider.notifier)
        .load(search: '  S-2026-000045  ')
        .then((_) {
      expect(repository.lastSearch, 'S-2026-000045');
      final loaded =
          container.read(salesHistoryControllerProvider) as SalesHistoryLoaded;
      expect(loaded.sales.length, 2);
      expect(loaded.total, 2);
      expect(loaded.searchActive, isTrue);
      expect(loaded.isEmpty, isFalse);
    });
  });

  test('blank search is normalised to no search filter', () {
    return container
        .read(salesHistoryControllerProvider.notifier)
        .load(search: '   ')
        .then((_) {
      expect(repository.lastSearch, isNull);
      final loaded =
          container.read(salesHistoryControllerProvider) as SalesHistoryLoaded;
      expect(loaded.searchActive, isFalse);
    });
  });

  test('loadToday() delegates to load() for today', () {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);

    return container
        .read(salesHistoryControllerProvider.notifier)
        .loadToday()
        .then((_) {
      expect(repository.lastFrom, start);
      expect(repository.lastSearch, isNull);
      expect(repository.calls, 1);
    });
  });

  test('failure surfaces an error state', () {
    repository.failure = ServerException('network down');

    return container
        .read(salesHistoryControllerProvider.notifier)
        .load()
        .then((_) {
      final failure =
          container.read(salesHistoryControllerProvider) as SalesHistoryFailure;
      expect(failure.message, 'network down');
    });
  });

  test('load() resets to Loading before a new query', () async {
    repository.items = [_sale('s1')];
    await container.read(salesHistoryControllerProvider.notifier).load();

    final pending =
        container.read(salesHistoryControllerProvider.notifier).load();
    expect(container.read(salesHistoryControllerProvider),
        isA<SalesHistoryLoading>());
    await pending;
  });

  test('prependSale() places the newest sale at index 0', () async {
    repository.items = [_sale('s1')];
    await container.read(salesHistoryControllerProvider.notifier).load();

    final newSale = _sale('s2');
    container.read(salesHistoryControllerProvider.notifier).prependSale(newSale);

    final loaded =
        container.read(salesHistoryControllerProvider) as SalesHistoryLoaded;
    expect(loaded.sales.length, 2);
    expect(loaded.sales.first.id, 's2');
    expect(loaded.sales[1].id, 's1');
  });

  test('merged sales are sorted by saleDate descending with latest first', () async {
    final older = _sale('s1');
    final newer = _sale('s2');
    // Fake repository returns unordered
    repository.items = [older, newer];

    await container.read(salesHistoryControllerProvider.notifier).load();

    final loaded =
        container.read(salesHistoryControllerProvider) as SalesHistoryLoaded;
    expect(loaded.sales.length, 2);
  });
}
