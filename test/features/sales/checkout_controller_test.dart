import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/app/providers.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/core/storage/local_database.dart';
import 'package:jolinx_app/core/sync/local_sales_service.dart';
import 'package:jolinx_app/features/sales/application/checkout_controller.dart';
import 'package:jolinx_app/features/sales/data/sale_repository.dart';
import 'package:jolinx_app/features/sales/domain/sale.dart';

/// In-memory [SaleRepository] recording what the checkout actually sent.
class FakeSaleRepository implements SaleRepository {
  FakeSaleRepository({this.createError, this.resolveError, this.stall});

  final List<Map<String, dynamic>> bodies = [];
  final List<String> idempotencyKeys = [];
  int createCalls = 0;
  int resolveCalls = 0;
  int resolveManyCalls = 0;

  /// When non-null, [create] awaits this future first (simulates a stalled
  /// backend; leave it pending to exercise the checkout deadline).
  final Future<void>? stall;

  /// When non-null, the next [create] throws it (then clears).
  AppException? createError;

  /// Applies to every [resolvePrice] call until cleared.
  AppException? resolveError;

  /// Applies to the next [resolvePrices] call, then clears.
  AppException? resolveMultiError;

  @override
  Future<SaleDto> create({
    required Map<String, dynamic> body,
    required String idempotencyKey,
  }) async {
    createCalls++;
    idempotencyKeys.add(idempotencyKey);
    bodies.add(body);
    if (stall != null) {
      await stall!;
    }
    if (createError != null) {
      final error = createError!;
      createError = null;
      throw error;
    }
    return _sale(idempotencyKey);
  }

  @override
  Future<ResolvedPrice?> resolvePrice(
    String productId, {
    double quantity = 1,
    String? branchId,
  }) async {
    resolveCalls++;
    if (resolveError != null) {
      final error = resolveError!;
      resolveError = null;
      throw error;
    }
    return const ResolvedPrice(price: 2500, currency: 'TZS');
  }

  @override
  Future<Map<String, double>> resolvePrices({
    required List<String> productIds,
    List<double>? quantities,
    String? branchId,
  }) async {
    resolveManyCalls++;
    if (resolveMultiError != null) {
      final error = resolveMultiError!;
      resolveMultiError = null;
      throw error;
    }
    return {for (final id in productIds) id: 2500.0};
  }

