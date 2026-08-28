import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:business_management_system/core/network/app_exception.dart';
import 'package:business_management_system/features/sales/application/checkout_controller.dart';
import 'package:business_management_system/features/sales/data/sale_repository.dart';
import 'package:business_management_system/features/sales/domain/sale.dart';

/// In-memory [SaleRepository] recording what the checkout actually sent.
class FakeSaleRepository implements SaleRepository {
  FakeSaleRepository({this.createError, this.resolveError});

  final List<Map<String, dynamic>> bodies = [];
  final List<String> idempotencyKeys = [];
  int createCalls = 0;
  int resolveCalls = 0;

  /// When non-null, the next [create] throws it (then clears).
  AppException? createError;

  /// Applies to every [resolvePrice] call until cleared.
  AppException? resolveError;

  @override
  Future<SaleDto> create({
    required Map<String, dynamic> body,
    required String idempotencyKey,
  }) async {
    createCalls++;
    idempotencyKeys.add(idempotencyKey);
    bodies.add(body);
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
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
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

CartLine rice() =>
    CartLine(productId: 'p1', name: 'Mchele', unitPrice: 2500);

CheckoutController controllerWith(
  FakeSaleRepository repository, {
  String branchId = 'branch-1',
}) =>
    CheckoutController(repository, () async => branchId);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CheckoutController', () {
    test('submits with resolved prices and the exact backend contract',
        () async {
      final repository = FakeSaleRepository();
      final controller = controllerWith(repository);

      final sale = await controller.submit(
        lines: [rice()],
        paymentMethod: PaymentMethod.cash,
      );

      expect(sale!.number, 'S-2026-000001');
      expect(controller.state, isA<CheckoutSuccess>());
      expect(repository.resolveCalls, 1);
      expect(repository.bodies.single['branchId'], 'branch-1');
      expect(repository.bodies.single['payments'], [
        {'method': 0, 'amount': 2500.0},
      ]);
    });

    test('double tap while submitting is ignored — one request only',
        () async {
      late CheckoutController controller;
      // Slow the create call down so a second submit overlaps it.
      final gate = Completer<void>();
      final slow = FakeSaleRepository();
      controller = CheckoutController(slow, () async {
        await gate.future;
        return 'branch-1';
      });

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

    test('network failure keeps the idempotency key for the retry',
        () async {
      final repository = FakeSaleRepository()
        ..createError = NetworkException();
      final controller = controllerWith(repository);

      await controller.submit(lines: [rice()], paymentMethod: 0);
      expect(controller.state, isA<CheckoutFailure>());

      final sale = await controller.submit(lines: [rice()], paymentMethod: 0);

      expect(sale, isNotNull);
      expect(repository.createCalls, 2);
      expect(repository.idempotencyKeys.first,
          repository.idempotencyKeys.last,
          reason: 'the retry replays the same logical sale');
    });

    test('definitive rejection starts a fresh sale on the next attempt',
        () async {
      final repository = FakeSaleRepository()
        ..createError = ValidationException('Insufficient stock for Mchele.');
      final controller = controllerWith(repository);

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
        final controller = controllerWith(repository);
        await controller.submit(lines: [rice()], paymentMethod: 0);
        expect((controller.state as CheckoutFailure).message,
            entry.value, reason: entry.key.message);
      }
    });

    test('price resolution failure falls back to the cart price', () async {
      final repository = FakeSaleRepository()
        ..resolveError = TimeoutException();
      final controller = controllerWith(repository);

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
      final controller =
          CheckoutController(repository, () async => null);

      final sale = await controller.submit(lines: [rice()], paymentMethod: 0);

      expect(sale, isNull);
      expect((controller.state as CheckoutFailure).message,
          'Tawi la biashara halipatikani.');
      expect(repository.createCalls, 0);
    });
  });

}

// Small helpers used by the tests above.
extension on CheckoutState {
  String get message => this is CheckoutFailure
      ? (this as CheckoutFailure).message
      : '';
}
