import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/config/app_config.dart';
import 'package:jolinx_app/app/providers.dart';
import 'package:jolinx_app/core/network/api_client.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/features/authentication/data/auth_repository.dart';
import 'package:jolinx_app/features/authentication/presentation/pages/staff_page.dart';

class FakeAuthRepository implements AuthRepository {
  final ApiClient _clientShell = ApiClient(
    config: AppConfig.forTest(
      apiBaseUrl: Uri.parse('https://api.test.local'),
      environment: AppEnvironment.dev,
    ),
    tokenStore: _NoopTokenStore(),
    refresher: (_) => throw UnimplementedError(),
  );

  int issueCalls = 0;
  ({String code, DateTime expiresAtUtc})? next;
  Object? issueError;

  @override
  ApiClient get apiClient => _clientShell;

  @override
  Future<({String code, DateTime expiresAtUtc})> issueInvitation() async {
    issueCalls++;
    final error = issueError;
    if (error != null) {
      throw error;
    }
    return next ??
        (
          code: 'ABCD1234',
          expiresAtUtc: DateTime.utc(2026, 9, 3, 12),
        );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopTokenStore implements TokenStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> readAccessToken() async => null;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}
}

Widget _host(FakeAuthRepository fake) => ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(fake)],
      child: const MaterialApp(home: StaffPage()),
    );

void main() {
  testWidgets('generates and reveals the invitation code', (tester) async {
    final fake = FakeAuthRepository();
    await tester.pumpWidget(_host(fake));

    await tester.tap(find.text('Tengeneza namba mpya'));
    await tester.pumpAndSettle();

    expect(fake.issueCalls, 1);
    expect(find.text('ABCD1234'), findsOneWidget);
    expect(find.text('Nakili namba'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('surfaces an error when issuance fails', (tester) async {
    final fake = FakeAuthRepository()
      ..issueError = ServerException('Hitilafu ya mtandao.');
    await tester.pumpWidget(_host(fake));

    await tester.tap(find.text('Tengeneza namba mpya'));
    await tester.pumpAndSettle();

    expect(find.text('Hitilafu ya mtandao.'), findsOneWidget);
    expect(find.text('ABCD1234'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
