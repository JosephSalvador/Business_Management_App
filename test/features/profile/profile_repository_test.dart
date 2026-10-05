import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/core/config/app_config.dart';
import 'package:jolinx_app/core/network/api_client.dart';
import 'package:jolinx_app/core/network/app_exception.dart';
import 'package:jolinx_app/features/profile/data/profile_repository.dart';
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

Map<String, dynamic> profileJson({
  String id = 'u1',
  String fullName = 'Juma',
  String email = 'juma@test.co.tz',
  String phone = '+255712345678',
  String tenantName = 'Acme Ltd',
  List<String> roleNames = const ['Admin'],
  List<String> permissions = const [],
}) =>
    {
      'id': id,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'tenantName': tenantName,
      'roleNames': roleNames,
      'permissions': permissions,
    };

void main() {
  group('ProfileRepository HTTP contract', () {
    test('get parses user profile fields', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(200, jsonEncode(profileJson())),
      ]);
      final repository = ProfileRepository(apiClient: clientWith(adapter));

      final profile = await repository.get();

      expect(adapter.requests.single.method, 'GET');
      expect(
        adapter.requests.single.path,
        contains('/api/v1/users/me'),
      );
      expect(profile.id, 'u1');
      expect(profile.fullName, 'Juma');
      expect(profile.email, 'juma@test.co.tz');
      expect(profile.phone, '+255712345678');
      expect(profile.tenantName, 'Acme Ltd');
      expect(profile.roleNames, ['Admin']);
    });

    test('updateProfile sends PUT with correct body', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse(
            200, jsonEncode(profileJson(fullName: 'Juma Updated'))),
      ]);
      final repository = ProfileRepository(apiClient: clientWith(adapter));

      final profile = await repository.updateProfile(
        fullName: 'Juma Updated',
        phone: '+255799999999',
      );

      final request = adapter.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, contains('/api/v1/users/me'));
      final body = jsonDecode(request.body!) as Map<String, dynamic>;
      expect(body['fullName'], 'Juma Updated');
      expect(body['phone'], '+255799999999');
      expect(profile.fullName, 'Juma Updated');
    });

    test('changePassword sends PUT with correct body', () async {
      final adapter = ScriptedAdapter([
        const ScriptedResponse(200, '{}'),
      ]);
      final repository = ProfileRepository(apiClient: clientWith(adapter));

      await repository.changePassword(
        currentPassword: 'old123',
        newPassword: 'new456',
      );

      final request = adapter.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, contains('/api/v1/users/me/password'));
      final body = jsonDecode(request.body!) as Map<String, dynamic>;
      expect(body['currentPassword'], 'old123');
      expect(body['newPassword'], 'new456');
    });

    test('get throws ServerException on bad response', () async {
      final adapter = ScriptedAdapter([
        const ScriptedResponse(500, '{"error":"oops"}'),
      ]);
      final repository = ProfileRepository(apiClient: clientWith(adapter));

      expectLater(repository.get(), throwsA(isA<ServerException>()));
    });

    test('updateProfile throws ValidationException on 400', () async {
      final adapter = ScriptedAdapter([
        const ScriptedResponse(400, '{}'),
      ]);
      final repository = ProfileRepository(apiClient: clientWith(adapter));

      expectLater(
        repository.updateProfile(fullName: 'X'),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
