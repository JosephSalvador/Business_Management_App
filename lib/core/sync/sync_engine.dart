import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../network/app_exception.dart';
import '../../features/customers/data/customer_repository.dart';
import '../../features/finance/data/expense_repository.dart';
import '../../features/finance/data/money_account_repository.dart';
import '../../features/inventory/data/inventory_repository.dart';
import '../../features/products/data/product_repository.dart';
import '../../features/products/domain/catalog.dart' show PriceList;
import '../../features/purchases/data/purchase_repository.dart';
import '../../features/sales/data/sale_repository.dart';
import '../../features/sales/domain/sale.dart' show QuickSaleDefaults;
import '../../features/suppliers/data/supplier_repository.dart';
import '../storage/sync_queue_dao.dart' show QueuedOperation;
import 'local_sales_service.dart';

/// What one drain pass achieved — feeds the UX summary, never shown raw.
class SyncOutcome {
  SyncOutcome({
    this.synced = 0,
    this.conflicted = 0,
    this.failed = 0,
    this.retriedLater = 0,
    this.pausedForSession = false,
    this.wentOffline = false,
    this.moduleDisabled = false,
    this.billingRequired = false,
  });

  int synced;
  int conflicted;
  int failed;
  int retriedLater;
  bool pausedForSession;
  bool wentOffline;
  bool moduleDisabled;
  bool billingRequired;

  bool get changed => synced > 0 || conflicted > 0 || failed > 0;
}

/// The single sync worker per device (M5.8).
///
/// Drains the persistent queue FIFO. Delivery is exactly-once by contract:
/// every attempt replays the operation's stable id as Idempotency-Key, so a
/// timeout after the server accepted the sale resolves to a replay of the
/// original on retry (M5.7). Conflicts are terminal states kept for review —
/// nothing is silently resolved or deleted (M5.12).
class SyncEngine {
  SyncEngine({
    required LocalSalesService salesService,
    required SaleRepository repository,
    ExpenseRepository? expenseRepository,
    CustomerRepository? customerRepository,
    InventoryRepository? inventoryRepository,
    MoneyAccountRepository? moneyAccountRepository,
    ProductRepository? productRepository,
    SupplierRepository? supplierRepository,
    PurchaseRepository? purchaseRepository,
  })  : _salesService = salesService,
        _repository = repository,
        _expenseRepository = expenseRepository,
        _customerRepository = customerRepository,
        _inventoryRepository = inventoryRepository,
        _moneyAccountRepository = moneyAccountRepository,
        _productRepository = productRepository,
        _supplierRepository = supplierRepository,
        _purchaseRepository = purchaseRepository;

  final LocalSalesService _salesService;
  final SaleRepository _repository;
  final ExpenseRepository? _expenseRepository;
  final CustomerRepository? _customerRepository;
  final InventoryRepository? _inventoryRepository;
  final MoneyAccountRepository? _moneyAccountRepository;
  final ProductRepository? _productRepository;
  final SupplierRepository? _supplierRepository;
  final PurchaseRepository? _purchaseRepository;

  Future<void> Function(SyncOutcome)? onDrained;

  bool _draining = false;

  /// True while a drain is in flight — the UX shows "Nasawazisha mauzo...".
  bool get isSyncing => _draining;

  /// Processes all due operations. Safe to call concurrently: the second
  /// call returns immediately while the first keeps working.
  Future<SyncOutcome> drain({bool forceRetryAll = false}) async {
    if (_draining) {
      return SyncOutcome();
    }
    _draining = true;
    final outcome = SyncOutcome();
    try {
      while (true) {
        final op = await _salesService.claimNext(
          now: DateTime.now().toUtc(),
          ignoreSchedule: forceRetryAll,
        );
        if (op == null) {
          break;
        }

        final delivered = await _deliver(op, outcome);
        if (delivered == _DeliveryResult.stop) {
          break;
        }
      }
    } finally {
      _draining = false;
    }
    if (outcome.changed || forceRetryAll) {
      await onDrained?.call(outcome);
    }
    return outcome;
  }

