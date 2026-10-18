import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/billing.dart';
import 'billing_controller.dart';

final billingControllerProvider =
    NotifierProvider<BillingController, BillingState>(BillingController.new);

final subscriptionEntitlementControllerProvider = NotifierProvider<
    SubscriptionEntitlementController, SubscriptionEntitlement?>(
  SubscriptionEntitlementController.new,
);

final knownSubscriptionDebtProvider = Provider<bool>((ref) {
  return ref.watch(subscriptionEntitlementControllerProvider)?.isInDebt ??
      false;
});

final fullBillingAccessProvider = Provider<bool>((ref) {
  return ref.watch(subscriptionEntitlementControllerProvider)?.hasFullAccess ??
      false;
});

final billingFeatureAccessProvider = Provider.family<bool, String>((ref, key) {
  final entitlement = ref.watch(subscriptionEntitlementControllerProvider);
  if (entitlement != null) return entitlement.hasFeature(key);
  return true;
});

final posFeatureAccessProvider = Provider<bool>((ref) {
  return ref.watch(billingFeatureAccessProvider(BillingFeatureKeys.pos));
});

final inventoryFeatureAccessProvider = Provider<bool>((ref) {
  return ref.watch(billingFeatureAccessProvider(BillingFeatureKeys.inventory));
});

final purchasingFeatureAccessProvider = Provider<bool>((ref) {
  return ref.watch(billingFeatureAccessProvider(BillingFeatureKeys.purchasing));
});

final accountingFeatureAccessProvider = Provider<bool>((ref) {
  return ref.watch(billingFeatureAccessProvider(BillingFeatureKeys.accounting));
});

final financeFeatureAccessProvider = Provider<bool>((ref) {
  return ref.watch(billingFeatureAccessProvider(BillingFeatureKeys.finance));
});

final crmFeatureAccessProvider = Provider<bool>((ref) {
  return ref.watch(billingFeatureAccessProvider(BillingFeatureKeys.crm));
});

final creditFeatureAccessProvider = Provider<bool>((ref) {
  return ref.watch(billingFeatureAccessProvider(BillingFeatureKeys.credit));
});

final reportsFeatureAccessProvider = Provider<bool>((ref) {
  return ref.watch(billingFeatureAccessProvider(BillingFeatureKeys.reports));
});

final multiBranchFeatureAccessProvider = Provider<bool>((ref) {
  return ref.watch(
    billingFeatureAccessProvider(BillingFeatureKeys.multiBranch),
  );
});
