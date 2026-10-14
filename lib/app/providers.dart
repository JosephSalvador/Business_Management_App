import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/authentication/application/auth_controller.dart';
import '../features/authentication/data/auth_providers.dart';
import '../features/billing/application/billing_providers.dart';
import '../features/capabilities/application/capabilities_controller.dart';
import '../features/finance/data/expense_providers.dart';
import '../features/finance/data/money_account_providers.dart';
import '../features/inventory/data/inventory_providers.dart';
import '../features/onboarding/data/workspace_providers.dart';
import '../features/products/data/product_providers.dart';
import '../features/profile/data/profile_providers.dart';
import '../features/sales/data/sales_providers.dart';
import '../features/suppliers/data/supplier_providers.dart';
import '../features/users/data/user_providers.dart';

export '../core/di/core_providers.dart'
    show
        appConfigProvider,
        tokenStoreProvider,
        localDatabaseProvider,
        dbKeyStoreProvider,
        deviceIdentityProvider,
        sessionJournalProvider,
        localSalesServiceProvider,
        offlineCredentialStoreProvider,
        biometricAuthGateProvider,
        branchCacheProvider,
        appLockPolicyProvider;
export '../features/authentication/data/auth_providers.dart';
export '../features/billing/application/billing_providers.dart';
export '../features/billing/data/billing_providers.dart';
export '../features/capabilities/application/capabilities_controller.dart';
export '../features/capabilities/data/capabilities_providers.dart';
export '../features/customers/data/customer_providers.dart';
export '../features/dashboard/data/dashboard_providers.dart';
export '../features/finance/data/expense_providers.dart';
export '../features/finance/data/money_account_providers.dart';
export '../features/inventory/data/inventory_providers.dart';
export '../features/onboarding/data/workspace_providers.dart';
export '../features/products/data/product_providers.dart';
export '../features/profile/data/profile_providers.dart';
export '../features/purchases/data/purchase_providers.dart';
export '../features/reports/data/report_providers.dart';
export '../features/roles/data/role_providers.dart';
export '../features/sales/data/sales_providers.dart';
export '../features/settings/data/organization_providers.dart';
export '../features/suppliers/data/supplier_providers.dart';
export '../features/users/data/user_providers.dart';
export '../features/receipts/data/receipt_providers.dart';
export '../core/storage/printer_store.dart';
export '../core/storage/receipt_cache.dart';

import '../core/services/startup_warmup_service.dart';

/// Wires the workspace journey to the auth lifecycle: loading starts on
/// login and state resets on logout/session expiry. Watched by the router so
/// it is alive for the whole session.
final workspaceJourneyBindingProvider = Provider<void>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  apiClient.onPaymentRequired = () async {
    await ref.read(capabilitiesStateProvider.notifier).refresh();
  };

  ref.listen<AuthState>(authControllerProvider, (_, next) {
    final controller = ref.read(workspaceControllerProvider.notifier);
    if (next is AuthAuthenticated) {
      controller.load();
      // Trigger background warmup pipeline (optimistic prefetch, outbox sync)
      ref.read(startupWarmupServiceProvider).warmUp(isOffline: next.isOffline);
    } else if (next is AuthLocked) {
      // Non-destructive idle/background lock: keep every controller state
      // (cart, history, forms) so unlock resumes exactly where the user left.
    } else {
      controller.reset();
      ref.read(productsControllerProvider.notifier).reset();
      ref.read(stockControllerProvider.notifier).reset();
      ref.read(catalogControllerProvider.notifier).reset();
      ref.read(cartControllerProvider.notifier).clear();
      ref.read(checkoutControllerProvider.notifier).reset();
      ref.read(salesHistoryControllerProvider.notifier).reset();
      ref.read(suppliersControllerProvider.notifier).reset();
      ref.read(usersControllerProvider.notifier).reset();
      ref.read(profileControllerProvider.notifier).reset();
      ref.read(expensesControllerProvider.notifier).reset();
      ref.read(moneyAccountsControllerProvider.notifier).reset();
      ref.read(cashSessionControllerProvider.notifier).reset();
      ref.read(billingControllerProvider.notifier).reset();
      ref.read(subscriptionEntitlementControllerProvider.notifier).reset();
      ref.read(capabilitiesStateProvider.notifier).reset();
    }
  });
});