  Future<_DeliveryResult> _deliver(
    QueuedOperation op,
    SyncOutcome outcome,
  ) async {
    switch (op.operationType) {
      case 'sale.create':
        return _deliverSale(op, outcome);
      case 'expense.create':
        return _deliverExpense(op, outcome);
      case 'customer.create':
        return _deliverCustomerCreate(op, outcome);
      case 'customer.debt_payment':
        return _deliverCustomerDebtPayment(op, outcome);
      case 'cash_session.open':
        return _deliverCashSessionOpen(op, outcome);
      case 'cash_session.close':
        return _deliverCashSessionClose(op, outcome);
      case 'inventory.receive':
        return _deliverInventoryAdjustment(op, outcome);
      case 'product.create':
        return _deliverProductCreate(op, outcome);
      case 'product.update':
        return _deliverProductUpdate(op, outcome);
      case 'product.price_set':
        return _deliverProductPriceSet(op, outcome);
      case 'supplier.create':
        return _deliverSupplierCreate(op, outcome);
      case 'supplier.update':
        return _deliverSupplierUpdate(op, outcome);
      case 'purchase.create':
        return _deliverPurchaseCreate(op, outcome);
      default:
        await _salesService.markQueueFailed(
          op.operationId,
          errorCode: 'UNKNOWN_OP',
          errorMessage: 'Unknown operation type ${op.operationType}',
        );
        outcome.failed++;
        return _DeliveryResult.continue_;
    }
  }

  Future<_DeliveryResult> _deliverSale(
    QueuedOperation op,
    SyncOutcome outcome,
  ) async {
    try {
      final body = jsonDecode(op.payload) as Map<String, dynamic>;
      final lines = (body['lines'] as List?)?.cast<Map<String, dynamic>>();
      if (lines != null &&
          lines.any((l) =>
              l['productId'] == QuickSaleDefaults.provisionalProductId)) {
        try {
          final realQuickSaleId =
              await _repository.getOrCreateQuickSaleProduct();
          for (final line in lines) {
            if (line['productId'] == QuickSaleDefaults.provisionalProductId) {
              line['productId'] = realQuickSaleId;
            }
          }
        } on AppException {
          // If resolving real ID fails due to network/session, retry later
          await _salesService.releaseUnattempted(op.operationId);
          outcome.wentOffline = true;
          return _DeliveryResult.stop;
        }
      }

      if (body['branchId'] == null) {
        final realBranchId = await _repository.defaultBranchId();
        if (realBranchId != null) {
          body['branchId'] = realBranchId;
        }
      }

      final sale = await _repository.create(
        body: body,
        idempotencyKey: op.operationId,
      );
      await _salesService.markSaleSynced(
        clientSaleId: op.aggregateId,
        serverSaleId: sale.id,
        serverNumber: sale.number,
      );
      outcome.synced++;
      return _DeliveryResult.continue_;
    } on ValidationException catch (error) {
      final code =
          error.message.contains('Insufficient stock') ? 'STOCK' : 'VALIDATION';
      await _conflict(op, outcome, code, error.message);
      return _DeliveryResult.continue_;
    } on UnauthorizedException {
      // Session problem: pause the engine without burning an attempt.
      await _salesService.releaseUnattempted(op.operationId);
      outcome.pausedForSession = true;
      return _DeliveryResult.stop;
    } on ForbiddenException catch (error) {
      // User disabled / branch disabled / permission removed (M5.12 CASE 6-8).
      await _fail(op, outcome, 'PERMISSION', error.message);
      return _DeliveryResult.continue_;
    } on ModuleDisabledException catch (error) {
      await _fail(op, outcome, 'MODULE_DISABLED', error.message);
      outcome.moduleDisabled = true;
      return _DeliveryResult.continue_;
    } on PaymentRequiredException {
      await _salesService.releaseUnattempted(op.operationId);
      outcome.billingRequired = true;
      return _DeliveryResult.continue_;
    } on QuotaExceededException catch (error) {
      await _fail(op, outcome, 'QUOTA', error.message);
      return _DeliveryResult.continue_;
    } on ConflictException catch (error) {
      // Should not happen for well-formed keys (replay returns 200); keep
      // for review rather than guessing.
      await _fail(op, outcome, 'CONFLICT_409', error.message);
      return _DeliveryResult.continue_;
    } on NetworkException {
      await _retryLater(op, outcome);
      outcome.wentOffline = true;
      return _DeliveryResult.stop;
    } on TimeoutException {
      // CRITICAL: the server may have accepted the sale before the response
      // was lost. Retrying with the same key is safe either way (M5.7).
      await _retryLater(op, outcome);
      return _DeliveryResult.stop;
    } on ServerException {
      await _retryLater(op, outcome);
      return _DeliveryResult.continue_;
    }
  }

