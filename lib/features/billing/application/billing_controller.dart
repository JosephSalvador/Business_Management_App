import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../data/billing_providers.dart';
import '../data/billing_repository.dart';
import '../domain/billing.dart';
import 'billing_providers.dart';

class BillingState {
  const BillingState({
    this.entitlement,
    this.plans = const [],
    this.invoices = const [],
    this.isLoading = false,
    this.isWorking = false,
    this.message,
  });

  final SubscriptionEntitlement? entitlement;
  final List<BillingPlan> plans;
  final List<BillingInvoice> invoices;
  final bool isLoading;
  final bool isWorking;
  final String? message;

  bool get hasData => entitlement != null;
}

class BillingController extends Notifier<BillingState> {
  static const _notProvided = Object();

  Future<void>? _loadInFlight;
  Future<void>? _actionInFlight;
  int _revision = 0;

  @override
  BillingState build() => const BillingState();

  BillingRepository get _repository => ref.read(billingRepositoryProvider);

  Future<void> load() async {
    if (state.isWorking) return;
    final active = _loadInFlight;
    if (active != null) {
      await active;
      return;
    }
    if (_actionInFlight != null) return;
    final request = _load();
    _loadInFlight = request;
    try {
      await request;
    } finally {
      if (identical(_loadInFlight, request)) {
        _loadInFlight = null;
      }
    }
  }

  Future<void> _load() async {
    final revision = _revision;
    final previous = state;
    state = _copyState(previous, isLoading: true, message: null);
    SubscriptionEntitlement? entitlement;
    try {
      entitlement = await _repository.getSubscription();
      if (revision != _revision) return;
      _setGlobalEntitlement(entitlement);
      final plans = await _repository.listPlans();
      final invoices = await _repository.listInvoices();
      if (revision != _revision) return;
      state = BillingState(
        entitlement: entitlement,
        plans: plans,
        invoices: invoices,
      );
    } on AppException catch (error) {
      if (revision != _revision) return;
      state = _copyState(
        previous,
        entitlement: entitlement,
        message: error.message,
      );
    }
  }

  Future<void> evaluateSubscription() => _runAction(_evaluateSubscription);

  Future<void> _evaluateSubscription() async {
    final revision = _revision;
    final previous = state;
    state = _copyState(previous, isWorking: true, message: null);
    SubscriptionEntitlement? entitlement;
    try {
      entitlement = await _repository.evaluateSubscription();
      if (revision != _revision) return;
      _setGlobalEntitlement(entitlement);
      final invoices = await _repository.listInvoices();
      if (revision != _revision) return;
      state = BillingState(
        entitlement: entitlement,
        plans: previous.plans,
        invoices: invoices,
      );
    } on AppException catch (error) {
      if (revision != _revision) return;
      state = _copyState(
        previous,
        entitlement: entitlement,
        message: error.message,
      );
    }
  }

  Future<void> redeemVoucher(String code) {
    final normalized = VoucherCode.normalize(code);
    if (normalized.isEmpty) return Future<void>.value();
    return _runAction(() => _redeemVoucher(normalized));
  }

  Future<void> _redeemVoucher(String code) async {
    final revision = _revision;
    final previous = state;
    state = _copyState(previous, isWorking: true, message: null);
    SubscriptionEntitlement? entitlement;
    try {
      entitlement = await _repository.redeemVoucher(code);
      if (revision != _revision) return;
      _setGlobalEntitlement(entitlement);
      final invoices = await _repository.listInvoices();
      if (revision != _revision) return;
      state = BillingState(
        entitlement: entitlement,
        plans: previous.plans,
        invoices: invoices,
      );
    } on AppException catch (error) {
      if (revision != _revision) return;
      state = _copyState(
        previous,
        entitlement: entitlement,
        message: error.message,
      );
    }
  }

  Future<void> activatePackage(String planCode) {
    final code = planCode.trim();
    if (code.isEmpty || state.isWorking) return Future<void>.value();
    return _runAction(
        () => _changePackage(() => _repository.activatePackage(code)));
  }

  Future<void> removePackage(String planCode) {
    final code = planCode.trim();
    if (code.isEmpty || state.isWorking) return Future<void>.value();
    return _runAction(
        () => _changePackage(() => _repository.removePackage(code)));
  }

  Future<void> _changePackage(Future<List<String>> Function() request) async {
    final revision = _revision;
    final previous = state;
    state = _copyState(previous, isWorking: true, message: null);
    SubscriptionEntitlement? entitlement;
    try {
      await request();
      entitlement = await _repository.getSubscription();
      if (revision != _revision) return;
      _setGlobalEntitlement(entitlement);
      state = BillingState(
        entitlement: entitlement,
        plans: previous.plans,
        invoices: previous.invoices,
      );
    } on AppException catch (error) {
      if (revision != _revision) return;
      state = _copyState(
        previous,
        entitlement: entitlement,
        message: error.message,
      );
    }
  }

  Future<BillingInvoice?> loadInvoice(String invoiceId) async {
    final revision = _revision;
    try {
      final invoice = await _repository.getInvoice(invoiceId);
      if (revision != _revision) return null;
      return invoice;
    } on AppException catch (error) {
      if (revision == _revision) {
        state = _copyState(state, message: error.message);
      }
      return null;
    }
  }

  Future<void> _runAction(Future<void> Function() action) async {
    final active = _actionInFlight;
    if (active != null) {
      await active;
      return;
    }
    if (_loadInFlight != null) return;
    final request = action();
    _actionInFlight = request;
    try {
      await request;
    } finally {
      if (identical(_actionInFlight, request)) {
        _actionInFlight = null;
      }
    }
  }

  void clearMessage() {
    state = _copyState(state, message: null);
  }

  void reset() {
    _revision++;
    _loadInFlight = null;
    _actionInFlight = null;
    state = const BillingState();
  }

  void _setGlobalEntitlement(SubscriptionEntitlement entitlement) {
    ref
        .read(subscriptionEntitlementControllerProvider.notifier)
        .setEntitlement(entitlement);
  }

  BillingState _copyState(
    BillingState source, {
    SubscriptionEntitlement? entitlement,
    bool? isLoading,
    bool? isWorking,
    Object? message = _notProvided,
  }) {
    final nextMessage =
        identical(message, _notProvided) ? source.message : message as String?;
    return BillingState(
      entitlement: entitlement ?? source.entitlement,
      plans: source.plans,
      invoices: source.invoices,
      isLoading: isLoading ?? source.isLoading,
      isWorking: isWorking ?? source.isWorking,
      message: nextMessage,
    );
  }
}

class SubscriptionEntitlementController
    extends Notifier<SubscriptionEntitlement?> {
  Future<void>? _refreshInFlight;
  int _revision = 0;

  @override
  SubscriptionEntitlement? build() => null;

  BillingRepository get _repository => ref.read(billingRepositoryProvider);

  Future<void> refresh() async {
    final active = _refreshInFlight;
    if (active != null) {
      await active;
      return;
    }
    final revision = _revision;
    final request = _refresh();
    _refreshInFlight = request;
    try {
      final entitlement = await request;
      if (entitlement != null && revision == _revision) {
        state = entitlement;
      }
    } finally {
      if (identical(_refreshInFlight, request)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<SubscriptionEntitlement?> _refresh() async {
    try {
      return await _repository.getSubscription();
    } on AppException {
      return null;
    }
  }

  void setEntitlement(SubscriptionEntitlement entitlement) {
    _revision++;
    state = entitlement;
  }

  void reset() {
    _revision++;
    _refreshInFlight = null;
    state = null;
  }
}
