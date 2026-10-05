import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/config/app_config.dart';
import 'package:jolinx_app/core/network/api_client.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/features/billing/data/billing_repository.dart';
import 'package:jolinx_app/features/billing/domain/billing.dart';

import '../../support/fakes.dart';

ApiClient clientWith(ScriptedAdapter adapter) => ApiClient(
      config: AppConfig.forTest(
        apiBaseUrl: Uri.parse('https://api.test.local'),
        environment: AppEnvironment.dev,
      ),
      tokenStore: InMemoryTokenStore(),
      refresher: (_) async => throw UnimplementedError(),
      dio: Dio(BaseOptions(baseUrl: 'https://api.test.local'))
        ..httpClientAdapter = adapter,
    );

String entitlementJson({
  Object status = 1,
  Object accessLevel = 0,
  List<Object?>? keys,
}) =>
    jsonEncode({
      'status': status,
      'accessLevel': accessLevel,
      'planCode': 'pro',
      'effectiveFeatureKeys': keys ??
          [
            BillingFeatureKeys.pos,
            BillingFeatureKeys.inventory,
            BillingFeatureKeys.finance,
          ],
      'nextDueUtc': null,
      'hasOpenInvoice': false,
      'maxBranches': null,
      'maxUsers': null,
      'maxProducts': null,
      'evaluatedAtUtc': '2026-09-25T10:00:00Z',
    });

String invoiceJson({String id = 'i1', int status = 1}) => jsonEncode({
      'id': id,
      'number': 'INV-0001',
      'description': 'Pro monthly',
      'amount': 49000,
      'currency': 'TZS',
      'subscriptionId': 's1',
      'periodStartUtc': '2026-09-01T00:00:00Z',
      'periodEndUtc': '2026-09-30T23:59:59Z',
      'issuedAtUtc': '2026-09-01T00:00:00Z',
      'status': status,
      'reference': null,
      'confirmedByUserId': null,
      'paidAtUtc': status == 1 ? '2026-09-02T08:00:00Z' : null,
    });

void main() {
  group('BillingRepository getSubscription HTTP contract', () {
    test('GETs /billing/subscription and parses the entitlement', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, entitlementJson(status: 2, accessLevel: 1)),
      ]);
      final repository = BillingRepository(apiClient: clientWith(adapter));

      final entitlement = await repository.getSubscription();

      expect(adapter.requests.single.method, 'GET');
      expect(
        adapter.requests.single.path,
        contains('/api/v1/billing/subscription'),
      );
      expect(entitlement.status, SubscriptionStatus.debt);
      expect(entitlement.accessLevel, BillingAccessLevel.posAndInventory);
      expect(entitlement.hasFeature(BillingFeatureKeys.pos), isTrue);
    });

    test('a 200 with a non-object body surfaces as ServerException', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, '[1,2,3]'),
      ]);
      final repository = BillingRepository(apiClient: clientWith(adapter));

      await expectLater(
        repository.getSubscription(),
        throwsA(isA<ServerException>()),
      );
    });

    test('a malformed entitlement body surfaces as ServerException', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, entitlementJson(status: 99)),
      ]);
      final repository = BillingRepository(apiClient: clientWith(adapter));

      await expectLater(
        repository.getSubscription(),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('BillingRepository evaluateSubscription HTTP contract', () {
    test('POSTs /billing/subscription/evaluate', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, entitlementJson()),
      ]);
      final repository = BillingRepository(apiClient: clientWith(adapter));

      final entitlement = await repository.evaluateSubscription();

      expect(adapter.requests.single.method, 'POST');
      expect(
        adapter.requests.single.path,
        contains('/api/v1/billing/subscription/evaluate'),
      );
      expect(entitlement.status, SubscriptionStatus.active);
      expect(entitlement.hasFeature(BillingFeatureKeys.finance), isTrue);
    });
  });

  group('BillingRepository redeemVoucher HTTP contract', () {
    test('POSTs the normalized code and parses the new entitlement', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, entitlementJson(status: 1, accessLevel: 0)),
      ]);
      final repository = BillingRepository(apiClient: clientWith(adapter));

      final entitlement = await repository.redeemVoucher('ABC-123');

      expect(adapter.requests.single.method, 'POST');
      expect(
        adapter.requests.single.path,
        contains('/api/v1/billing/vouchers/redeem'),
      );
      expect(
        jsonDecode(adapter.requests.single.body!),
        {'code': 'ABC-123'},
      );
      expect(entitlement.hasFullAccess, isTrue);
    });
  });

  group('BillingRepository plans and invoices HTTP contract', () {
    test('listPlans parses the plan catalogue', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode([
              {
                'id': 'p1',
                'code': 'pro',
                'name': 'Pro',
                'monthlyPrice': 49000,
                'currency': 'TZS',
                'featureKeys': ['finance.enabled'],
                'maxBranches': null,
                'maxUsers': null,
                'maxProducts': null,
              },
            ])),
      ]);
      final repository = BillingRepository(apiClient: clientWith(adapter));

      final plans = await repository.listPlans();

      expect(adapter.requests.single.path, contains('/api/v1/billing/plans'));
      expect(plans.single.code, 'pro');
      expect(plans.single.featureKeys, contains('finance.enabled'));
    });

    test('listPlans rejects a non-list body', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, '{"plans":[]}'),
      ]);
      final repository = BillingRepository(apiClient: clientWith(adapter));

      await expectLater(
        repository.listPlans(),
        throwsA(isA<ServerException>()),
      );
    });

    test('listInvoices parses invoice rows', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200, '[${invoiceJson()},${invoiceJson(id: 'i2', status: 0)}]'),
      ]);
      final repository = BillingRepository(apiClient: clientWith(adapter));

      final invoices = await repository.listInvoices();

      expect(
        adapter.requests.single.path,
        contains('/api/v1/billing/invoices'),
      );
      expect(invoices, hasLength(2));
      expect(invoices.first.status, BillingInvoiceStatus.paid);
      expect(invoices.last.status, BillingInvoiceStatus.open);
    });

    test('listInvoices rejects a non-list body', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, '{}'),
      ]);
      final repository = BillingRepository(apiClient: clientWith(adapter));

      await expectLater(
        repository.listInvoices(),
        throwsA(isA<ServerException>()),
      );
    });

    test('getInvoice requests the invoice by id', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, invoiceJson(id: 'inv-9')),
      ]);
      final repository = BillingRepository(apiClient: clientWith(adapter));

      final invoice = await repository.getInvoice('inv-9');

      expect(
        adapter.requests.single.path,
        contains('/api/v1/billing/invoices/inv-9'),
      );
      expect(invoice.id, 'inv-9');
    });

    test('a billing 402 maps to PaymentRequiredException', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            402,
            jsonEncode({
              'title': 'BillingRequired',
              'detail': 'Renew to restore full access.',
              'status': 402,
              'code': 'BillingRequired',
            })),
      ]);
      final repository = BillingRepository(apiClient: clientWith(adapter));

      await expectLater(
        repository.getSubscription(),
        throwsA(isA<PaymentRequiredException>()),
      );
    });
  });
}