  Future<_DeliveryResult> _deliverExpense(
    QueuedOperation op,
    SyncOutcome outcome,
  ) async {
    if (_expenseRepository == null) {
      await _retryLater(op, outcome);
      return _DeliveryResult.continue_;
    }
    try {
      final body = jsonDecode(op.payload) as Map<String, dynamic>;
      final result = await _expenseRepository.create(body, remoteOnly: true);
      final serverId = result['id']?.toString() ?? op.aggregateId;
      await _salesService.queue.markSynced(op.operationId, serverId);
      outcome.synced++;
      return _DeliveryResult.continue_;
    } on ValidationException catch (error) {
      await _conflict(op, outcome, 'VALIDATION', error.message);
      return _DeliveryResult.continue_;
    } on UnauthorizedException {
      await _salesService.releaseUnattempted(op.operationId);
      outcome.pausedForSession = true;
      return _DeliveryResult.stop;
    } on ForbiddenException catch (error) {
      await _fail(op, outcome, 'PERMISSION', error.message);
      return _DeliveryResult.continue_;
    } on NetworkException {
      await _retryLater(op, outcome);
      outcome.wentOffline = true;
      return _DeliveryResult.stop;
    } on TimeoutException {
      await _retryLater(op, outcome);
      return _DeliveryResult.stop;
    } on ServerException {
      await _retryLater(op, outcome);
      return _DeliveryResult.continue_;
    } catch (e) {
      await _fail(op, outcome, 'UNKNOWN_ERROR', e.toString());
      return _DeliveryResult.continue_;
    }
  }

  Future<_DeliveryResult> _deliverCustomerDebtPayment(
    QueuedOperation op,
    SyncOutcome outcome,
  ) async {
    if (_customerRepository == null) {
      await _retryLater(op, outcome);
      return _DeliveryResult.continue_;
    }
    try {
      final body = jsonDecode(op.payload) as Map<String, dynamic>;
      final customerId = body['customerId']?.toString() ?? op.aggregateId;
      final amount = (body['amount'] as num?)?.toDouble() ?? 0.0;
      final description = body['description']?.toString() ?? 'Malipo ya Deni';

      await _customerRepository.recordPayment(
        customerId,
        amount,
        description,
        remoteOnly: true,
      );
      await _salesService.queue.markSynced(op.operationId, 'synced');
      outcome.synced++;
      return _DeliveryResult.continue_;
    } on ValidationException catch (error) {
      await _conflict(op, outcome, 'VALIDATION', error.message);
      return _DeliveryResult.continue_;
    } on UnauthorizedException {
      await _salesService.releaseUnattempted(op.operationId);
      outcome.pausedForSession = true;
      return _DeliveryResult.stop;
    } on ForbiddenException catch (error) {
      await _fail(op, outcome, 'PERMISSION', error.message);
      return _DeliveryResult.continue_;
    } on NetworkException {
      await _retryLater(op, outcome);
      outcome.wentOffline = true;
      return _DeliveryResult.stop;
    } on TimeoutException {
      await _retryLater(op, outcome);
      return _DeliveryResult.stop;
    } on ServerException {
      await _retryLater(op, outcome);
      return _DeliveryResult.continue_;
    } catch (e) {
      await _fail(op, outcome, 'UNKNOWN_ERROR', e.toString());
      return _DeliveryResult.continue_;
    }
  }

