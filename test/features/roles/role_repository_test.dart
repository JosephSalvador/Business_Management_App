import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/config/app_config.dart';
import 'package:jolinx_app/core/network/api_client.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/features/roles/data/role_repository.dart';
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

Map<String, dynamic> roleJson(String id, {String name = 'Admin'}) => {
      'id': id,
      'name': name,
      'description': 'Full access',
      'isSystem': false,
      'permissionNames': <String>[],
      'createdAt': '2026-01-01T00:00:00Z',
    };

void main() {
  group('RoleRepository HTTP contract', () {
    test('list parses flat array', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode([
              roleJson('r1'),
              roleJson('r2', name: 'Viewer'),
            ])),
      ]);
      final repository = RoleRepository(apiClient: clientWith(adapter));

      final roles = await repository.list();

      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.path, contains('/api/v1/roles'));
      expect(roles.length, 2);
      expect(roles.first.id, 'r1');
    });

    test('getById parses single role', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, jsonEncode(roleJson('r3', name: 'Manager'))),
      ]);
      final repository = RoleRepository(apiClient: clientWith(adapter));

      final role = await repository.getById('r3');

      expect(
        adapter.requests.single.path,
        contains('/api/v1/roles/r3'),
      );
      expect(role.id, 'r3');
      expect(role.name, 'Manager');
    });

    test('create sends name and description only', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(201, jsonEncode(roleJson('r-new', name: 'Editor'))),
      ]);
      final repository = RoleRepository(apiClient: clientWith(adapter));

      final role = await repository.create(
        name: 'Editor',
        description: 'Can edit',
      );

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, contains('/api/v1/roles'));
      final body = jsonDecode(request.body!) as Map<String, dynamic>;
      expect(body['name'], 'Editor');
      expect(body['description'], 'Can edit');
      expect(body.containsKey('permissions'), false);
      expect(role.id, 'r-new');
    });

    test('update sends correct body', () async {
      final adapter = ScriptedAdapter([
        const ScriptedResponse(200, '{}'),
      ]);
      final repository = RoleRepository(apiClient: clientWith(adapter));

      await repository.update('r1', name: 'SuperAdmin', description: 'All');

      final request = adapter.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, contains('/api/v1/roles/r1'));
      final body = jsonDecode(request.body!) as Map<String, dynamic>;
      expect(body['name'], 'SuperAdmin');
      expect(body['description'], 'All');
    });

    test('permissions parses permission list', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200,
            jsonEncode([
              {'name': 'read', 'description': 'Can read'},
              {'name': 'write', 'description': 'Can write'},
            ])),
      ]);
      final repository = RoleRepository(apiClient: clientWith(adapter));

      final perms = await repository.permissions();

      expect(adapter.requests.single.path, contains('/api/v1/permissions'));
      expect(perms.length, 2);
      expect(perms.first.name, 'read');
    });

    test('rolePermissions parses permission names', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, jsonEncode(['read', 'write'])),
      ]);
      final repository = RoleRepository(apiClient: clientWith(adapter));

      final names = await repository.rolePermissions('r1');

      expect(
        adapter.requests.single.path,
        contains('/api/v1/roles/r1/permissions'),
      );
      expect(names, ['read', 'write']);
    });

    test('setRolePermissions sends wrapped body', () async {
      final adapter = ScriptedAdapter([
        const ScriptedResponse(200, '{}'),
      ]);
      final repository = RoleRepository(apiClient: clientWith(adapter));

      await repository.setRolePermissions('r1', ['read', 'delete']);

      final request = adapter.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, contains('/api/v1/roles/r1/permissions'));
      final body = jsonDecode(request.body!) as Map<String, dynamic>;
      expect(body['permissionNames'], ['read', 'delete']);
    });

    test('list throws ServerException on bad response', () async {
      final adapter = ScriptedAdapter([
        const ScriptedResponse(500, '{}'),
      ]);
      final repository = RoleRepository(apiClient: clientWith(adapter));

      expectLater(repository.list(), throwsA(isA<ServerException>()));
    });
  });
}
