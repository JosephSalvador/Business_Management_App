import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/features/billing/domain/billing.dart';

Map<String, dynamic> entitlementJson({
  Object status = 2,
  Object accessLevel = 1,
  Object? planCode = 'backstop',
  Object? effectiveFeatureKeys,
  Object? nextDueUtc = '2026-10-01T00:00:00Z',
  Object hasOpenInvoice = false,
  Object? maxBranches = 1,
  Object? maxUsers = 3,
  Object? maxProducts = 50,
  Object evaluatedAtUtc = '2026-09-25T10:00:00Z',
  bool omitEffectiveFeatureKeys = false,
}) {
  return {
    'status': status,
    'accessLevel': accessLevel,
    'planCode': planCode,
    if (!omitEffectiveFeatureKeys)
      'effectiveFeatureKeys':
          effectiveFeatureKeys ?? ['pos.enabled', 'inventory.enabled'],
    'nextDueUtc': nextDueUtc,
    'hasOpenInvoice': hasOpenInvoice,
    'maxBranches': maxBranches,
    'maxUsers': maxUsers,
    'maxProducts': maxProducts,
    'evaluatedAtUtc': evaluatedAtUtc,
  };
}

void main() {
  group('SubscriptionEntitlement.fromJson', () {
    test('parses a backstop (debt) entitlement', () {
      final entitlement = SubscriptionEntitlement.fromJson(entitlementJson());

      expect(entitlement.status, SubscriptionStatus.debt);
      expect(entitlement.accessLevel, BillingAccessLevel.posAndInventory);
      expect(entitlement.planCode, 'backstop');
      expect(entitlement.hasFullAccess, isFalse);
      expect(entitlement.isInDebt, isTrue);
      expect(entitlement.hasFeature(BillingFeatureKeys.pos), isTrue);
      expect(entitlement.hasFeature(BillingFeatureKeys.inventory), isTrue);
      expect(entitlement.hasFeature(BillingFeatureKeys.finance), isFalse);
      expect(entitlement.maxBranches, 1);
      expect(entitlement.maxUsers, 3);
      expect(entitlement.maxProducts, 50);
      expect(entitlement.hasOpenInvoice, isFalse);
      expect(entitlement.nextDueUtc, isNotNull);
      expect(entitlement.nextDueUtc!.isUtc, isTrue);
      expect(entitlement.evaluatedAtUtc.isUtc, isTrue);
    });

    test('parses a full (active) entitlement with finance unlocked', () {
      final entitlement = SubscriptionEntitlement.fromJson(
        entitlementJson(
          status: 1,
          accessLevel: 0,
          planCode: 'pro',
          effectiveFeatureKeys: [
            BillingFeatureKeys.pos,
            BillingFeatureKeys.inventory,
            BillingFeatureKeys.finance,
            BillingFeatureKeys.accounting,
            BillingFeatureKeys.reports,
          ],
          nextDueUtc: null,
          maxBranches: null,
          maxUsers: null,
          maxProducts: null,
        ),
      );

      expect(entitlement.status, SubscriptionStatus.active);
      expect(entitlement.accessLevel, BillingAccessLevel.full);
      expect(entitlement.hasFullAccess, isTrue);
      expect(entitlement.isInDebt, isFalse);
      expect(entitlement.hasFeature(BillingFeatureKeys.finance), isTrue);
      expect(entitlement.hasFeature(BillingFeatureKeys.accounting), isTrue);
      expect(entitlement.maxBranches, isNull);
      expect(entitlement.nextDueUtc, isNull);
    });

    test('rejects an unknown status code', () {
      expect(
        () => SubscriptionEntitlement.fromJson(entitlementJson(status: 9)),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a non-integer status code', () {
      expect(
        () => SubscriptionEntitlement.fromJson(entitlementJson(status: '2')),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects an unknown access level', () {
      expect(
        () => SubscriptionEntitlement.fromJson(entitlementJson(accessLevel: 7)),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a missing feature key list', () {
      expect(
        () => SubscriptionEntitlement.fromJson(
          entitlementJson(omitEffectiveFeatureKeys: true),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects non-string feature keys', () {
      expect(
        () => SubscriptionEntitlement.fromJson(
          entitlementJson(effectiveFeatureKeys: [1, 2]),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a missing evaluatedAtUtc', () {
      expect(
        () => SubscriptionEntitlement.fromJson(
          entitlementJson(evaluatedAtUtc: 'not-a-date'),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('BillingPlan.fromJson', () {
    test('parses a full plan', () {
      final plan = BillingPlan.fromJson({
        'id': 'p1',
        'code': 'pro',
        'name': 'Pro',
        'monthlyPrice': 49000,
        'currency': 'TZS',
        'featureKeys': ['pos.enabled', 'finance.enabled'],
        'maxBranches': 5,
        'maxUsers': null,
        'maxProducts': null,
      });

      expect(plan.code, 'pro');
      expect(plan.monthlyPrice, 49000);
      expect(plan.featureKeys, contains(BillingFeatureKeys.finance));
      expect(plan.maxBranches, 5);
      expect(plan.maxUsers, isNull);
    });

    test('rejects a plan without feature keys', () {
      expect(
        () => BillingPlan.fromJson({
          'id': 'p1',
          'code': 'pro',
          'name': 'Pro',
          'monthlyPrice': 1,
          'currency': 'TZS',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a non-numeric price', () {
      expect(
        () => BillingPlan.fromJson({
          'id': 'p1',
          'code': 'pro',
          'name': 'Pro',
          'monthlyPrice': 'free',
          'currency': 'TZS',
          'featureKeys': <String>[],
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('BillingInvoice.fromJson', () {
    test('parses a paid invoice', () {
      final invoice = BillingInvoice.fromJson({
        'id': 'i1',
        'number': 'INV-0001',
        'description': 'Pro monthly',
        'amount': 49000,
        'currency': 'TZS',
        'subscriptionId': 's1',
        'periodStartUtc': '2026-09-01T00:00:00Z',
        'periodEndUtc': '2026-09-30T23:59:59Z',
        'issuedAtUtc': '2026-09-01T00:00:00Z',
        'status': 1,
        'reference': 'EXT-1',
        'confirmedByUserId': 'u1',
        'paidAtUtc': '2026-09-02T08:00:00Z',
      });

      expect(invoice.number, 'INV-0001');
      expect(invoice.status, BillingInvoiceStatus.paid);
      expect(invoice.amount, 49000);
      expect(invoice.paidAtUtc, isNotNull);
      expect(invoice.paidAtUtc!.isUtc, isTrue);
    });

    test('parses an open invoice without optional references', () {
      final invoice = BillingInvoice.fromJson({
        'id': 'i2',
        'number': 'INV-0002',
        'description': 'Pro monthly',
        'amount': 49000,
        'currency': 'TZS',
        'subscriptionId': 's1',
        'periodStartUtc': '2026-09-01T00:00:00Z',
        'periodEndUtc': '2026-09-30T23:59:59Z',
        'issuedAtUtc': '2026-09-01T00:00:00Z',
        'status': 0,
        'reference': null,
        'confirmedByUserId': null,
        'paidAtUtc': null,
      });

      expect(invoice.status, BillingInvoiceStatus.open);
      expect(invoice.reference, isNull);
      expect(invoice.paidAtUtc, isNull);
    });

    test('rejects an unknown invoice status', () {
      expect(
        () => BillingInvoice.fromJson({
          'id': 'i3',
          'number': 'INV-0003',
          'description': 'Pro monthly',
          'amount': 49000,
          'currency': 'TZS',
          'subscriptionId': 's1',
          'periodStartUtc': '2026-09-01T00:00:00Z',
          'periodEndUtc': '2026-09-30T23:59:59Z',
          'issuedAtUtc': '2026-09-01T00:00:00Z',
          'status': 42,
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('VoucherCode', () {
    test('normalizes by trimming and upper-casing', () {
      expect(VoucherCode.normalize('  abc-123 '), 'ABC-123');
      expect(VoucherCode.normalize('Already-UPPER'), 'ALREADY-UPPER');
      expect(VoucherCode.normalize('   '), isEmpty);
    });
  });

  group('BillingFeatureKeys', () {
    test('finance maps to the backend finance.enabled key', () {
      expect(BillingFeatureKeys.finance, 'finance.enabled');
      expect(BillingFeatureKeys.accounting, 'accounting.enabled');
      expect(BillingFeatureKeys.pos, 'pos.enabled');
      expect(BillingFeatureKeys.inventory, 'inventory.enabled');
    });

    test('price editing has no client-side feature key (entitlement level)',
        () {
      expect(BillingFeatureKeys.pos, isNot(contains('pricing')));
      expect(
        const <String>{
          BillingFeatureKeys.pos,
          BillingFeatureKeys.inventory,
          BillingFeatureKeys.purchasing,
          BillingFeatureKeys.accounting,
          BillingFeatureKeys.finance,
          BillingFeatureKeys.crm,
          BillingFeatureKeys.credit,
          BillingFeatureKeys.reports,
          BillingFeatureKeys.multiBranch,
        },
        hasLength(9),
      );
    });
  });
}