  Future<_DeliveryResult> _deliverCustomerCreate(
    QueuedOperation op,
    SyncOutcome outcome,
  ) async {
    if (_customerRepository == null) {
      await _retryLater(op, outcome);
      return _DeliveryResult.continue_;
    }
    try {
      final body = jsonDecode(op.payload) as Map<String, dynamic>;
      final result = await _customerRepository.create(body, remoteOnly: true);
      final serverId = result['id']?.toString() ?? op.aggregateId;
      await _salesService.queue.markSynced(op.operationId, serverId);
      outcome.synced++;
      return _DeliveryResult.continue_;
    } on ValidationException catch (error) {
      await _conflict(op, outcome, 'VALIDATION', error.message);
      return _DeliveryResult.continue_;
    } on UnauthorizedException {
      await _salesService.releaseUnattempted(op.operationId);
      outcome.pausedForSession = true;
      return _DeliveryResult.stop;
    } on ForbiddenException catch (error) {
      await _fail(op, outcome, 'PERMISSION', error.message);
      return _DeliveryResult.continue_;
    } on NetworkException {
      await _retryLater(op, outcome);
      outcome.wentOffline = true;
      return _DeliveryResult.stop;
    } on TimeoutException {
      await _retryLater(op, outcome);
      return _DeliveryResult.stop;
    } on ServerException {
      await _retryLater(op, outcome);
      return _DeliveryResult.continue_;
    } catch (e) {
      await _fail(op, outcome, 'UNKNOWN_ERROR', e.toString());
      return _DeliveryResult.continue_;
    }
  }

  Future<_DeliveryResult> _deliverCashSessionOpen(
    QueuedOperation op,
    SyncOutcome outcome,
  ) async {
    if (_moneyAccountRepository == null) {
      await _retryLater(op, outcome);
      return _DeliveryResult.continue_;
    }
    try {
      final body = jsonDecode(op.payload) as Map<String, dynamic>;
      final result = await _moneyAccountRepository.openSession(
        body,
        remoteOnly: true,
      );
      final serverId = result['id']?.toString() ?? op.aggregateId;
      await _salesService.queue.markSynced(op.operationId, serverId);
      outcome.synced++;
      return _DeliveryResult.continue_;
    } on ValidationException catch (error) {
      await _conflict(op, outcome, 'VALIDATION', error.message);
      return _DeliveryResult.continue_;
    } on UnauthorizedException {
      await _salesService.releaseUnattempted(op.operationId);
      outcome.pausedForSession = true;
      return _DeliveryResult.stop;
    } on ForbiddenException catch (error) {
      await _fail(op, outcome, 'PERMISSION', error.message);
      return _DeliveryResult.continue_;
    } on NetworkException {
      await _retryLater(op, outcome);
      outcome.wentOffline = true;
      return _DeliveryResult.stop;
    } on TimeoutException {
      await _retryLater(op, outcome);
      return _DeliveryResult.stop;
    } on ServerException {
      await _retryLater(op, outcome);
      return _DeliveryResult.continue_;
    } catch (e) {
      await _fail(op, outcome, 'UNKNOWN_ERROR', e.toString());
      return _DeliveryResult.continue_;
    }
  }

