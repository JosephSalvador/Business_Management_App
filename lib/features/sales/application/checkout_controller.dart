import 'dart:async' as async;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../core/network/app_exception.dart';
import '../../authentication/application/auth_controller.dart';
import '../data/sale_repository.dart';
import '../domain/sale.dart';
import '../data/offline_sale_recorder.dart';

sealed class CheckoutState {
  const CheckoutState();
}

class CheckoutIdle extends CheckoutState {
  const CheckoutIdle();
}

class CheckoutSubmitting extends CheckoutState {
  const CheckoutSubmitting();
}

class CheckoutSuccess extends CheckoutState {
  const CheckoutSuccess(this.sale);

  final SaleDto sale;
}

class CheckoutFailure extends CheckoutState {
  const CheckoutFailure(this.message);

  final String message;
}

/// Submits the cart to `POST /api/v1/sales`, falling back to an atomic
/// PENDING record in the encrypted local database when the API cannot be
/// reached (M5.4). The pending record keeps the SAME clientSaleId that was
/// used (or would have been used) online, so the later sync replay can never
/// produce a second server sale — including the dangerous
/// "timeout after the server accepted" case (M5.7).
///
/// Idempotency contract:
/// - A GUID [Uuid] is drawn when a checkout attempt starts and is kept across
///   retries caused by network/timeout/server failures.
/// - The key is discarded only after success or a definitive rejection
///   (validation, stock, permissions), where a new logical sale begins.
///
/// Prices are re-resolved from `/pricing/resolve-many` (one bulk call for the
/// whole cart) immediately before an ONLINE submit so the payment amount
/// equals the server-computed total. OFFLINE sales use cached shelf prices
/// and are stored as estimates.
class CheckoutController extends Notifier<CheckoutState> {
  String? _clientSaleId;
  String? _branchId;

  /// How long an online attempt may take before the checkout falls back to
  /// the local pending queue. Set so a slow-but-alive link still lands on the
  /// receipt quickly; the idempotency key keeps a late server accept safe.
  static const _checkoutDeadline = Duration(seconds: 4);

  @override
  CheckoutState build() => const CheckoutIdle();

  SaleRepository get _repository => ref.read(saleRepositoryProvider);

  /// Submits the cart. Returns the created sale (or provisional pending
  /// sale), or null when the checkout failed (state carries the user-facing
  /// message) or was already running.
  ///
  /// [amountTendered] is the money actually handed over — used for CASH so the
  /// server can compute change when the tender exceeds the total. For non-cash
  /// methods pass null (exact total); for CREDIT pass the initial payment
  /// (defaults to zero) so the balance goes on the customer's ledger.
  /// [customerId]/[customerName] link a CREDIT sale to its ledger customer.
  Future<SaleDto?> submit({
    required List<CartLine> lines,
    required int paymentMethod,
    double? amountTendered,
    String? customerId,
    String? customerName,
  }) async {
    if (state is CheckoutSubmitting || lines.isEmpty) {
      return null;
    }

    // Keep the same idempotency key across retries of the same logical sale;
    // only start a new one when no attempt is in flight.
    _clientSaleId ??= const Uuid().v4();

    state = const CheckoutSubmitting();
    try {
      final branchId = await _ensureBranchId();
      if (branchId == null) {
        throw ValidationException('Tawi la biashara halipatikani.');
      }

      final online = _tryOnline(
        branchId: branchId,
        lines: lines,
        paymentMethod: paymentMethod,
        amountTendered: amountTendered,
        customerId: customerId,
      );
      // Absorb a late success/error when the deadline already fell back
      // offline — the server may still accept, and the idempotency key makes
      // the later pending-queue replay harmless (M5.7).
      online.ignore();

      SaleDto sale;
      try {
        sale = await online.timeout(_checkoutDeadline);
      } on async.TimeoutException {
        // Only fast-path into the local pending queue when it can accept the
        // sale; otherwise keep waiting for the authoritative outcome.
        final windowOpen =
            await ref.read(sessionJournalProvider).offlineWindowOpen();
        if (windowOpen) {
          return await _recordOffline(lines, paymentMethod,
              amountTendered: amountTendered,
              customerId: customerId,
              customerName: customerName);
        }
        sale = await online;
      }

      state = CheckoutSuccess(sale);
      _clientSaleId = null;
      return sale;
    } on AppException catch (error) {
      // Transport-level failures fall back to the local pending queue —
      // including timeouts, where the server may already hold the sale with
      // this exact key (safe by idempotent replay).
      if (_isTransportFailure(error)) {
        return _recordOffline(lines, paymentMethod,
            amountTendered: amountTendered,
            customerId: customerId,
            customerName: customerName);
      }
      state = CheckoutFailure(_mapError(error));
      if (!_isRetryable(error)) {
        // Definitive rejection: the next tap starts a fresh logical sale.
        _clientSaleId = null;
      }
      return null;
    }
  }

  void reset() {
    _clientSaleId = null;
    state = const CheckoutIdle();
  }

