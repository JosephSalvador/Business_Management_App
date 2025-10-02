import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class UserProvider with ChangeNotifier {
  User? _currentUser;
  bool _isLoggedIn = false;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  List<String> get currentUserPrivileges => _currentUser?.privileges ?? [];

  UserProvider() {
    loadUserSession();
  }

  // Load user session from SharedPreferences
  Future<void> loadUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (_isLoggedIn) {
      final userJsonString = prefs.getString('userData');
      if (userJsonString != null) {
        final userMap = jsonDecode(userJsonString);
        _currentUser = User.fromJson(userMap);
      }
    }
    notifyListeners();
  }

  // Save user session and log in
  Future<void> login(User user) async {
    _currentUser = user;
    _isLoggedIn = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userData', jsonEncode(user.toJson()));
  }

  // Logout and clear session
  Future<void> logout() async {
    _currentUser = null;
    _isLoggedIn = false;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  bool hasPrivilege(String privilege) {
    return _currentUser?.privileges.contains(privilege) ?? false;
  }

  bool hasAnyPrivilege(List<String> privileges) {
    return privileges.any((privilege) => hasPrivilege(privilege));
  }

  void updateUser(User updatedUser) async {
    _currentUser = updatedUser;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userData', jsonEncode(updatedUser.toJson()));
  }
}