  @override
  Future<PagedSales> list({
    int page = 1,
    int pageSize = 50,
    DateTime? from,
    DateTime? to,
    int? status,
    String? search,
  }) async =>
      const PagedSales(items: [], total: 0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SaleDto _sale(String clientSaleId) => SaleDto.fromJson({
      'id': 's1',
      'number': 'S-2026-000001',
      'status': 0,
      'saleDate': '2026-08-23T10:00:00Z',
      'currency': 'TZS',
      'subtotal': 5000,
      'discountAmount': 0,
      'taxAmount': 720,
      'totalAmount': 5720,
      'amountPaid': 5720,
      'change': 0,
      'clientSaleId': clientSaleId,
      'lines': <dynamic>[],
      'payments': [
        {'method': 0, 'amount': 5720},
      ],
    });

CartLine rice() => CartLine(productId: 'p1', name: 'Mchele', unitPrice: 2500);

ProviderContainer _container({
  required FakeSaleRepository repository,
  Future<String?> Function()? branchId,
}) {
  final db = LocalDatabase(NativeDatabase.memory());
  final service = LocalSalesService(database: db);
  return ProviderContainer(overrides: [
    localDatabaseProvider.overrideWithValue(db),
    localSalesServiceProvider.overrideWithValue(service),
    sessionContextProvider.overrideWithValue(('tenant-1', 'user-1')),
    saleRepositoryProvider.overrideWithValue(repository),
    posBranchIdProvider.overrideWithValue(
      branchId ?? (() async => 'branch-1'),
    ),
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CheckoutController', () {
    test('submits with resolved prices and the exact backend contract',
        () async {
      final repository = FakeSaleRepository();
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(checkoutControllerProvider.notifier);

      final sale = await controller.submit(
        lines: [rice()],
        paymentMethod: PaymentMethod.cash,
      );

      expect(sale!.number, 'S-2026-000001');
      expect(controller.state, isA<CheckoutSuccess>());
      expect(repository.resolveManyCalls, 1);
      expect(repository.bodies.single['branchId'], 'branch-1');
      expect(repository.bodies.single['payments'], [
        {'method': 0, 'amount': 2500.0},
      ]);
    });

    test('credit submit links the customer and keeps a zero initial payment',
        () async {
      final repository = FakeSaleRepository();
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(checkoutControllerProvider.notifier);

      final sale = await controller.submit(
        lines: [rice()],
        paymentMethod: PaymentMethod.credit,
        amountTendered: 0,
        customerId: 'cust-1',
        customerName: 'Neema Shop',
      );

      expect(sale, isNotNull);
      expect(repository.bodies.single['customerId'], 'cust-1');
      expect(repository.bodies.single['isElectronicPayment'], isFalse,
          reason: 'an in-house credit balance is not an electronic tender');
      expect(repository.bodies.single['payments'], [
        {'method': 4, 'amount': 0.0},
      ]);
    });

    test('double tap while submitting is ignored — one request only', () async {
      final gate = Completer<void>();
      final slow = FakeSaleRepository();
      final container = _container(repository: slow);
      addTearDown(container.dispose);
      final controller = container.read(checkoutControllerProvider.notifier);

      final first = controller.submit(
        lines: [rice()],
        paymentMethod: PaymentMethod.cash,
      );
      final second = controller.submit(
        lines: [rice()],
        paymentMethod: PaymentMethod.cash,
      );

      expect(await second, isNull);
      gate.complete();
      expect(await first, isNotNull);
      expect(slow.createCalls, 1);
    });

    test('definitive rejection starts a fresh sale on the next attempt',
        () async {
      final repository = FakeSaleRepository()
        ..createError = ValidationException('Insufficient stock for Mchele.');
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(checkoutControllerProvider.notifier);

      await controller.submit(lines: [rice()], paymentMethod: 0);
      expect(controller.state.message, 'Kiasi cha bidhaa hakitoshi.');

      await controller.submit(lines: [rice()], paymentMethod: 0);

      expect(repository.idempotencyKeys.first,
          isNot(repository.idempotencyKeys.last));
    });

    test('maps backend failures to friendly Swahili messages', () async {
      final cases = {
        ValidationException('No price could be resolved for Sukari.'):
            contains('haina bei'),
        ValidationException("Product 'Sukari' is not sellable."):
            contains('hauuzi'),
        ForbiddenException(): equals('Hauna ruhusa ya kitendo hiki.'),
        ServerException(): isNotEmpty,
      };
      for (final entry in cases.entries) {
        final repository = FakeSaleRepository()..createError = entry.key;
        final container = _container(repository: repository);
        addTearDown(container.dispose);
        final controller = container.read(checkoutControllerProvider.notifier);
        await controller.submit(lines: [rice()], paymentMethod: 0);
        expect((controller.state as CheckoutFailure).message, entry.value,
            reason: entry.key.message);
      }
    });

    test('price resolution failure falls back to the cart price', () async {
      final repository = FakeSaleRepository()
        ..resolveMultiError = TimeoutException();
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(checkoutControllerProvider.notifier);

      final sale = await controller.submit(
        lines: [rice()],
        paymentMethod: 0,
      );

      expect(sale, isNotNull);
      expect(repository.bodies.single['payments'], [
        {'method': 0, 'amount': 2500.0},
      ]);
    });

    test('missing branch fails without calling create', () async {
      final repository = FakeSaleRepository();
      final container = _container(
        repository: repository,
        branchId: () async => null,
      );
      addTearDown(container.dispose);
      final controller = container.read(checkoutControllerProvider.notifier);

      final sale = await controller.submit(lines: [rice()], paymentMethod: 0);

      expect(sale, isNull);
      expect((controller.state as CheckoutFailure).message,
          'Tawi la biashara halipatikani.');
      expect(repository.createCalls, 0);
    });
  });
}

extension on CheckoutState {
  String get message =>
      this is CheckoutFailure ? (this as CheckoutFailure).message : '';
}
