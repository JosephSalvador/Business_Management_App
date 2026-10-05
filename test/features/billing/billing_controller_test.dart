import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/features/billing/application/billing_providers.dart';
import 'package:jolinx_app/features/billing/data/billing_providers.dart';
import 'package:jolinx_app/features/billing/data/billing_repository.dart';
import 'package:jolinx_app/features/billing/domain/billing.dart';

SubscriptionEntitlement sampleEntitlement({
  SubscriptionStatus status = SubscriptionStatus.active,
  BillingAccessLevel accessLevel = BillingAccessLevel.full,
  Set<String> keys = const {
    BillingFeatureKeys.pos,
    BillingFeatureKeys.inventory,
    BillingFeatureKeys.finance,
    BillingFeatureKeys.accounting,
  },
}) =>
    SubscriptionEntitlement(
      status: status,
      accessLevel: accessLevel,
      planCode: 'pro',
      effectiveFeatureKeys: keys,
      nextDueUtc: null,
      hasOpenInvoice: false,
      maxBranches: null,
      maxUsers: null,
      maxProducts: null,
      evaluatedAtUtc: DateTime.utc(2026, 9, 25, 10),
    );

class FakeBillingRepository implements BillingRepository {
  FakeBillingRepository({SubscriptionEntitlement? initial})
      : entitlement = initial ?? sampleEntitlement();

  SubscriptionEntitlement entitlement;
  Object? subscriptionError;
  int getSubscriptionCalls = 0;
  int evaluateCalls = 0;
  String? lastRedeemedCode;

  @override
  Future<SubscriptionEntitlement> getSubscription() async {
    getSubscriptionCalls++;
    final error = subscriptionError;
    if (error != null) throw error;
    return entitlement;
  }

  @override
  Future<SubscriptionEntitlement> evaluateSubscription() async {
    evaluateCalls++;
    return entitlement;
  }

  @override
  Future<SubscriptionEntitlement> redeemVoucher(String code) async {
    lastRedeemedCode = code;
    return entitlement;
  }

  @override
  Future<List<BillingPlan>> listPlans() async => const [];

  @override
  Future<List<BillingInvoice>> listInvoices() async => const [];

  @override
  Future<BillingInvoice> getInvoice(String invoiceId) async =>
      throw UnimplementedError();

  @override
  Future<List<String>> activatePackage(String planCode) async =>
      throw UnimplementedError();

  @override
  Future<List<String>> removePackage(String planCode) async =>
      throw UnimplementedError();
}