  Future<_DeliveryResult> _deliverCashSessionClose(
    QueuedOperation op,
    SyncOutcome outcome,
  ) async {
    if (_moneyAccountRepository == null) {
      await _retryLater(op, outcome);
      return _DeliveryResult.continue_;
    }
    try {
      final body = jsonDecode(op.payload) as Map<String, dynamic>;
      final sessionId = body['sessionId']?.toString() ?? op.aggregateId;
      await _moneyAccountRepository.closeSession(
        sessionId,
        body,
        remoteOnly: true,
      );
      await _salesService.queue.markSynced(op.operationId, 'synced');
      outcome.synced++;
      return _DeliveryResult.continue_;
    } on ValidationException catch (error) {
      await _conflict(op, outcome, 'VALIDATION', error.message);
      return _DeliveryResult.continue_;
    } on UnauthorizedException {
      await _salesService.releaseUnattempted(op.operationId);
      outcome.pausedForSession = true;
      return _DeliveryResult.stop;
    } on ForbiddenException catch (error) {
      await _fail(op, outcome, 'PERMISSION', error.message);
      return _DeliveryResult.continue_;
    } on NetworkException {
      await _retryLater(op, outcome);
      outcome.wentOffline = true;
      return _DeliveryResult.stop;
    } on TimeoutException {
      await _retryLater(op, outcome);
      return _DeliveryResult.stop;
    } on ServerException {
      await _retryLater(op, outcome);
      return _DeliveryResult.continue_;
    } catch (e) {
      await _fail(op, outcome, 'UNKNOWN_ERROR', e.toString());
      return _DeliveryResult.continue_;
    }
  }

  Future<_DeliveryResult> _deliverInventoryAdjustment(
    QueuedOperation op,
    SyncOutcome outcome,
  ) async {
    if (_inventoryRepository == null) {
      await _retryLater(op, outcome);
      return _DeliveryResult.continue_;
    }
    try {
      final body = jsonDecode(op.payload) as Map<String, dynamic>;
      final quantity =
          (body['quantityDelta'] ?? body['adjustmentQuantity'] as num?)
                  ?.toDouble() ??
              0.0;
      final reasonText = body['reason']?.toString() ?? 'Inbound Receiving';
      final notesText = body['notes']?.toString();
      final combinedReason = (notesText != null && notesText.trim().isNotEmpty)
          ? '$reasonText - $notesText'
          : reasonText;

      final entry = AdjustStockEntry(
        productId: body['productId']?.toString() ?? '',
        warehouseId: body['warehouseId']?.toString() ?? '',
        quantityDelta: quantity,
        reason: combinedReason,
        idempotencyKey: op.operationId,
      );

      await _inventoryRepository.adjustStock(entry, remoteOnly: true);
      await _salesService.queue.markSynced(op.operationId, 'synced');
      outcome.synced++;
      return _DeliveryResult.continue_;
    } on ValidationException catch (error) {
      await _conflict(op, outcome, 'VALIDATION', error.message);
      return _DeliveryResult.continue_;
    } on UnauthorizedException {
      await _salesService.releaseUnattempted(op.operationId);
      outcome.pausedForSession = true;
      return _DeliveryResult.stop;
    } on ForbiddenException catch (error) {
      await _fail(op, outcome, 'PERMISSION', error.message);
      return _DeliveryResult.continue_;
    } on NetworkException {
      await _retryLater(op, outcome);
      outcome.wentOffline = true;
      return _DeliveryResult.stop;
    } on TimeoutException {
      await _retryLater(op, outcome);
      return _DeliveryResult.stop;
    } on ServerException {
      await _retryLater(op, outcome);
      return _DeliveryResult.continue_;
    } catch (e) {
      await _fail(op, outcome, 'UNKNOWN_ERROR', e.toString());
      return _DeliveryResult.continue_;
    }
  }

