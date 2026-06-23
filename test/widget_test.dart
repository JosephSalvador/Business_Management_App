import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:business_management_system/shared/models/user_model.dart';
import 'package:business_management_system/shared/providers/user_provider.dart';

void main() {
  test('User serialization writes privileges and reads legacy key', () {
    final user = User(
      id: '1',
      username: 'admin',
      email: 'admin@company.com',
      role: 'Admin',
      privileges: ['Manage Users'],
      fullName: 'Admin User',
      createdAt: DateTime.parse('2026-06-24T12:00:00.000Z'),
    );

    final json = user.toJson();

    expect(json['privileges'], ['Manage Users']);
    expect(json.containsKey('priviledges'), isFalse);

    final restored = User.fromJson({
      'id': '1',
      'username': 'admin',
      'email': 'admin@company.com',
      'role': 'Admin',
      'priviledges': ['Manage Users'],
      'fullName': 'Admin User',
      'createdAt': '2026-06-24T12:00:00.000Z',
    });

    expect(restored.privileges, ['Manage Users']);
  });

  test('UserProvider restores a saved session with legacy privileges key', () async {
    SharedPreferences.setMockInitialValues({
      'isLoggedIn': true,
      'userData': jsonEncode({
        'id': '1',
        'username': 'admin',
        'email': 'admin@company.com',
        'role': 'Admin',
        'priviledges': ['Manage Users', 'View Sales'],
        'fullName': 'Admin User',
        'isActive': true,
        'createdAt': '2026-06-24T12:00:00.000Z',
      }),
    });

    final provider = UserProvider();
    await provider.loadUserSession();

    expect(provider.isLoggedIn, isTrue);
    expect(provider.currentUser?.privileges, ['Manage Users', 'View Sales']);
  });
}
