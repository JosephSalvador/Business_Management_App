import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class UserProvider with ChangeNotifier {
  User? _currentUser;
  bool _isLoggedIn = false;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  List<String> get currentUserPrivileges => _currentUser?.privileges ?? [];

  void login(User user) {
    _currentUser = user;
    _isLoggedIn = true;
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  bool hasPrivilege(String privilege) {
    return _currentUser?.privileges.contains(privilege) ?? false;
  }

  bool hasAnyPrivilege(List<String> privileges) {
    return privileges.any((privilege) => hasPrivilege(privilege));
  }

  void updateuser(User updatedUser) {
    _currentUser = updatedUser;
    notifyListeners();
  }
}