  Future<_DeliveryResult> _deliverProductCreate(
    QueuedOperation op,
    SyncOutcome outcome,
  ) async {
    if (_productRepository == null) {
      await _retryLater(op, outcome);
      return _DeliveryResult.continue_;
    }
    try {
      final body = jsonDecode(op.payload) as Map<String, dynamic>;
      final draft = ProductDraft(
        name: body['name'] as String? ?? '',
        unitOfMeasureId: body['unitOfMeasureId'] as String? ?? '',
        description: body['description'] as String?,
        sku: body['sku'] as String?,
        barcode: body['barcode'] as String?,
        categoryId: body['categoryId'] as String?,
        brandId: body['brandId'] as String?,
        taxCategoryId: body['taxCategoryId'] as String?,
        costPrice: (body['costPrice'] as num?)?.toDouble(),
      );
      final result = await _productRepository.create(draft, remoteOnly: true);
      final tenantId = op.tenantId;
      await _salesService.catalog.remapProductId(
        tenantId: tenantId,
        localProductId: op.aggregateId,
        serverProductId: result.id,
      );
      await _salesService.queue.remapProductId(
        localProductId: op.aggregateId,
        serverProductId: result.id,
      );
      await _salesService.queue.markSynced(op.operationId, result.id);
      outcome.synced++;
      return _DeliveryResult.continue_;
    } on ValidationException catch (error) {
      await _conflict(op, outcome, 'VALIDATION', error.message);
      return _DeliveryResult.continue_;
    } on UnauthorizedException {
      await _salesService.releaseUnattempted(op.operationId);
      outcome.pausedForSession = true;
      return _DeliveryResult.stop;
    } on ForbiddenException catch (error) {
      await _fail(op, outcome, 'PERMISSION', error.message);
      return _DeliveryResult.continue_;
    } on NetworkException {
      await _retryLater(op, outcome);
      outcome.wentOffline = true;
      return _DeliveryResult.stop;
    } on TimeoutException {
      await _retryLater(op, outcome);
      return _DeliveryResult.stop;
    } on ServerException {
      await _retryLater(op, outcome);
      return _DeliveryResult.continue_;
    } catch (e) {
      await _fail(op, outcome, 'UNKNOWN_ERROR', e.toString());
      return _DeliveryResult.continue_;
    }
  }

  Future<_DeliveryResult> _deliverProductUpdate(
    QueuedOperation op,
    SyncOutcome outcome,
  ) async {
    if (_productRepository == null) {
      await _retryLater(op, outcome);
      return _DeliveryResult.continue_;
    }
    try {
      final body = jsonDecode(op.payload) as Map<String, dynamic>;
      final id = body['id'] as String? ?? op.aggregateId;
      final draft = ProductDraft(
        name: body['name'] as String? ?? '',
        unitOfMeasureId: body['unitOfMeasureId'] as String? ?? '',
        description: body['description'] as String?,
        sku: body['sku'] as String?,
        barcode: body['barcode'] as String?,
        categoryId: body['categoryId'] as String?,
        brandId: body['brandId'] as String?,
        taxCategoryId: body['taxCategoryId'] as String?,
        costPrice: (body['costPrice'] as num?)?.toDouble(),
      );
      await _productRepository.update(id, draft, remoteOnly: true);
      await _salesService.queue.markSynced(op.operationId, id);
      outcome.synced++;
      return _DeliveryResult.continue_;
    } on ValidationException catch (error) {
      await _conflict(op, outcome, 'VALIDATION', error.message);
      return _DeliveryResult.continue_;
    } on UnauthorizedException {
      await _salesService.releaseUnattempted(op.operationId);
      outcome.pausedForSession = true;
      return _DeliveryResult.stop;
    } on ForbiddenException catch (error) {
      await _fail(op, outcome, 'PERMISSION', error.message);
      return _DeliveryResult.continue_;
    } on NetworkException {
      await _retryLater(op, outcome);
      outcome.wentOffline = true;
      return _DeliveryResult.stop;
    } on TimeoutException {
      await _retryLater(op, outcome);
      return _DeliveryResult.stop;
    } on ServerException {
      await _retryLater(op, outcome);
      return _DeliveryResult.continue_;
    } catch (e) {
      await _fail(op, outcome, 'UNKNOWN_ERROR', e.toString());
      return _DeliveryResult.continue_;
    }
  }

