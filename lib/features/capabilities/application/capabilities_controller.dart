import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../billing/application/billing_providers.dart';
import '../../billing/domain/billing.dart';
import '../../sales/data/sales_providers.dart' show sessionContextProvider;
import '../data/capabilities_providers.dart';
import '../data/capabilities_repository.dart';
import '../domain/capabilities.dart';

class CapabilitiesState {
  const CapabilitiesState({
    this.source = CapabilitiesSource.fallback,
    this.isLoading = false,
    this.message,
  });

  final CapabilitiesSource source;
  final bool isLoading;
  final String? message;

  bool get isStale => source == CapabilitiesSource.cache;
}

class CapabilitiesController extends Notifier<CapabilitiesState> {
  Future<void>? _refreshInFlight;
  int _revision = 0;

  @override
  CapabilitiesState build() => const CapabilitiesState();

  CapabilitiesRepository get _repository =>
      ref.read(capabilitiesRepositoryProvider);

  String? get _tenantId => ref.read(sessionContextProvider).$1;

  void restoreFromCache() {
    final tenantId = _tenantId;
    if (tenantId == null) return;
    final revision = _revision;
    _repository.loadCached(tenantId).then((cached) {
      if (cached == null || revision != _revision) return;
      ref
          .read(subscriptionEntitlementControllerProvider.notifier)
          .setEntitlement(cached);
      state = const CapabilitiesState(source: CapabilitiesSource.cache);
    });
  }

  Future<void> refresh() async {
    final tenantId = _tenantId;
    if (tenantId == null) return;
    final active = _refreshInFlight;
    if (active != null) {
      await active;
      return;
    }
    final revision = _revision;
    final request = _refresh(tenantId);
    _refreshInFlight = request;
    try {
      await request;
    } finally {
      if (identical(_refreshInFlight, request)) {
        _refreshInFlight = null;
      }
      if (revision == _revision) {
        state = CapabilitiesState(
          source: state.source,
          isLoading: false,
          message: state.message,
        );
      }
    }
  }

  Future<void> _refresh(String tenantId) async {
    final revision = _revision;
    state = CapabilitiesState(
      source: state.source,
      isLoading: true,
      message: null,
    );
    try {
      final entitlement = await _repository.fetchAndCache(tenantId);
      if (revision != _revision) return;
      ref
          .read(subscriptionEntitlementControllerProvider.notifier)
          .setEntitlement(entitlement);
      state = const CapabilitiesState(source: CapabilitiesSource.network);
    } on Object {
      if (revision != _revision) return;
      final cached = await _repository.loadCached(tenantId);
      if (revision != _revision) return;
      if (cached != null) {
        ref
            .read(subscriptionEntitlementControllerProvider.notifier)
            .setEntitlement(cached);
        state = const CapabilitiesState(source: CapabilitiesSource.cache);
        return;
      }
      state = const CapabilitiesState(
        source: CapabilitiesSource.fallback,
        message: 'Haiwezi kupata maelekezo ya mfumo.',
      );
    }
  }

  void onBillingRequired() => refresh();

  void reset() {
    _revision++;
    _refreshInFlight = null;
    state = const CapabilitiesState();
  }
}

final enabledModulesProvider = Provider<Set<WorkspaceModule>>((ref) {
  final entitlement = ref.watch(subscriptionEntitlementControllerProvider);
  if (entitlement == null) {
    return {
      for (final module in WorkspaceModule.values)
        if (module.isBackstop) module,
    };
  }
  return {
    for (final module in WorkspaceModule.values)
      if (entitlement.hasFeature(module.featureKey)) module,
  };
});

final isModuleEnabledProvider =
    Provider.family<bool, WorkspaceModule>((ref, module) {
  return ref.watch(enabledModulesProvider).contains(module);
});

final invoicingModuleEnabledProvider = Provider<bool>((ref) {
  return ref.watch(isModuleEnabledProvider(WorkspaceModule.invoicing));
});

final capabilitiesStateProvider =
    NotifierProvider<CapabilitiesController, CapabilitiesState>(
  CapabilitiesController.new,
);

final capabilityKeyProvider = Provider.family<bool, String>((ref, key) {
  final entitlement = ref.watch(subscriptionEntitlementControllerProvider);
  if (entitlement == null) {
    return key == BillingFeatureKeys.pos || key == BillingFeatureKeys.inventory;
  }
  return entitlement.hasFeature(key);
});
