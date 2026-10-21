import 'dart:async' as async;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../core/di/core_providers.dart' show localReceiptDaoProvider;
import '../../../core/network/app_exception.dart';
import '../../authentication/application/auth_controller.dart';
import '../../onboarding/application/workspace_controller.dart';
import '../data/offline_sale_recorder.dart';
import '../data/receipt_printer_service.dart';
import '../data/sale_repository.dart';
import '../domain/sale.dart';

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

  /// Fast POS timeout: try online for 3 seconds. If online has not answered
  /// or encounters network/server hiccups, immediately record offline (5ms)
  /// and sync in the background so the cashier never waits!
  static const _checkoutDeadline = Duration(milliseconds: 3000);

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

      final connection = ref.read(connectionQualityProvider);
      if (connection == ConnectionQuality.offline ||
          connection == ConnectionQuality.unreachable) {
        final windowOpen =
            await ref.read(sessionJournalProvider).offlineWindowOpen();
        if (windowOpen) {
          final offlineSale = await _recordOffline(lines, paymentMethod,
              amountTendered: amountTendered,
              customerId: customerId,
              customerName: customerName);
          if (offlineSale != null) {
            return offlineSale;
          }
        }
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
          final offlineSale = await _recordOffline(lines, paymentMethod,
              amountTendered: amountTendered,
              customerId: customerId,
              customerName: customerName);
          if (offlineSale != null) {
            return offlineSale;
          }
        }
        sale = await online;
      }

      await _persistConfirmedSaleLocally(sale);
      state = CheckoutSuccess(sale);
      _clientSaleId = null;
      return sale;
    } on AppException catch (error) {
      // Transport-level failures and server hiccups fall back to the local
      // pending queue — including timeouts, 5xx server errors, where the server
      // may already hold the sale with this exact key (safe by idempotent replay).
      if (_isTransportFailure(error) || error is ServerException) {
        final offlineSale = await _recordOffline(lines, paymentMethod,
            amountTendered: amountTendered,
            customerId: customerId,
            customerName: customerName);
        if (offlineSale != null) {
          return offlineSale;
        }
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
      final hasPermission = auth.session.user.hasPermission('Sales.Create') ||
          auth.session.user.hasPermission('sale.create');
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
      await _persistReceiptLocally(provisional);
      state = CheckoutSuccess(provisional);
      // Identity now lives in the persistent queue row.
      _clientSaleId = null;
      // Trigger background sync pass immediately (like Square & Toast)
      try {
        ref.read(syncEngineProvider).drain().ignore();
      } catch (_) {
        // Ignore in environments where sync engine is mocked or not running
      }
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

  Future<void> _persistConfirmedSaleLocally(SaleDto sale) async {
    try {
      final tenantId = ref.read(sessionContextProvider).$1 ?? '';
      final branchId = _branchId ?? '';
      final deviceId = await ref
          .read(deviceIdentityProvider)
          .get()
          .timeout(const Duration(milliseconds: 200), onTimeout: () => '');
      final auth = ref.read(authControllerProvider);
      final userId = auth is AuthAuthenticated ? auth.session.user.id : '';

      final salesService = ref.read(localSalesServiceProvider);
      await salesService.sales.recordConfirmedOnlineSale(
        sale: sale,
        tenantId: tenantId,
        branchId: branchId,
        deviceId: deviceId,
        userId: userId,
      );

      await _persistReceiptLocally(sale);
    } catch (_) {
      // Best-effort local persistence — does not block online checkout success.
    }
  }

  Future<void> _persistReceiptLocally(SaleDto sale) async {
    try {
      final tenantId = ref.read(sessionContextProvider).$1 ?? '';
      final printerService = ref.read(receiptPrinterServiceProvider);
      final businessName = _getBusinessName();
      final receipt = printerService.saleToReceipt(
        sale: sale,
        businessName: businessName,
      );
      final receiptText = printerService.buildReceiptText(receipt: receipt);
      final receiptDao = ref.read(localReceiptDaoProvider);
      await receiptDao.saveReceipt(
        saleId: sale.id,
        tenantId: tenantId,
        receiptNumber: sale.number,
        receipt: receipt,
        receiptText: receiptText,
      );
    } catch (_) {
      // Best-effort local persistence — non-fatal.
    }
  }

  String _getBusinessName() {
    try {
      final workspace = ref.read(workspaceControllerProvider);
      return workspace is WorkspaceReady && workspace.selected != null
          ? workspace.selected!.name
          : 'Business OS';
    } catch (_) {
      return 'Business OS';
    }
  }
}