  Future<_DeliveryResult> _deliverProductPriceSet(
    QueuedOperation op,
    SyncOutcome outcome,
  ) async {
    if (_productRepository == null) {
      await _retryLater(op, outcome);
      return _DeliveryResult.continue_;
    }
    try {
      final body = jsonDecode(op.payload) as Map<String, dynamic>;
      final priceListId = body['priceListId'] as String? ?? 'default';
      final productId = body['productId'] as String? ?? op.aggregateId;
      final price = (body['price'] as num?)?.toDouble() ?? 0.0;
      final priceType = (body['priceType'] as num?)?.toInt() ?? 0;

      final priceList = await _productRepository.defaultPriceList() ??
          PriceList(
            id: priceListId,
            name: 'Retail',
            currency: 'TZS',
            isDefault: true,
          );

      await _productRepository.setSellingPrice(
        priceList: priceList,
        productId: productId,
        price: price,
        priceType: priceType,
        remoteOnly: true,
      );
      await _salesService.queue.markSynced(op.operationId, 'synced');
      outcome.synced++;
      return _DeliveryResult.continue_;
    } on ValidationException catch (error) {
      await _conflict(op, outcome, 'VALIDATION', error.message);
      return _DeliveryResult.continue_;
    } on UnauthorizedException {
      await _salesService.releaseUnattempted(op.operationId);
      outcome.pausedForSession = true;
      return _DeliveryResult.stop;
    } on ForbiddenException catch (error) {
      await _fail(op, outcome, 'PERMISSION', error.message);
      return _DeliveryResult.continue_;
    } on NetworkException {
      await _retryLater(op, outcome);
      outcome.wentOffline = true;
      return _DeliveryResult.stop;
    } on TimeoutException {
      await _retryLater(op, outcome);
      return _DeliveryResult.stop;
    } on ServerException {
      await _retryLater(op, outcome);
      return _DeliveryResult.continue_;
    } catch (e) {
      await _fail(op, outcome, 'UNKNOWN_ERROR', e.toString());
      return _DeliveryResult.continue_;
    }
  }

  Future<_DeliveryResult> _deliverSupplierCreate(
    QueuedOperation op,
    SyncOutcome outcome,
  ) async {
    if (_supplierRepository == null) {
      await _retryLater(op, outcome);
      return _DeliveryResult.continue_;
    }
    try {
      final body = jsonDecode(op.payload) as Map<String, dynamic>;
      final result = await _supplierRepository.create(body, remoteOnly: true);
      await _salesService.queue.markSynced(
        op.operationId,
        (result['id'] as String?) ?? 'synced',
      );
      outcome.synced++;
      return _DeliveryResult.continue_;
    } on ValidationException catch (error) {
      await _conflict(op, outcome, 'VALIDATION', error.message);
      return _DeliveryResult.continue_;
    } on UnauthorizedException {
      await _salesService.releaseUnattempted(op.operationId);
      outcome.pausedForSession = true;
      return _DeliveryResult.stop;
    } on ForbiddenException catch (error) {
      await _fail(op, outcome, 'PERMISSION', error.message);
      return _DeliveryResult.continue_;
    } on NetworkException {
      await _retryLater(op, outcome);
      outcome.wentOffline = true;
      return _DeliveryResult.stop;
    } on TimeoutException {
      await _retryLater(op, outcome);
      return _DeliveryResult.stop;
    } on ServerException {
      await _retryLater(op, outcome);
      return _DeliveryResult.continue_;
    } catch (e) {
      await _fail(op, outcome, 'UNKNOWN_ERROR', e.toString());
      return _DeliveryResult.continue_;
    }
  }