  Future<SaleDto?> _recordOffline(
    List<CartLine> lines,
    int paymentMethod, {
    double? amountTendered,
    String? customerId,
    String? customerName,
  }) async {
    final recorder = ref.read(offlineSaleRecorderProvider);

    // Check offline window
    final windowOpen = ref.read(sessionJournalProvider).offlineWindowOpen();
    final isOpen = await windowOpen;
    if (!isOpen) {
      state = const CheckoutFailure(
        'Kipindi cha kuuza nje ya mtandao kimeisha. '
        'Unganisha intaneti kuendelea kuuza.',
      );
      _clientSaleId = null;
      return null;
    }

    // Check offline selling permission
    final auth = ref.read(authControllerProvider);
    if (auth is AuthAuthenticated) {
      final hasPermission = auth.session.user.hasPermission('sale.create');
      if (!hasPermission) {
        state = const CheckoutFailure(
          'Huna ruhusa ya kuuza. Ingia mtandoni kupata ruhusa.',
        );
        _clientSaleId = null;
        return null;
      }
    } else {
      state = const CheckoutFailure(
        'Huna sessioni ya kuuza. Tafadhali ingia.',
      );
      _clientSaleId = null;
      return null;
    }

    try {
      final recorded = await recorder.record(
        clientSaleIdOverride: _clientSaleId,
        lines: lines,
        paymentMethod: paymentMethod,
        paymentAmount: amountTendered,
        customerId: customerId,
      );
      var subtotal = 0.0;
      for (final line in lines) {
        subtotal += line.lineTotal;
      }
      final provisional = OfflineSaleRecorder.provisionalDto(
        recorded: recorded,
        lines: lines,
        paymentMethod: paymentMethod,
        total: subtotal,
        paymentAmount: amountTendered,
        customerName: customerName,
      );
      state = CheckoutSuccess(provisional);
      // Identity now lives in the persistent queue row.
      _clientSaleId = null;
      return provisional;
    } on AppException catch (error) {
      state = CheckoutFailure(_mapError(error));
      return null;
    }
  }

  Future<String?> _ensureBranchId() async {
    if (_branchId != null) {
      return _branchId;
    }

    // Try cache first (for offline scenarios). The cache is best-effort:
    // a storage failure OR a wedged keystore read (thrown error or read
    // that never answers) must never block a sale — fall through to the
    // API instead.
    try {
      final cached = await ref
          .read(branchCacheProvider)
          .getCached()
          .timeout(const Duration(seconds: 2), onTimeout: () => null);
      if (cached != null) {
        _branchId = cached;
        return cached;
      }
    } on Exception {
      // Cache unreadable — the API path below is the source of truth.
    }

    // Fall back to API
    return _branchId = await ref.read(posBranchIdProvider)();
  }

  Future<SaleDto> _tryOnline({
    required String branchId,
    required List<CartLine> lines,
    required int paymentMethod,
    double? amountTendered,
    String? customerId,
  }) async {
    final priced = await _refreshPrices(lines, branchId);
    final total = priced.fold(0.0, (sum, line) => sum + line.lineTotal);
    return _repository.create(
      body: buildCreateSaleBody(
        branchId: branchId,
        clientSaleId: _clientSaleId!,
        lines: priced,
        paymentMethod: paymentMethod,
        total: total,
        paymentAmount: amountTendered,
        customerId: customerId,
      ),
      idempotencyKey: _clientSaleId!,
    );
  }

  Future<List<CartLine>> _refreshPrices(
    List<CartLine> lines,
    String branchId,
  ) async {
    // Quick-sale lines carry a client-fixed price — split them out.
    final toResolve = <CartLine>[];
    final quickLines = <CartLine>[];
    for (final line in lines) {
      if (line.unitPriceOverride != null) {
        quickLines.add(line);
      } else {
        toResolve.add(line);
      }
    }

    if (toResolve.isEmpty) {
      return lines;
    }

    // One bulk call prices the whole cart instead of one round trip per line.
    Map<String, double> prices;
    try {
      prices = await _repository.resolvePrices(
        productIds: [for (final line in toResolve) line.productId],
        quantities: [for (final line in toResolve) line.quantity],
        branchId: branchId,
      );
    } on AppException {
      // Fall back to the cart prices as-is.
      return lines;
    }

    return [
      for (final line in toResolve)
        CartLine(
          productId: line.productId,
          name: line.name,
          unitPrice: prices[line.productId] ?? line.unitPrice,
          quantity: line.quantity,
        ),
      ...quickLines,
    ];
  }

  bool _isTransportFailure(AppException error) =>
      error is NetworkException || error is TimeoutException;

  bool _isRetryable(AppException error) =>
      error is NetworkException ||
      error is TimeoutException ||
      error is ServerException ||
      error is UnknownException;

  String _mapError(AppException error) {
    final message = error.message;
    if (message.contains('Insufficient stock') ||
        message.contains('hakitoshi')) {
      return 'Kiasi cha bidhaa hakitoshi.';
    }
    if (message.contains('No price could be resolved') ||
        message.contains('No price list')) {
      return 'Bidhaa haina bei. Iweke bei kwanza.';
    }
    if (message.contains('not sellable')) {
      return 'Bidhaa hii hauuzi kwa sasa.';
    }
    if (message.contains('fully cover')) {
      return 'Malipo hayakutosheleza. Jaribu tena.';
    }
    if (message.contains('credit sale needs a customer')) {
      return 'Chagua mteja kwa mauzo ya mkopo.';
    }
    return switch (error) {
      UnauthorizedException() => error.message,
      ForbiddenException() => error.message,
      NetworkException() => 'Hakuna mtandao. Sale haijatumwa — jaribu tena.',
      TimeoutException() =>
        'Muunganisho ulikwama. Thibitisha mauzo kabla ya kujaribu tena.',
      _ => message.isEmpty ? 'Imeshindikana kukamilisha mauzo.' : message,
    };
  }
}
