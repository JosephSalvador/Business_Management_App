import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/config/app_config.dart';
import 'package:jolinx_app/core/network/api_client.dart';
import 'package:jolinx_app/features/authentication/data/auth_repository.dart';
import 'package:jolinx_app/features/authentication/data/offline_credential_store.dart';
import 'package:jolinx_app/features/authentication/domain/session.dart';
import 'package:jolinx_app/features/onboarding/data/workspace_repository.dart';
import '../../support/fakes.dart';

/// Fake [OfflineCredentialStore] for tests.
class _FakeOfflineCredentialStore implements OfflineCredentialStore {
  @override
  Future<bool> isOfflineAuthAvailable() async => false;

  @override
  Future<bool> verifyPassword(String password) async => false;

  @override
  Future<void> storeCredentials(
      {required String password, required dynamic user}) async {}

  @override
  Future<String?> generateOfflineToken(dynamic user) async => null;

  @override
  Future<void> enableQuickUnlock(dynamic user) async {}

  @override
  Future<bool> hasValidQuickUnlock() async => false;

  @override
  Future<Session?> restoreQuickUnlock() async => null;

  @override
  Future<void> disableQuickUnlock() async {}

  @override
  Future<Session?> restoreOfflineSession() async => null;

  @override
  Future<void> clearOfflineToken() async {}

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> clearPasswordHash() async {}

  @override
  Future<String?> getCachedUserId() async => null;

  @override
  Future<String?> getCachedTenantId() async => null;

  @override
  Future<List<String>> getCachedPermissions() async => const [];

  @override
  Future<String?> getCachedEmail() async => null;

  @override
  Future<String?> getCachedFullName() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Real [ApiClient] over the [ScriptedAdapter] so paths, bodies, and error
/// mapping are exercised end-to-end (no network).
ApiClient clientWith(ScriptedAdapter adapter) => ApiClient(
      config: AppConfig.forTest(
        apiBaseUrl: Uri.parse('https://api.test.local'),
        environment: AppEnvironment.dev,
      ),
      tokenStore: InMemoryTokenStore(),
      refresher: (_) async => TokenPair(
        accessToken: 'a',
        refreshToken: 'r',
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 15)),
      ),
      dio: Dio(BaseOptions(baseUrl: 'https://api.test.local'))
        ..httpClientAdapter = adapter,
    );

void main() {
  group('WorkspaceRepository HTTP contract', () {
    test('mine parses the workspace array', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode([
              {
                'id': 't1',
                'name': 'Duka la Mama',
                'currency': 'TZS',
                'countryCode': 'TZ',
                'businessType': 'retail',
                'onboardingComplete': false,
                'roles': ['Administrator'],
              },
            ])),
      ]);
      final repository = WorkspaceRepository(apiClient: clientWith(adapter));

      final workspaces = await repository.mine();

      expect(adapter.requests.single.path,
          'https://api.test.local/api/v1/workspaces/mine');
      expect(workspaces, hasLength(1));
      expect(workspaces.first.name, 'Duka la Mama');
      expect(workspaces.first.onboardingComplete, isFalse);
    });

    test('completeOnboarding posts the normalized draft', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode({
              'id': 't1',
              'name': 'Duka la Mama',
              'currency': 'TZS',
              'countryCode': 'TZ',
              'businessType': 'retail',
              'onboardingComplete': true,
              'roles': ['Administrator'],
            })),
      ]);
      final repository = WorkspaceRepository(apiClient: clientWith(adapter));

      final result = await repository.completeOnboarding(const OnboardingDraft(
        name: ' Duka la Mama ',
        businessType: 'Retail',
        countryCode: 'tz',
        currency: 'tzs ',
        contactPhone: '0712345678',
        taxId: null,
      ));

      expect(result.onboardingComplete, isTrue);
      final body =
          jsonDecode(adapter.requests.single.body!) as Map<String, dynamic>;
      expect(body, {
        'name': 'Duka la Mama',
        'businessType': 'retail',
        'countryCode': 'TZ',
        'currency': 'TZS',
        'contactPhone': '0712345678',
      });
    });

    test('verification endpoints hit the right paths', () async {
      final adapter = ScriptedAdapter([
        const ScriptedResponse(204),
        const ScriptedResponse(204),
      ]);
      final auth = AuthRepository(
        apiClient: clientWith(adapter),
        tokenStore: InMemoryTokenStore(),
        offlineCredentialStore: _FakeOfflineCredentialStore(),
      );

      await auth.verifyEmail(email: 'Owner@Test.Local', code: ' 654321 ');
      await auth.resendVerificationCode(email: 'owner@test.local');

      expect(adapter.requests[0].path,
          'https://api.test.local/api/v1/auth/verify-email');
      expect(adapter.requests[1].path,
          'https://api.test.local/api/v1/auth/resend-verification');
    });

    test('register no longer receives or persists tokens', () async {
      final store = InMemoryTokenStore();
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode({
              'id': 'u1',
              'tenantId': 't1',
              'email': 'owner@test.local',
              'fullName': 'Mama',
              'phone': null,
              'isActive': true,
              'emailVerified': false,
              'permissions': ['Dashboard.View'],
            })),
      ]);
      final auth = AuthRepository(
        apiClient: clientWith(adapter),
        tokenStore: store,
        offlineCredentialStore: _FakeOfflineCredentialStore(),
      );

      final user = await auth.register(
        email: 'owner@test.local',
        password: 'Passw0rd!',
        fullName: 'Mama',
        phone: '+255712345678',
        organizationName: 'Duka',
      );

      expect(user.emailVerified, isFalse);
      expect(store.writeCount, 0);
    });
  });
}