  Future<_DeliveryResult> _deliverSupplierUpdate(
    QueuedOperation op,
    SyncOutcome outcome,
  ) async {
    if (_supplierRepository == null) {
      await _retryLater(op, outcome);
      return _DeliveryResult.continue_;
    }
    try {
      final body = jsonDecode(op.payload) as Map<String, dynamic>;
      final id = (body['id'] as String?) ?? op.aggregateId;
      final payload = Map<String, dynamic>.from(body)..remove('id');
      await _supplierRepository.update(id, payload, remoteOnly: true);
      await _salesService.queue.markSynced(op.operationId, 'synced');
      outcome.synced++;
      return _DeliveryResult.continue_;
    } on ValidationException catch (error) {
      await _conflict(op, outcome, 'VALIDATION', error.message);
      return _DeliveryResult.continue_;
    } on UnauthorizedException {
      await _salesService.releaseUnattempted(op.operationId);
      outcome.pausedForSession = true;
      return _DeliveryResult.stop;
    } on ForbiddenException catch (error) {
      await _fail(op, outcome, 'PERMISSION', error.message);
      return _DeliveryResult.continue_;
    } on NetworkException {
      await _retryLater(op, outcome);
      outcome.wentOffline = true;
      return _DeliveryResult.stop;
    } on TimeoutException {
      await _retryLater(op, outcome);
      return _DeliveryResult.stop;
    } on ServerException {
      await _retryLater(op, outcome);
      return _DeliveryResult.continue_;
    } catch (e) {
      await _fail(op, outcome, 'UNKNOWN_ERROR', e.toString());
      return _DeliveryResult.continue_;
    }
  }

  Future<_DeliveryResult> _deliverPurchaseCreate(
    QueuedOperation op,
    SyncOutcome outcome,
  ) async {
    if (_purchaseRepository == null) {
      await _retryLater(op, outcome);
      return _DeliveryResult.continue_;
    }
    try {
      final body = jsonDecode(op.payload) as Map<String, dynamic>;
      await _purchaseRepository.create(body, remoteOnly: true);
      await _salesService.queue.markSynced(op.operationId, 'synced');
      outcome.synced++;
      return _DeliveryResult.continue_;
    } on ValidationException catch (error) {
      await _conflict(op, outcome, 'VALIDATION', error.message);
      return _DeliveryResult.continue_;
    } on UnauthorizedException {
      await _salesService.releaseUnattempted(op.operationId);
      outcome.pausedForSession = true;
      return _DeliveryResult.stop;
    } on ForbiddenException catch (error) {
      await _fail(op, outcome, 'PERMISSION', error.message);
      return _DeliveryResult.continue_;
    } on NetworkException {
      await _retryLater(op, outcome);
      outcome.wentOffline = true;
      return _DeliveryResult.stop;
    } on TimeoutException {
      await _retryLater(op, outcome);
      return _DeliveryResult.stop;
    } on ServerException {
      await _retryLater(op, outcome);
      return _DeliveryResult.continue_;
    } catch (e) {
      await _fail(op, outcome, 'UNKNOWN_ERROR', e.toString());
      return _DeliveryResult.continue_;
    }
  }

  Future<void> _conflict(
    QueuedOperation op,
    SyncOutcome outcome,
    String code,
    String message,
  ) async {
    debugPrint('sync conflict ${op.operationId}: $code');
    if (op.operationType == 'sale.create') {
      await _salesService.markSaleConflict(
        clientSaleId: op.aggregateId,
        errorCode: code,
        errorMessage: message,
      );
    } else {
      await _salesService.queue.markConflict(
        op.operationId,
        errorCode: code,
        errorMessage: message,
      );
    }
    outcome.conflicted++;
  }

  Future<void> _fail(
    QueuedOperation op,
    SyncOutcome outcome,
    String code,
    String message,
  ) async {
    await _salesService.markQueueFailed(
      op.operationId,
      errorCode: code,
      errorMessage: message,
    );
    if (op.operationType == 'sale.create') {
      await _salesService.markSaleConflictOnly(
        clientSaleId: op.aggregateId,
        errorCode: code,
        errorMessage: message,
      );
    }
    outcome.failed++;
  }

  Future<void> _retryLater(QueuedOperation op, SyncOutcome outcome) async {
    await _salesService.releaseForRetry(
      op.operationId,
      attemptCount: op.attemptCount,
    );
    outcome.retriedLater++;
  }
}

enum _DeliveryResult { continue_, stop }
