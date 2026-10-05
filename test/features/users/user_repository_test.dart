import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/config/app_config.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/core/network/api_client.dart';
import 'package:jolinx_app/features/users/data/user_repository.dart';
import '../../support/fakes.dart';

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

Map<String, dynamic> userJson(String id, {String name = 'John Doe'}) => {
      'id': id,
      'fullName': name,
      'email': '$id@test.com',
      'isActive': true,
      'emailVerified': true,
      'isLockedOut': false,
      'roleIds': <String>[],
      'branchIds': <String>[],
      'createdAt': '2026-01-01T00:00:00Z',
    };

void main() {
  group('UserRepository HTTP contract', () {
    test('list parses paged envelope', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode({
              'items': [userJson('u1'), userJson('u2', name: 'Jane')],
              'total': 2,
            })),
      ]);
      final repository = UserRepository(apiClient: clientWith(adapter));

      final page = await repository.list();

      expect(
        adapter.requests.single.path,
        contains('/api/v1/users'),
      );
      expect(page.total, 2);
      expect(page.items, hasLength(2));
      expect(page.items[1].fullName, 'Jane');
    });

    test('list passes page and pageSize query params', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode({
              'items': [userJson('u1')],
              'total': 10,
            })),
      ]);
      final repository = UserRepository(apiClient: clientWith(adapter));

      await repository.list(page: 2, pageSize: 25);

      expect(
        adapter.requests.single.path,
        contains('page=2'),
      );
      expect(
        adapter.requests.single.path,
        contains('pageSize=25'),
      );
    });

    test('getById parses single user', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, jsonEncode(userJson('u1', name: 'Admin'))),
      ]);
      final repository = UserRepository(apiClient: clientWith(adapter));

      final user = await repository.getById('u1');

      expect(adapter.requests.single.path, contains('/api/v1/users/u1'));
      expect(user.fullName, 'Admin');
      expect(user.id, 'u1');
    });

    test('create sends correct body via POST', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(201, jsonEncode(<String, dynamic>{})),
      ]);
      final repository = UserRepository(apiClient: clientWith(adapter));

      await repository.create({
        'name': 'New User',
        'email': 'new@test.com',
      });

      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.path, contains('/api/v1/users'));
      final body =
          jsonDecode(adapter.requests.single.body!) as Map<String, dynamic>;
      expect(body['name'], 'New User');
      expect(body['email'], 'new@test.com');
    });

    test('update sends correct body with PUT', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, jsonEncode(<String, dynamic>{})),
      ]);
      final repository = UserRepository(apiClient: clientWith(adapter));

      await repository.update('u1', {
        'name': 'Updated Name',
      });

      expect(adapter.requests.single.method, 'PUT');
      expect(adapter.requests.single.path, contains('/api/v1/users/u1'));
      final body =
          jsonDecode(adapter.requests.single.body!) as Map<String, dynamic>;
      expect(body['name'], 'Updated Name');
    });

    test('roles parses flat array', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode([
              {
                'id': 'r1',
                'name': 'Admin',
                'isSystem': false,
                'permissionNames': [],
                'createdAt': '2026-01-01T00:00:00Z'
              },
              {
                'id': 'r2',
                'name': 'Staff',
                'isSystem': false,
                'permissionNames': [],
                'createdAt': '2026-01-01T00:00:00Z'
              },
            ])),
      ]);
      final repository = UserRepository(apiClient: clientWith(adapter));

      final roles = await repository.roles();

      expect(adapter.requests.single.path, contains('/api/v1/roles'));
      expect(roles.length, 2);
      expect(roles[0].name, 'Admin');
    });

    test('list throws ServerException on 500', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            500,
            jsonEncode({
              'title': 'Server',
              'detail': 'Something broke.',
              'code': 'Server',
            })),
      ]);
      final repository = UserRepository(apiClient: clientWith(adapter));

      await expectLater(
        repository.list(),
        throwsA(isA<ServerException>()),
      );
    });

    test('create throws ServerException on 500', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            500,
            jsonEncode({
              'title': 'Server',
              'detail': 'Cannot create.',
              'code': 'Server',
            })),
      ]);
      final repository = UserRepository(apiClient: clientWith(adapter));

      await expectLater(
        repository.create({'name': 'X'}),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