ProviderContainer containerWith(FakeBillingRepository repository) {
  final container = ProviderContainer(
    overrides: [billingRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('BillingController load', () {
    test('populates state and publishes the global entitlement', () async {
      final repository = FakeBillingRepository();
      final container = containerWith(repository);

      await container.read(billingControllerProvider.notifier).load();

      final state = container.read(billingControllerProvider);
      expect(state.hasData, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.entitlement!.hasFeature(BillingFeatureKeys.finance), isTrue);

      final global = container.read(subscriptionEntitlementControllerProvider);
      expect(global, same(state.entitlement));
      expect(
        container
            .read(billingFeatureAccessProvider(BillingFeatureKeys.finance)),
        isTrue,
      );
      expect(container.read(fullBillingAccessProvider), isTrue);
    });

    test('is single-flight for concurrent loads', () async {
      final repository = FakeBillingRepository();
      final container = containerWith(repository);
      final controller = container.read(billingControllerProvider.notifier);

      await Future.wait([controller.load(), controller.load()]);

      expect(repository.getSubscriptionCalls, 1);
      expect(container.read(billingControllerProvider).hasData, isTrue);
    });

    test('surfaces a repository failure as the state message', () async {
      final repository = FakeBillingRepository()
        ..subscriptionError = NetworkException('no network');
      final container = containerWith(repository);

      await container.read(billingControllerProvider.notifier).load();

      final state = container.read(billingControllerProvider);
      expect(state.message, 'no network');
      expect(state.entitlement, isNull);
      expect(
        container.read(subscriptionEntitlementControllerProvider),
        isNull,
      );
    });
  });

  group('BillingController redeemVoucher', () {
    test('normalizes the code and publishes the new entitlement', () async {
      final repository = FakeBillingRepository();
      final container = containerWith(repository);

      await container.read(billingControllerProvider.notifier).load();
      await container
          .read(billingControllerProvider.notifier)
          .redeemVoucher('  abc-123 ');

      expect(repository.lastRedeemedCode, 'ABC-123');
      expect(
        container.read(subscriptionEntitlementControllerProvider),
        isNotNull,
      );
      expect(container.read(billingControllerProvider).message, isNull);
    });

    test('ignores a blank code without touching the repository', () async {
      final repository = FakeBillingRepository();
      final container = containerWith(repository);
      final controller = container.read(billingControllerProvider.notifier);
      await controller.load();

      await controller.redeemVoucher('   ');

      expect(repository.lastRedeemedCode, isNull);
      expect(repository.evaluateCalls, 0);
    });
  });

  group('billingFeatureAccessProvider', () {
    test('fails open to the backstop before any entitlement is loaded', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(billingFeatureAccessProvider(BillingFeatureKeys.pos)),
        isTrue,
      );
      expect(
        container.read(
          billingFeatureAccessProvider(BillingFeatureKeys.inventory),
        ),
        isTrue,
      );
      expect(
        container.read(
          billingFeatureAccessProvider(BillingFeatureKeys.finance),
        ),
        isFalse,
      );
      expect(container.read(fullBillingAccessProvider), isFalse);
      expect(container.read(knownSubscriptionDebtProvider), isFalse);
    });

    test('follows the loaded entitlement keys', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(subscriptionEntitlementControllerProvider.notifier)
          .setEntitlement(
            sampleEntitlement(
              status: SubscriptionStatus.debt,
              accessLevel: BillingAccessLevel.posAndInventory,
              keys: const {
                BillingFeatureKeys.pos,
                BillingFeatureKeys.inventory,
              },
            ),
          );

      expect(
        container.read(
          billingFeatureAccessProvider(BillingFeatureKeys.finance),
        ),
        isFalse,
      );
      expect(
        container.read(billingFeatureAccessProvider(BillingFeatureKeys.pos)),
        isTrue,
      );
      expect(container.read(fullBillingAccessProvider), isFalse);
      expect(container.read(knownSubscriptionDebtProvider), isTrue);
    });
  });

  group('SubscriptionEntitlementController', () {
    test('refresh replaces the entitlement and is single-flight', () async {
      final repository = FakeBillingRepository();
      final container = containerWith(repository);
      final controller =
          container.read(subscriptionEntitlementControllerProvider.notifier);

      await Future.wait([controller.refresh(), controller.refresh()]);

      expect(repository.getSubscriptionCalls, 1);
      expect(
          container.read(subscriptionEntitlementControllerProvider), isNotNull);
    });

    test('refresh keeps the previous entitlement on failure', () async {
      final repository = FakeBillingRepository();
      final container = containerWith(repository);
      final controller =
          container.read(subscriptionEntitlementControllerProvider.notifier);

      await controller.refresh();
      expect(
        container.read(subscriptionEntitlementControllerProvider),
        isNotNull,
      );

      repository.subscriptionError = NetworkException('offline');
      await controller.refresh();

      expect(
        container.read(subscriptionEntitlementControllerProvider),
        isNotNull,
      );
    });

    test('reset clears the entitlement', () async {
      final repository = FakeBillingRepository();
      final container = containerWith(repository);
      final controller =
          container.read(subscriptionEntitlementControllerProvider.notifier);

      await controller.refresh();
      controller.reset();

      expect(container.read(subscriptionEntitlementControllerProvider), isNull);
    });
  });
}
