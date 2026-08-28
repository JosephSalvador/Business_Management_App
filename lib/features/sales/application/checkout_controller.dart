import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/app_exception.dart';
import '../data/sale_repository.dart';
import '../domain/sale.dart';
import 'offline_sale_recorder.dart';

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
/// Prices are re-resolved from `/pricing/resolve` immediately before an
/// ONLINE submit so the payment amount equals the server-computed total.
/// OFFLINE sales use cached shelf prices and are stored as estimates.
class CheckoutController extends StateNotifier<CheckoutState> {
  CheckoutController(
    this._repository,
    this._branchIdOf, {
    OfflineSaleRecorder? offlineRecorder,
    Future<bool> Function()? offlineWindowOpen,
    Uuid uuid = const Uuid(),
  })  : _offlineRecorder = offlineRecorder,
        _offlineWindowOpen = offlineWindowOpen,
        _uuid = uuid,
        super(const CheckoutIdle());

  final SaleRepository _repository;
  final OfflineSaleRecorder? _offlineRecorder;
  final Future<bool> Function()? _offlineWindowOpen;
  final Uuid _uuid;

  /// Resolves the branch the sale is recorded against (first tenant branch).
  final Future<String?> Function() _branchIdOf;

  String? _clientSaleId;
  String? _branchId;

  /// Submits the cart. Returns the created sale (or provisional pending
  /// sale), or null when the checkout failed (state carries the user-facing
  /// message) or was already running.
  Future<SaleDto?> submit({
    required List<CartLine> lines,
    required int paymentMethod,
  }) async {
    if (state is CheckoutSubmitting || lines.isEmpty) {
      return null;
    }

    // Keep the same idempotency key across retries of the same logical sale;
    // only start a new one when no attempt is in flight.
    _clientSaleId ??= _uuid.v4();

    state = const CheckoutSubmitting();
    try {
      final branchId = await _ensureBranchId();
      if (branchId == null) {
        throw ValidationException('Tawi la biashara halipatikani.');
      }

      List<CartLine> priced;
      double total;
      try {
        priced = await _refreshPrices(lines, branchId);
        total = priced.fold(0.0, (sum, line) => sum + line.lineTotal);
      } on NetworkException {
        return _recordOffline(lines, paymentMethod);
      } on TimeoutException {
        return _recordOffline(lines, paymentMethod);
      }

      final sale = await _repository.create(
        body: buildCreateSaleBody(
          branchId: branchId,
          clientSaleId: _clientSaleId!,
          lines: priced,
          paymentMethod: paymentMethod,
          total: total,
        ),
        idempotencyKey: _clientSaleId!,
      );

      state = CheckoutSuccess(sale);
      _clientSaleId = null;
      return sale;
    } on AppException catch (error) {
      // Transport-level failures fall back to the local pending queue —
      // including timeouts, where the server may already hold the sale with
      // this exact key (safe by idempotent replay).
      if (_isTransportFailure(error)) {
        return _recordOffline(lines, paymentMethod);
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

  Future<SaleDto?> _recordOffline(List<CartLine> lines, int paymentMethod) async {
    final recorder = _offlineRecorder;
    if (recorder == null) {
      state = CheckoutFailure(_mapError(NetworkException()));
      return null;
    }
    final windowOpen = await _offlineWindowOpen?.call() ?? true;
    if (!windowOpen) {
      state = const CheckoutFailure(
        'Kipindi cha kuuza nje ya mtandao kimeisha. '
        'Unganisha intaneti kuendelea kuuza.',
      );
      _clientSaleId = null;
      return null;
    }
    try {
      final recorded = await recorder.record(
        clientSaleIdOverride: _clientSaleId,
        lines: lines,
        paymentMethod: paymentMethod,
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
    return _branchId = await _branchIdOf();
  }

  Future<List<CartLine>> _refreshPrices(
    List<CartLine> lines,
    String branchId,
  ) async {
    final priced = <CartLine>[];
    for (final line in lines) {
      double price = line.unitPrice;
      try {
        final resolved = await _repository.resolvePrice(
          line.productId,
          quantity: line.quantity,
          branchId: branchId,
        );
        if (resolved != null) {
          price = resolved.price;
        }
      } on AppException {
        // Fall back to the cart price; the backend still recomputes and any
        // drift surfaces as a validation error rather than a wrong charge.
      }
      priced.add(CartLine(
        productId: line.productId,
        name: line.name,
        unitPrice: price,
        quantity: line.quantity,
      ));
    }
    return priced;
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
    return switch (error) {
      UnauthorizedException() => error.message,
      ForbiddenException() => error.message,
      NetworkException() =>
        'Hakuna mtandao. Sale haijatumwa — jaribu tena.',
      TimeoutException() =>
        'Muunganisho ulikwama. Thibitisha mauzo kabla ya kujaribu tena.',
      _ => message.isEmpty
          ? 'Imeshindikana kukamilisha mauzo.'
          : message,
    };
  }
}
