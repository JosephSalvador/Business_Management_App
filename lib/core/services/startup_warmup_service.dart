import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/billing/application/billing_providers.dart';
import '../../features/capabilities/application/capabilities_controller.dart';
import '../../features/products/data/product_providers.dart';
import '../../features/sales/data/sales_providers.dart';

/// Pre-warms essential caches and synchronizes offline outbox in the background
/// immediately upon successful authentication so the user experiences zero lag.
class StartupWarmupService {
  StartupWarmupService(this._ref);

  final Ref _ref;

  /// Runs background warmup tasks silently without blocking UI transitions.
  void warmUp({required bool isOffline}) {
    unawaited(_runWarmup(isOffline: isOffline));
  }

  Future<void> _runWarmup({required bool isOffline}) async {
    // 1. Warm POS Branch ID cache if needed
    try {
      final fetchBranch = _ref.read(posBranchIdProvider);
      await fetchBranch();
    } catch (e) {
      debugPrint('StartupWarmup: Branch cache warmup skipped: $e');
    }

    if (!isOffline) {
      // 2. Pre-fetch product catalog reference data (units, taxes, warehouses)
      try {
        await _ref.read(catalogControllerProvider.notifier).load();
      } catch (e) {
        debugPrint('StartupWarmup: Catalog warmup skipped: $e');
      }

      // 3. Pre-fetch POS products list
      try {
        await _ref.read(posCatalogControllerProvider.notifier).load();
      } catch (e) {
        debugPrint('StartupWarmup: POS catalog warmup skipped: $e');
      }

      // 4. Trigger sync engine drain if online
      try {
        final syncEngine = _ref.read(syncEngineProvider);
        await syncEngine.drain();
      } catch (e) {
        debugPrint('StartupWarmup: Sync drain skipped: $e');
      }

      // 5. Refresh entitlements & capabilities in background
      try {
        await _ref.read(capabilitiesStateProvider.notifier).refresh();
        await _ref
            .read(subscriptionEntitlementControllerProvider.notifier)
            .refresh();
      } catch (e) {
        debugPrint('StartupWarmup: Entitlements warmup skipped: $e');
      }
    } else {
      // Offline mode: restore cached capabilities & local sync status
      try {
        _ref.read(capabilitiesStateProvider.notifier).restoreFromCache();
        await _ref.read(syncStatusProvider.notifier).refresh();
        await _ref.read(posCatalogControllerProvider.notifier).load();
      } catch (e) {
        debugPrint('StartupWarmup: Offline restore skipped: $e');
      }
    }
  }
}

final startupWarmupServiceProvider = Provider<StartupWarmupService>((ref) {
  return StartupWarmupService(ref);
});
